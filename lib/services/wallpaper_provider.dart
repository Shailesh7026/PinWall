import 'package:flutter/material.dart';
import '../models/queue_models.dart';
import '../models/wallpaper.dart';
import 'api_service.dart';
import 'background_worker.dart';
import 'local_db.dart';
import 'queue_engine.dart';
import 'settings_service.dart';

enum LoadState { idle, loading, loaded, error }

class WallpaperProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  final LocalDb _db = LocalDb.instance;
  final QueueEngine _engine = QueueEngine.instance;

  // ── Browse / Explore State ───────────────────────────────────────────────
  List<MediaItem> _items = [];
  List<MediaItem> get items => _items;

  LoadState _state = LoadState.idle;
  LoadState get state => _state;

  String _error = '';
  String get error => _error;

  bool _fromCache = false;
  bool get fromCache => _fromCache;

  String _currentQuery = '';
  String get currentQuery => _currentQuery;

  List<String> _trending = [];
  List<String> get trending => _trending;

  // ── Board Import & History State ─────────────────────────────────────────
  List<MediaItem> _boardItems = [];
  List<MediaItem> get boardItems => _boardItems;

  LoadState _boardState = LoadState.idle;
  LoadState get boardState => _boardState;

  String _boardError = '';
  String get boardError => _boardError;

  bool _boardFromCache = false;
  bool get boardFromCache => _boardFromCache;

  List<ImportHistoryEntry> _importHistory = [];
  List<ImportHistoryEntry> get importHistory => _importHistory;

  List<QueueBoard> _homeBoards = [];
  List<QueueBoard> get homeBoards => _homeBoards;

  List<QueueBoard> _lockBoards = [];
  List<QueueBoard> get lockBoards => _lockBoards;

  // ── Queue Gallery (Local Disk) State ─────────────────────────────────────
  List<QueuedWallpaper> _homeQueue = [];
  List<QueuedWallpaper> get homeQueue => _homeQueue;

  List<QueuedWallpaper> _lockQueue = [];
  List<QueuedWallpaper> get lockQueue => _lockQueue;

  bool _isSyncingQueue = false;
  bool get isSyncingQueue => _isSyncingQueue;

  // ── Settings & Cache State ───────────────────────────────────────────────
  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;

  int _apiCacheCount = 0;
  int get apiCacheCount => _apiCacheCount;

  bool _apiReady = false;
  bool get apiReady => _apiReady;

  Future<void> warmUp() async {
    await refreshLocalState();
    _apiReady = await _api.warmUp();
    notifyListeners();
  }

  Future<void> refreshLocalState() async {
    _settings = await SettingsService.load();
    _importHistory = await _db.getImportHistory();
    _homeBoards = await _db.getQueueBoards('home');
    _lockBoards = await _db.getQueueBoards('lock');
    _homeQueue = await _db.getQueuedWallpapers(queueType: 'home');
    _lockQueue = await _db.getQueuedWallpapers(queueType: 'lock');
    _apiCacheCount = await _db.getApiCacheCount();
    notifyListeners();
  }

  // ── Browse / Explore Actions ─────────────────────────────────────────────

  Future<void> loadGenre(
    String slug, {
    int count = 30,
    bool forceRefresh = false,
  }) async {
    _state = LoadState.loading;
    _currentQuery = 'genre:$slug';
    _error = '';
    notifyListeners();
    try {
      final res = await _api.fetchGenre(
        slug,
        count: count,
        forceRefresh: forceRefresh,
      );
      _items = res.items;
      _fromCache = res.fromCache;
      _state = LoadState.loaded;
      _apiCacheCount = await _db.getApiCacheCount();
    } catch (e) {
      _error = e.toString();
      _state = LoadState.error;
    }
    notifyListeners();
  }

  Future<void> loadSearch(
    String query, {
    int count = 30,
    bool forceRefresh = false,
  }) async {
    _state = LoadState.loading;
    _currentQuery = 'search:$query';
    _error = '';
    notifyListeners();
    try {
      final res = await _api.search(
        query,
        count: count,
        forceRefresh: forceRefresh,
      );
      _items = res.items;
      _fromCache = res.fromCache;
      _state = LoadState.loaded;
      _apiCacheCount = await _db.getApiCacheCount();
    } catch (e) {
      _error = e.toString();
      _state = LoadState.error;
    }
    notifyListeners();
  }

  Future<void> loadRelated(String pinId) async {
    _state = LoadState.loading;
    _currentQuery = 'related:$pinId';
    _error = '';
    notifyListeners();
    try {
      final res = await _api.fetchRelated(pinId);
      _items = res.items;
      _fromCache = res.fromCache;
      _state = LoadState.loaded;
      _apiCacheCount = await _db.getApiCacheCount();
    } catch (e) {
      _error = e.toString();
      _state = LoadState.error;
    }
    notifyListeners();
  }

  Future<void> loadTrending() async {
    _trending = await _api.fetchTrending();
    notifyListeners();
  }

  // ── Board Import & Multi-Board Queue Actions ─────────────────────────────

  Future<void> importBoard(
    String boardUrl, {
    bool forceRefresh = false,
  }) async {
    _boardState = LoadState.loading;
    _boardError = '';
    notifyListeners();
    try {
      final res = await _api.fetchBoard(
        boardUrl,
        count: 50,
        forceRefresh: forceRefresh,
      );
      _boardItems = res.items;
      _boardFromCache = res.fromCache;
      _boardState = LoadState.loaded;
      await refreshLocalState();
    } catch (e) {
      _boardError = e.toString();
      _boardState = LoadState.error;
      notifyListeners();
    }
  }

  Future<void> addBoardToQueue(String queueType, String boardUrl) async {
    await _db.addQueueBoard(queueType, boardUrl);
    await refreshLocalState();
  }

  Future<void> removeBoardFromQueue(int id) async {
    await _db.removeQueueBoard(id);
    await refreshLocalState();
  }

  Future<void> deleteHistoryEntry(String boardUrl) async {
    await _db.deleteImportHistory(boardUrl);
    await refreshLocalState();
  }

  // ── Queue Gallery & Wallpaper Application Actions ────────────────────────

  Future<bool> addWallpaperToQueue(
    MediaItem item,
    String queueType, {
    String? sourceBoard,
  }) async {
    final ok = await _engine.downloadToQueue(
      item: item,
      queueType: queueType,
      sourceBoard: sourceBoard ?? 'browse',
      maxSize: _settings.queueMaxSize,
    );
    await refreshLocalState();
    return ok;
  }

  Future<int> syncQueueFromBoards(
    String queueType, {
    bool forceRefresh = false,
  }) async {
    _isSyncingQueue = true;
    notifyListeners();
    try {
      final count = await _engine.refillQueueFromBoards(
        queueType,
        maxSize: _settings.queueMaxSize,
        maxBatch: _settings.queueMaxSize,
        forceRefresh: forceRefresh,
      );
      await refreshLocalState();
      return count;
    } finally {
      _isSyncingQueue = false;
      notifyListeners();
    }
  }

  Future<void> applyImmediate(MediaItem item, int screenLocation) async {
    await _engine.applyImmediateFromItem(item, screenLocation);
  }

  Future<void> applyQueuedItem(QueuedWallpaper item, int screenLocation) async {
    await _engine.applyQueuedItem(item, screenLocation, settings: _settings);
    await refreshLocalState();
  }

  Future<void> deleteQueuedItem(QueuedWallpaper item) async {
    await _db.deleteQueuedWallpaper(item);
    await refreshLocalState();
  }

  Future<void> clearQueue(String queueType) async {
    await _db.clearQueue(queueType);
    await refreshLocalState();
  }

  Future<String> runAutoCycleNow() async {
    _isSyncingQueue = true;
    notifyListeners();
    try {
      final msg = await _engine.runAutoRotationCycle();
      await refreshLocalState();
      return msg;
    } finally {
      _isSyncingQueue = false;
      notifyListeners();
    }
  }

  // ── Settings & Cache Actions ─────────────────────────────────────────────

  Future<void> updateSettings(AppSettings updated) async {
    _settings = updated;
    await SettingsService.save(updated);
    await _db.pruneQueueToMaxSize('home', updated.queueMaxSize);
    await _db.pruneQueueToMaxSize('lock', updated.queueMaxSize);
    await BackgroundScheduler.syncWithSettings(updated);
    await refreshLocalState();
  }

  Future<void> clearApiCache() async {
    await _db.clearApiCache();
    await refreshLocalState();
  }
}

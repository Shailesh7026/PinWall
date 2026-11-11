import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:wallpaper_manager_plus/wallpaper_manager_plus.dart';
import '../models/queue_models.dart';
import '../models/wallpaper.dart';
import 'api_service.dart';
import 'local_db.dart';
import 'settings_service.dart';

class QueueEngine {
  QueueEngine._();
  static final QueueEngine instance = QueueEngine._();

  final _db = LocalDb.instance;
  final _api = ApiService();
  final _wallpaper = WallpaperManagerPlus();
  final _random = Random();

  Future<Directory> _queueDir(String queueType) async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'pinwall_queues', queueType));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _extFromUrl(String url) {
    final lower = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    if (lower.endsWith('.png')) return '.png';
    if (lower.endsWith('.webp')) return '.webp';
    return '.jpg';
  }

  /// Downloads [item] into local disk storage and adds it to [queueType] ('home' or 'lock').
  /// Returns true if newly downloaded, false if skipped (duplicate or video or failed).
  Future<bool> downloadToQueue({
    required MediaItem item,
    required String queueType,
    String? sourceBoard,
    int? maxSize,
  }) async {
    if (item.isVideo) return false;
    if (await _db.hasWallpaperInQueue(queueType, item.url)) return false;

    final res = await http
        .get(Uri.parse(item.url))
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200 || res.bodyBytes.isEmpty) return false;

    final dir = await _queueDir(queueType);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final hash = item.url.hashCode.abs();
    final fileName = '${ts}_$hash${_extFromUrl(item.url)}';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(res.bodyBytes);

    await _db.insertQueuedWallpaper(
      QueuedWallpaper(
        queueType: queueType,
        pinId: item.id,
        imageUrl: item.url,
        localPath: file.path,
        sourceBoard: sourceBoard,
        alt: item.alt,
        width: item.width,
        height: item.height,
        status: 'queued',
        createdAt: ts,
      ),
    );

    final settings = await SettingsService.load();
    await _db.pruneQueueToMaxSize(queueType, maxSize ?? settings.queueMaxSize);
    return true;
  }

  /// Scrapes boards assigned to [queueType] in random order and downloads wallpapers
  /// up to [maxSize] (at most [maxBatch] new downloads per call).
  Future<int> refillQueueFromBoards(
    String queueType, {
    int? maxSize,
    int maxBatch = 10,
    bool forceRefresh = false,
  }) async {
    final settings = await SettingsService.load();
    final limit = maxSize ?? settings.queueMaxSize;

    final boards = await _db.getQueueBoards(queueType);
    if (boards.isEmpty) return 0;

    final currentQueued = await _db.getQueuedWallpapers(
      queueType: queueType,
      status: 'queued',
    );
    int needed = limit - currentQueued.length;
    if (needed <= 0) return 0;
    int toDownload = min(needed, maxBatch);

    final shuffledBoards = List<QueueBoard>.from(boards)..shuffle(_random);
    int downloaded = 0;

    for (final board in shuffledBoards) {
      if (downloaded >= toDownload) break;
      try {
        final res = await _api.fetchBoard(
          board.boardUrl,
          count: 50,
          forceRefresh: forceRefresh,
          recordHistory: false,
        );
        final candidates = res.items.where((e) => !e.isVideo).toList()
          ..shuffle(_random);

        for (final item in candidates) {
          if (downloaded >= toDownload) break;
          try {
            final ok = await downloadToQueue(
              item: item,
              queueType: queueType,
              sourceBoard: board.label,
              maxSize: limit,
            );
            if (ok) downloaded++;
          } catch (_) {}
        }
      } catch (_) {}
    }

    return downloaded;
  }

  /// Applies a local file directly to [screenLocation] (WallpaperManagerPlus constants).
  Future<void> applyLocalFile(String localPath, int screenLocation) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('Wallpaper file no longer exists on disk.');
    }
    await _wallpaper.setWallpaper(file, screenLocation);
  }

  /// Downloads [item] to a temp file, sets it immediately, and removes the temp file.
  Future<void> applyImmediateFromItem(
    MediaItem item,
    int screenLocation,
  ) async {
    if (item.isVideo) {
      throw Exception('Video pins cannot be set as static wallpaper.');
    }
    final res = await http
        .get(Uri.parse(item.url))
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
      throw Exception('Failed to download image (${res.statusCode}).');
    }
    final tempDir = await getTemporaryDirectory();
    final file = File(
      p.join(
        tempDir.path,
        'pinwall_now_${DateTime.now().millisecondsSinceEpoch}${_extFromUrl(item.url)}',
      ),
    );
    await file.writeAsBytes(res.bodyBytes);
    try {
      await _wallpaper.setWallpaper(file, screenLocation);
    } finally {
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }

  /// Applies a specific [QueuedWallpaper] and handles auto-delete / status update.
  Future<void> applyQueuedItem(
    QueuedWallpaper item,
    int screenLocation, {
    AppSettings? settings,
  }) async {
    final cfg = settings ?? await SettingsService.load();
    await applyLocalFile(item.localPath, screenLocation);
    if (item.id != null) {
      await _db.markWallpaperApplied(item.id!);
      if (cfg.autoDeleteApplied) {
        await _db.deleteAppliedWallpapers(item.queueType, keepId: item.id);
      }
    }
    await _db.pruneQueueToMaxSize(item.queueType, cfg.queueMaxSize);
  }

  /// Picks the next queued wallpaper for [queueType], refilling from boards if empty
  /// and auto-download is enabled, applies it, and prunes/auto-deletes.
  Future<QueuedWallpaper?> applyNextInQueue({
    required String queueType,
    required int screenLocation,
    required AppSettings settings,
  }) async {
    var queued = await _db.getQueuedWallpapers(
      queueType: queueType,
      status: 'queued',
    );

    if (queued.isEmpty && settings.autoDownloadEnabled) {
      await refillQueueFromBoards(
        queueType,
        maxSize: settings.queueMaxSize,
        maxBatch: 5,
      );
      queued = await _db.getQueuedWallpapers(
        queueType: queueType,
        status: 'queued',
      );
    }

    // Find first item whose file actually exists on disk
    QueuedWallpaper? chosen;
    for (final candidate in queued) {
      if (await File(candidate.localPath).exists()) {
        chosen = candidate;
        break;
      } else {
        await _db.deleteQueuedWallpaper(candidate);
      }
    }

    // If still empty, fallback to re-using an existing applied item if auto-delete is off
    if (chosen == null && !settings.autoDeleteApplied) {
      final applied = await _db.getQueuedWallpapers(
        queueType: queueType,
        status: 'applied',
      );
      for (final candidate in applied) {
        if (await File(candidate.localPath).exists()) {
          chosen = candidate;
          break;
        }
      }
    }

    if (chosen == null) return null;

    await applyQueuedItem(chosen, screenLocation, settings: settings);

    // Top up queue if running low and auto-download is enabled
    final remaining = await _db.getQueuedWallpapers(
      queueType: queueType,
      status: 'queued',
    );
    if (settings.autoDownloadEnabled && remaining.length < 3) {
      await refillQueueFromBoards(
        queueType,
        maxSize: settings.queueMaxSize,
        maxBatch: 5,
      );
    }

    return chosen;
  }

  /// Runs one full scheduled wallpaper rotation cycle according to [AppSettings].
  Future<String> runAutoRotationCycle() async {
    final settings = await SettingsService.load();
    final parts = <String>[];

    switch (settings.queueMode) {
      case QueueMode.bothSingleQueue:
        final applied = await applyNextInQueue(
          queueType: 'home',
          screenLocation: WallpaperManagerPlus.bothScreens,
          settings: settings,
        );
        parts.add(
          applied != null
              ? 'Applied wallpaper to Home & Lock'
              : 'Home/Shared queue empty — add boards or wallpapers',
        );
        break;

      case QueueMode.homeOnly:
        final applied = await applyNextInQueue(
          queueType: 'home',
          screenLocation: WallpaperManagerPlus.homeScreen,
          settings: settings,
        );
        parts.add(
          applied != null
              ? 'Applied wallpaper to Home screen'
              : 'Home queue empty — add boards or wallpapers',
        );
        break;

      case QueueMode.lockOnly:
        final applied = await applyNextInQueue(
          queueType: 'lock',
          screenLocation: WallpaperManagerPlus.lockScreen,
          settings: settings,
        );
        parts.add(
          applied != null
              ? 'Applied wallpaper to Lock screen'
              : 'Lock queue empty — add boards or wallpapers',
        );
        break;

      case QueueMode.separateQueues:
        final homeApplied = await applyNextInQueue(
          queueType: 'home',
          screenLocation: WallpaperManagerPlus.homeScreen,
          settings: settings,
        );
        final lockApplied = await applyNextInQueue(
          queueType: 'lock',
          screenLocation: WallpaperManagerPlus.lockScreen,
          settings: settings,
        );
        parts.add('Home: ${homeApplied != null ? "updated" : "empty"}');
        parts.add('Lock: ${lockApplied != null ? "updated" : "empty"}');
        break;
    }

    final summary = parts.join(' • ');
    await SettingsService.updateLastRun(summary);
    return summary;
  }
}


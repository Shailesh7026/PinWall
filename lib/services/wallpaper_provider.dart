import 'package:flutter/material.dart';
import '../models/wallpaper.dart';
import 'api_service.dart';

enum LoadState { idle, loading, loaded, error }

class WallpaperProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  // ── Genre / Search results ──────────────────────────────────────────────
  List<MediaItem> _items = [];
  List<MediaItem> get items => _items;

  LoadState _state = LoadState.idle;
  LoadState get state => _state;

  String _error = '';
  String get error => _error;

  String _currentQuery = '';
  String get currentQuery => _currentQuery;

  // ── Trending ────────────────────────────────────────────────────────────
  List<String> _trending = [];
  List<String> get trending => _trending;

  // ── Warm-up (Render free plan wake-up) ─────────────────────────────────
  bool _apiReady = false;
  bool get apiReady => _apiReady;

  Future<void> warmUp() async {
    _apiReady = await _api.warmUp();
    notifyListeners();
  }

  // ── Fetch by genre ──────────────────────────────────────────────────────
  Future<void> loadGenre(String slug, {int count = 30}) async {
    _startLoading('genre:$slug');
    try {
      final res = await _api.fetchGenre(slug, count: count);
      _setItems(res.items);
    } catch (e) {
      _setError(e.toString());
    }
  }

  // ── Search ──────────────────────────────────────────────────────────────
  Future<void> loadSearch(String query, {int count = 30}) async {
    _startLoading('search:$query');
    try {
      final res = await _api.search(query, count: count);
      _setItems(res.items);
    } catch (e) {
      _setError(e.toString());
    }
  }

  // ── Board ───────────────────────────────────────────────────────────────
  Future<void> loadBoard(String boardUrl, {int count = 30}) async {
    _startLoading('board:$boardUrl');
    try {
      final res = await _api.fetchBoard(boardUrl, count: count);
      _setItems(res.items);
    } catch (e) {
      _setError(e.toString());
    }
  }

  // ── Trending ────────────────────────────────────────────────────────────
  Future<void> loadTrending() async {
    _trending = await _api.fetchTrending();
    notifyListeners();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────
  void _startLoading(String query) {
    _state = LoadState.loading;
    _currentQuery = query;
    _error = '';
    notifyListeners();
  }

  void _setItems(List<MediaItem> items) {
    _items = items;
    _state = LoadState.loaded;
    notifyListeners();
  }

  void _setError(String msg) {
    _error = msg;
    _state = LoadState.error;
    notifyListeners();
  }

  void clear() {
    _items = [];
    _state = LoadState.idle;
    _error = '';
    notifyListeners();
  }
}

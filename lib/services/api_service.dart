import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/queue_models.dart';
import '../models/wallpaper.dart';
import 'local_db.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _client = http.Client();
  final _db = LocalDb.instance;

  /// Ping the API so Render wakes up from sleep.
  Future<bool> warmUp() async {
    try {
      final res = await _client
          .get(Uri.parse('$kApiBaseUrl/health'))
          .timeout(const Duration(seconds: 65));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetch wallpapers by genre slug (nature, anime, dark, etc.) with heavy local caching.
  Future<SearchResponse> fetchGenre(
    String slug, {
    int count = 30,
    bool forceRefresh = false,
    bool append = false,
  }) async {
    final cacheKey = 'genre:$slug';
    if (!forceRefresh && !append) {
      final cached = await _db.getCachedItems(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        return SearchResponse(
          query: slug,
          count: cached.length,
          items: cached,
          fromCache: true,
        );
      }
    }

    final uri = Uri.parse('$kApiBaseUrl/genre/$slug').replace(
      queryParameters: {'count': count.toString()},
    );
    final res = await _get(uri);
    if (res.items.isNotEmpty) {
      if (append) {
        await _db.appendCachedItems(cacheKey, res.items);
      } else {
        await _db.setCachedItems(cacheKey, res.items);
      }
    }
    return res;
  }

  /// Search Pinterest wallpapers by keyword with local caching.
  Future<SearchResponse> search(
    String query, {
    int count = 30,
    bool forceRefresh = false,
    bool append = false,
  }) async {
    final clean = query.trim();
    final cacheKey = 'search:${clean.toLowerCase()}';
    if (!forceRefresh && !append) {
      final cached = await _db.getCachedItems(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        return SearchResponse(
          query: clean,
          count: cached.length,
          items: cached,
          fromCache: true,
        );
      }
    }

    final uri = Uri.parse('$kApiBaseUrl/search').replace(
      queryParameters: {'query': clean, 'count': count.toString()},
    );
    final res = await _get(uri);
    if (res.items.isNotEmpty) {
      if (append) {
        await _db.appendCachedItems(cacheKey, res.items);
      } else {
        await _db.setCachedItems(cacheKey, res.items);
      }
    }
    return res;
  }

  /// Fetch wallpapers from a Pinterest board URL, caching results and saving Import History.
  Future<SearchResponse> fetchBoard(
    String boardUrl, {
    int count = 40,
    bool forceRefresh = false,
    bool append = false,
    bool recordHistory = true,
  }) async {
    final cleanUrl = boardUrl.trim();
    final cacheKey = 'board:$cleanUrl';
    if (!forceRefresh && !append) {
      final cached = await _db.getCachedItems(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        if (recordHistory) {
          await _db.upsertImportHistory(
            ImportHistoryEntry(
              boardUrl: cleanUrl,
              title: LocalDb.boardLabelFromUrl(cleanUrl),
              pinCount: cached.length,
              previewUrl: cached.first.url,
              lastImportedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
        }
        return SearchResponse(
          query: cleanUrl,
          count: cached.length,
          items: cached,
          fromCache: true,
        );
      }
    }

    final encoded = Uri.encodeComponent(cleanUrl);
    final uri = Uri.parse('$kApiBaseUrl/board/$encoded').replace(
      queryParameters: {'count': count.toString()},
    );
    final res = await _get(uri);
    if (res.items.isNotEmpty) {
      if (append) {
        await _db.appendCachedItems(cacheKey, res.items);
      } else {
        await _db.setCachedItems(cacheKey, res.items);
      }
      if (recordHistory) {
        await _db.upsertImportHistory(
          ImportHistoryEntry(
            boardUrl: cleanUrl,
            title: LocalDb.boardLabelFromUrl(cleanUrl),
            pinCount: res.items.length,
            previewUrl: res.items.first.url,
            lastImportedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
    }
    return res;
  }

  /// Get related pins for a pin ID with local caching.
  Future<SearchResponse> fetchRelated(
    String pinId, {
    int count = 30,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'related:$pinId';
    if (!forceRefresh) {
      final cached = await _db.getCachedItems(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        return SearchResponse(
          query: pinId,
          count: cached.length,
          items: cached,
          fromCache: true,
        );
      }
    }

    final uri = Uri.parse('$kApiBaseUrl/related').replace(
      queryParameters: {'pin_id': pinId, 'count': count.toString()},
    );
    final res = await _get(uri);
    if (res.items.isNotEmpty) {
      await _db.setCachedItems(cacheKey, res.items);
    }
    return res;
  }

  /// Get trending search queries.
  Future<List<String>> fetchTrending({int limit = 10}) async {
    try {
      final uri = Uri.parse('$kApiBaseUrl/trending').replace(
        queryParameters: {'limit': limit.toString()},
      );
      final res = await _client.get(uri).timeout(const Duration(seconds: 25));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final list = json['trending'] as List;
        return list.map((e) => e['query'] as String).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<SearchResponse> _get(Uri uri) async {
    final res = await _client.get(uri).timeout(const Duration(seconds: 45));
    if (res.statusCode == 200) {
      return SearchResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    throw Exception('API error ${res.statusCode}: ${res.body}');
  }
}

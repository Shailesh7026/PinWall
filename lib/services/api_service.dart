import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/wallpaper.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _client = http.Client();

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

  /// Fetch wallpapers by genre slug (nature, anime, dark, etc.)
  Future<SearchResponse> fetchGenre(String slug, {int count = 30}) async {
    final uri = Uri.parse('$kApiBaseUrl/genre/$slug').replace(
      queryParameters: {'count': count.toString()},
    );
    return _get(uri, slug);
  }

  /// Search Pinterest wallpapers by keyword
  Future<SearchResponse> search(String query, {int count = 30}) async {
    final uri = Uri.parse('$kApiBaseUrl/search').replace(
      queryParameters: {'query': query, 'count': count.toString()},
    );
    return _get(uri, query);
  }

  /// Fetch wallpapers from a Pinterest board URL
  Future<SearchResponse> fetchBoard(String boardUrl, {int count = 30}) async {
    // Encode the board URL as a path segment
    final encoded = Uri.encodeComponent(boardUrl);
    final uri = Uri.parse('$kApiBaseUrl/board/$encoded').replace(
      queryParameters: {'count': count.toString()},
    );
    return _get(uri, boardUrl);
  }

  /// Get related pins for a pin ID
  Future<SearchResponse> fetchRelated(String pinId, {int count = 30}) async {
    final uri = Uri.parse('$kApiBaseUrl/related').replace(
      queryParameters: {'pin_id': pinId, 'count': count.toString()},
    );
    return _get(uri, pinId);
  }

  /// Get trending search queries
  Future<List<String>> fetchTrending({int limit = 10}) async {
    final uri = Uri.parse('$kApiBaseUrl/trending').replace(
      queryParameters: {'limit': limit.toString()},
    );
    final res = await _client.get(uri).timeout(const Duration(seconds: 45));
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final list = json['trending'] as List;
      return list.map((e) => e['query'] as String).toList();
    }
    return [];
  }

  Future<SearchResponse> _get(Uri uri, String fallbackQuery) async {
    final res = await _client.get(uri).timeout(const Duration(seconds: 45));
    if (res.statusCode == 200) {
      return SearchResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    throw Exception('API error ${res.statusCode}: ${res.body}');
  }
}

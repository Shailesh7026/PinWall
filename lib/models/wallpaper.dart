class MediaItem {
  final String? id;
  final String url;
  final int? width;
  final int? height;
  final String? alt;
  final bool isVideo;

  MediaItem({
    this.id,
    required this.url,
    this.width,
    this.height,
    this.alt,
    this.isVideo = false,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id']?.toString(),
      url: json['url'] as String,
      width: json['width'] as int?,
      height: json['height'] as int?,
      alt: json['alt'] as String?,
      isVideo: json['is_video'] as bool? ?? false,
    );
  }
}

class SearchResponse {
  final String query;
  final int count;
  final List<MediaItem> items;

  SearchResponse({
    required this.query,
    required this.count,
    required this.items,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      query: json['query'] as String,
      count: json['count'] as int,
      items: (json['items'] as List)
          .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

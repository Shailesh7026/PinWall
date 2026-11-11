import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_masonry_view/flutter_masonry_view.dart';
import '../models/wallpaper.dart';

/// Masonry grid of wallpaper images from the API.
class WallpaperMasonryGrid extends StatelessWidget {
  final List<MediaItem> items;

  const WallpaperMasonryGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return MasonryView(
      listOfItem: items,
      numberOfColumn: 2,
      itemRadius: 12,
      itemPadding: 4,
      itemBuilder: (item) {
        final media = item as MediaItem;
        final aspectRatio = (media.width != null && media.height != null)
            ? media.width! / media.height!
            : 0.75;
        return AspectRatio(
          aspectRatio: aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: media.url,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: Colors.grey[200],
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Simple 2-column grid (fallback / home screen use).
class WallpaperGridItem extends StatelessWidget {
  final String imageUrl;

  const WallpaperGridItem({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: Colors.grey[200]),
        errorWidget: (_, __, ___) => const Icon(Icons.error),
      ),
    );
  }
}

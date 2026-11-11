import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_masonry_view/flutter_masonry_view.dart';
import '../models/wallpaper.dart';
import 'wallpaper_detail_sheet.dart';

/// Scrollable masonry grid of wallpaper images from the API.
class WallpaperMasonryGrid extends StatelessWidget {
  final List<MediaItem> items;
  final String? sourceBoard;
  final Future<void> Function()? onRefresh;

  const WallpaperMasonryGrid({
    super.key,
    required this.items,
    this.sourceBoard,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(6),
      child: MasonryView(
        listOfItem: items,
        numberOfColumn: 2,
        itemRadius: 12,
        itemPadding: 4,
        itemBuilder: (item) {
          final media = item as MediaItem;
          final aspectRatio = (media.width != null &&
                  media.height != null &&
                  media.height! > 0)
              ? (media.width! / media.height!).clamp(0.45, 1.8)
              : 0.75;
          return GestureDetector(
            onTap: () => showWallpaperDetailSheet(
              context,
              media,
              sourceBoard: sourceBoard,
            ),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: media.url,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (_, _, _) => Container(
                        color: Colors.grey[300],
                        child:
                            const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                    if (media.isVideo)
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.black54,
                          child: Icon(
                            Icons.play_arrow,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (onRefresh != null) {
      return RefreshIndicator(onRefresh: onRefresh!, child: content);
    }
    return content;
  }
}

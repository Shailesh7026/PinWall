import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallpaper_manager_plus/wallpaper_manager_plus.dart';
import '../models/wallpaper.dart';
import '../services/wallpaper_provider.dart';

Future<void> showWallpaperDetailSheet(
  BuildContext context,
  MediaItem item, {
  String? sourceBoard,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _WallpaperDetailSheet(item: item, sourceBoard: sourceBoard),
  );
}

class _WallpaperDetailSheet extends StatefulWidget {
  final MediaItem item;
  final String? sourceBoard;

  const _WallpaperDetailSheet({required this.item, this.sourceBoard});

  @override
  State<_WallpaperDetailSheet> createState() => _WallpaperDetailSheetState();
}

class _WallpaperDetailSheetState extends State<_WallpaperDetailSheet> {
  bool _busy = false;
  String? _statusMsg;

  Future<void> _applyNow(int location, String label) async {
    setState(() {
      _busy = true;
      _statusMsg = 'Applying to $label…';
    });
    try {
      await context.read<WallpaperProvider>().applyImmediate(widget.item, location);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wallpaper set on $label!')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _statusMsg = 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addToQueue(String queueType, String label) async {
    setState(() {
      _busy = true;
      _statusMsg = 'Downloading to $label…';
    });
    try {
      final ok = await context.read<WallpaperProvider>().addWallpaperToQueue(
            widget.item,
            queueType,
            sourceBoard: widget.sourceBoard,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Added to $label!'
                : widget.item.isVideo
                    ? 'Video pins cannot be queued as wallpapers.'
                    : 'Already in $label.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _statusMsg = 'Download failed: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.86;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: InteractiveViewer(
                  child: CachedNetworkImage(
                    imageUrl: widget.item.url,
                    fit: BoxFit.contain,
                    placeholder: (_, _) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (_, _, _) =>
                        const Center(child: Icon(Icons.broken_image, size: 48)),
                  ),
                ),
              ),
            ),
          ),
          if (widget.item.alt != null && widget.item.alt!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                widget.item.alt!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (widget.item.width != null && widget.item.height != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${widget.item.width} × ${widget.item.height}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          if (_statusMsg != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
              child: Text(
                _statusMsg!,
                style: const TextStyle(fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Apply Immediately',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _applyNow(
                            WallpaperManagerPlus.homeScreen,
                            'Home Screen',
                          ),
                          icon: const Icon(Icons.home, size: 18),
                          label: const Text('Home'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _applyNow(
                            WallpaperManagerPlus.lockScreen,
                            'Lock Screen',
                          ),
                          icon: const Icon(Icons.lock, size: 18),
                          label: const Text('Lock'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _applyNow(
                            WallpaperManagerPlus.bothScreens,
                            'Both Screens',
                          ),
                          icon: const Icon(Icons.smartphone, size: 18),
                          label: const Text('Both'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Save & Download to Auto-Queue',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _addToQueue('home', 'Home / Shared Queue'),
                          icon: const Icon(Icons.add_to_queue, size: 18),
                          label: const Text('+ Home Queue'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _addToQueue('lock', 'Lock Queue'),
                          icon: const Icon(Icons.lock_clock, size: 18),
                          label: const Text('+ Lock Queue'),
                        ),
                      ),
                    ],
                  ),
                  if (widget.item.id != null) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        context
                            .read<WallpaperProvider>()
                            .loadRelated(widget.item.id!);
                      },
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Find Related Wallpapers'),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}


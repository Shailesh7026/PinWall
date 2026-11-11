import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallpaper_manager_plus/wallpaper_manager_plus.dart';
import '../models/queue_models.dart';
import '../services/wallpaper_provider.dart';

/// Actual local wallpaper queue gallery:
/// displays downloaded files on disk, active/queued status, queue size limit,
/// auto-delete status, and instant apply/fill/rotate actions.
class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  String _filter = 'all'; // 'all', 'home', 'lock'

  String _diskSizeMb(List<QueuedWallpaper> items) {
    int bytes = 0;
    for (final item in items) {
      final f = File(item.localPath);
      if (f.existsSync()) {
        bytes += f.lengthSync();
      }
    }
    return (bytes / (1024 * 1024)).toStringAsFixed(1);
  }

  Future<void> _runNextNow() async {
    final msg = await context.read<WallpaperProvider>().runAutoCycleNow();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _fillQueues() async {
    final p = context.read<WallpaperProvider>();
    int total = 0;
    if (_filter == 'all' || _filter == 'home') {
      total += await p.syncQueueFromBoards('home');
    }
    if (_filter == 'all' || _filter == 'lock') {
      total += await p.syncQueueFromBoards('lock');
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          total > 0
              ? 'Downloaded $total wallpapers to queue!'
              : 'Nothing new to download (check boards or queue size).',
        ),
      ),
    );
  }

  Future<void> _clearSelected() async {
    final p = context.read<WallpaperProvider>();
    if (_filter == 'all' || _filter == 'home') {
      await p.clearQueue('home');
    }
    if (_filter == 'all' || _filter == 'lock') {
      await p.clearQueue('lock');
    }
  }

  void _openQueuedItemSheet(QueuedWallpaper item) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(item.localPath),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Center(child: Icon(Icons.broken_image, size: 48)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Queue: ${item.queueType.toUpperCase()}  •  Status: ${item.isApplied ? "ACTIVE / APPLIED" : "QUEUED"}'
                '${item.sourceBoard != null ? "\nSource: ${item.sourceBoard}" : ""}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await context.read<WallpaperProvider>().applyQueuedItem(
                              item,
                              WallpaperManagerPlus.homeScreen,
                            );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Applied to Home Screen!'),
                            ),
                          );
                        }
                      },
                      child: const Text('Set Home'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await context.read<WallpaperProvider>().applyQueuedItem(
                              item,
                              WallpaperManagerPlus.lockScreen,
                            );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Applied to Lock Screen!'),
                            ),
                          );
                        }
                      },
                      child: const Text('Set Lock'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await context.read<WallpaperProvider>().applyQueuedItem(
                              item,
                              WallpaperManagerPlus.bothScreens,
                            );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Applied to Both Screens!'),
                            ),
                          );
                        }
                      },
                      child: const Text('Both'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await context
                      .read<WallpaperProvider>()
                      .deleteQueuedItem(item);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete from Disk'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue Gallery'),
        actions: [
          IconButton(
            tooltip: 'Clear visible queue',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _clearSelected,
          ),
        ],
      ),
      body: Consumer<WallpaperProvider>(
        builder: (context, provider, _) {
          final visible = switch (_filter) {
            'home' => provider.homeQueue,
            'lock' => provider.lockQueue,
            _ => [...provider.homeQueue, ...provider.lockQueue],
          };
          final s = provider.settings;

          return Column(
            children: [
              // ── Summary & Controls Card ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Home: ${provider.homeQueue.length}/${s.queueMaxSize}  •  '
                                'Lock: ${provider.lockQueue.length}/${s.queueMaxSize}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              '${_diskSizeMb(visible)} MB',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                s.autoDownloadEnabled
                                    ? 'Auto-Download: ON'
                                    : 'Auto-Download: OFF',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                s.autoDeleteApplied
                                    ? 'Auto-Delete: ON'
                                    : 'Auto-Delete: OFF',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                'Max: ${s.queueMaxSize}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        if (s.lastStatusMessage != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Last run: ${s.lastStatusMessage}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        if (provider.isSyncingQueue)
                          const LinearProgressIndicator()
                        else
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _fillQueues,
                                  icon: const Icon(Icons.downloading, size: 18),
                                  label: const Text('Fill from Boards'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _runNextNow,
                                  icon: const Icon(Icons.skip_next, size: 18),
                                  label: const Text('Apply Next Now'),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Filter Chips ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    for (final entry in const [
                      ('all', 'All'),
                      ('home', 'Home Queue'),
                      ('lock', 'Lock Queue'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(entry.$2),
                          selected: _filter == entry.$1,
                          onSelected: (_) =>
                              setState(() => _filter = entry.$1),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Local Disk Gallery Grid ─────────────────────────────────
              Expanded(
                child: visible.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No wallpapers in queue yet.\n'
                            'Browse Explore to add pins, or add boards in the Boards tab and tap "Fill from Boards".',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(10),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.65,
                        ),
                        itemCount: visible.length,
                        itemBuilder: (_, i) {
                          final item = visible[i];
                          final file = File(item.localPath);
                          return GestureDetector(
                            onTap: () => _openQueuedItemSheet(item),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (file.existsSync())
                                    Image.file(file, fit: BoxFit.cover)
                                  else
                                    Container(
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.broken_image),
                                    ),
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: item.isApplied
                                            ? Colors.green
                                            : Colors.black87,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        item.isApplied
                                            ? 'ACTIVE'
                                            : item.queueType.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}


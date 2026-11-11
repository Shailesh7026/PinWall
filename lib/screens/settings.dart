import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/queue_models.dart';
import '../services/wallpaper_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _intervals = <int, String>{
    15: 'Every 15 minutes',
    30: 'Every 30 minutes',
    60: 'Every 1 hour',
    180: 'Every 3 hours',
    360: 'Every 6 hours',
    720: 'Every 12 hours',
    1440: 'Every 24 hours',
  };

  static const _queueSizes = [10, 15, 20, 25, 30, 50];

  String _modeLabel(QueueMode m) => switch (m) {
        QueueMode.bothSingleQueue => 'Single Queue → Both Home & Lock',
        QueueMode.homeOnly => 'Single Queue → Home Screen Only',
        QueueMode.lockOnly => 'Lock Queue → Lock Screen Only',
        QueueMode.separateQueues => 'Dual Queues → Separate Home & Lock',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auto-Changer & Settings')),
      body: Consumer<WallpaperProvider>(
        builder: (context, provider, _) {
          final s = provider.settings;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // ── Auto Wallpaper Changer ──────────────────────────────────
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text(
                        'Auto Wallpaper Changer',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Automatically downloads, applies & rotates wallpapers in the background',
                      ),
                      value: s.autoChangeEnabled,
                      onChanged: (v) async {
                        await provider.updateSettings(
                          s.copyWith(autoChangeEnabled: v),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                v
                                    ? 'Auto-changer scheduled (${_intervals[s.intervalMinutes] ?? "${s.intervalMinutes} min"})!'
                                    : 'Auto-changer paused.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.timer_outlined),
                      title: const Text('Rotation Interval'),
                      trailing: DropdownButton<int>(
                        value: _intervals.containsKey(s.intervalMinutes)
                            ? s.intervalMinutes
                            : 60,
                        underline: const SizedBox.shrink(),
                        items: _intervals.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            provider.updateSettings(
                              s.copyWith(intervalMinutes: v),
                            );
                          }
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.layers_outlined),
                      title: const Text('Target & Queue Mode'),
                      subtitle: Text(_modeLabel(s.queueMode)),
                      trailing: DropdownButton<QueueMode>(
                        value: s.queueMode,
                        underline: const SizedBox.shrink(),
                        items: QueueMode.values
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(
                                  switch (m) {
                                    QueueMode.bothSingleQueue => 'Both (1 Queue)',
                                    QueueMode.homeOnly => 'Home Only',
                                    QueueMode.lockOnly => 'Lock Only',
                                    QueueMode.separateQueues => 'Dual (2 Queues)',
                                  },
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            provider.updateSettings(s.copyWith(queueMode: v));
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Queue & Storage Rules ───────────────────────────────────
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.cloud_download_outlined),
                      title: const Text('Auto-Download from Queue Boards'),
                      subtitle: const Text(
                        'Randomly picks from your assigned boards to keep queues full',
                      ),
                      value: s.autoDownloadEnabled,
                      onChanged: (v) => provider.updateSettings(
                        s.copyWith(autoDownloadEnabled: v),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.collections_bookmark_outlined),
                      title: const Text('Max Queue Size'),
                      subtitle: const Text(
                        'Wallpapers kept downloaded per queue before pruning oldest',
                      ),
                      trailing: DropdownButton<int>(
                        value: _queueSizes.containsKeyValue(s.queueMaxSize)
                            ? s.queueMaxSize
                            : 20,
                        underline: const SizedBox.shrink(),
                        items: _queueSizes
                            .map(
                              (n) => DropdownMenuItem(
                                value: n,
                                child: Text('$n wallpapers'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            provider.updateSettings(
                              s.copyWith(queueMaxSize: v),
                            );
                          }
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.auto_delete_outlined),
                      title: const Text('Auto-Delete Applied Wallpapers'),
                      subtitle: const Text(
                        'Deletes previously applied wallpapers from disk once rotated out',
                      ),
                      value: s.autoDeleteApplied,
                      onChanged: (v) => provider.updateSettings(
                        s.copyWith(autoDeleteApplied: v),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Manual Test & Status ────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Test & Status',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.lastStatusMessage != null
                            ? 'Last cycle: ${s.lastStatusMessage}'
                            : 'No rotation cycle run yet.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: provider.isSyncingQueue
                            ? null
                            : () async {
                                final msg = await provider.runAutoCycleNow();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(msg)),
                                  );
                                }
                              },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Run Auto-Rotation Cycle Now'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Heavy Cache Management ──────────────────────────────────
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cached),
                  title: const Text('Local API & Board Cache'),
                  subtitle: Text(
                    '${provider.apiCacheCount} cached queries/boards • ${provider.importHistory.length} saved in history',
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      await provider.clearApiCache();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('API cache cleared!')),
                        );
                      }
                    },
                    child: const Text('Clear Cache'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

extension _ListContainsExt on List<int> {
  bool containsKeyValue(int val) => contains(val);
}

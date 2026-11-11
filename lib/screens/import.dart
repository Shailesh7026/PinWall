import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinwall/models/queue_models.dart';
import 'package:pinwall/services/wallpaper_provider.dart';
import 'package:pinwall/widgets/wallpaper_grid.dart';

/// Boards & Import screen:
/// - Paste a Pinterest board URL to preview & cache it
/// - Assign multiple boards to Home Queue and/or Lock Queue
/// - Re-open cached Import History without hitting the API
class ImportScreen extends StatefulWidget {
  final VoidCallback? onImportComplete;

  const ImportScreen({super.key, this.onImportComplete});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _urlController = TextEditingController();
  String _selectedQueueTarget = 'home'; // 'home', 'lock', 'both'

  String? _validUrlOrNull() {
    final url = _urlController.text.trim();
    final parsed = Uri.tryParse(url);
    if (url.isEmpty || parsed == null || !parsed.hasScheme) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid Pinterest board URL.'),
        ),
      );
      return null;
    }
    return url;
  }

  Future<void> _importAndPreview({bool forceRefresh = false}) async {
    final url = _validUrlOrNull();
    if (url == null) return;
    FocusScope.of(context).unfocus();
    await context
        .read<WallpaperProvider>()
        .importBoard(url, forceRefresh: forceRefresh);
  }

  Future<void> _addBoardToQueue() async {
    final url = _validUrlOrNull();
    if (url == null) return;
    FocusScope.of(context).unfocus();
    final provider = context.read<WallpaperProvider>();

    if (_selectedQueueTarget == 'home' || _selectedQueueTarget == 'both') {
      await provider.addBoardToQueue('home', url);
    }
    if (_selectedQueueTarget == 'lock' || _selectedQueueTarget == 'both') {
      await provider.addBoardToQueue('lock', url);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Board added to ${_selectedQueueTarget.toUpperCase()} queue!',
        ),
      ),
    );
    // Also import & cache it so history & pins are ready
    await provider.importBoard(url);
  }

  Future<void> _openHistoryBoard(ImportHistoryEntry entry) async {
    _urlController.text = entry.boardUrl;
    await context.read<WallpaperProvider>().importBoard(entry.boardUrl);
  }

  Future<void> _downloadRandomBatch(String queueType) async {
    final provider = context.read<WallpaperProvider>();
    final count = await provider.syncQueueFromBoards(queueType);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count > 0
              ? 'Downloaded $count new wallpapers into ${queueType.toUpperCase()} queue!'
              : 'Queue is full or no new pins found.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boards & Import'),
        actions: [
          if (widget.onImportComplete != null)
            TextButton(
              onPressed: widget.onImportComplete,
              child: const Text('Queue →'),
            ),
        ],
      ),
      body: Consumer<WallpaperProvider>(
        builder: (context, provider, _) {
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              // ── Board URL Input Card ────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Import Pinterest Board',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _urlController,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => _importAndPreview(),
                        decoration: InputDecoration(
                          labelText: 'Pinterest Board URL',
                          hintText:
                              'https://www.pinterest.com/username/board-name/',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.link),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _urlController.clear(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'home',
                            label: Text('Home / Shared'),
                            icon: Icon(Icons.home, size: 16),
                          ),
                          ButtonSegment(
                            value: 'lock',
                            label: Text('Lock'),
                            icon: Icon(Icons.lock, size: 16),
                          ),
                          ButtonSegment(
                            value: 'both',
                            label: Text('Both'),
                            icon: Icon(Icons.smartphone, size: 16),
                          ),
                        ],
                        selected: {_selectedQueueTarget},
                        onSelectionChanged: (s) =>
                            setState(() => _selectedQueueTarget = s.first),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _importAndPreview,
                              icon: const Icon(Icons.visibility),
                              label: const Text('Preview'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _addBoardToQueue,
                              icon: const Icon(Icons.playlist_add),
                              label: const Text('Add to Queue'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Active Queue Boards ─────────────────────────────────────
              _QueueBoardsCard(
                title: 'Home / Shared Queue Boards',
                icon: Icons.home,
                boards: provider.homeBoards,
                busy: provider.isSyncingQueue,
                onSync: () => _downloadRandomBatch('home'),
                onRemove: (id) => provider.removeBoardFromQueue(id),
              ),
              const SizedBox(height: 10),
              _QueueBoardsCard(
                title: 'Lock Screen Queue Boards',
                icon: Icons.lock,
                boards: provider.lockBoards,
                busy: provider.isSyncingQueue,
                onSync: () => _downloadRandomBatch('lock'),
                onRemove: (id) => provider.removeBoardFromQueue(id),
              ),

              // ── Import History (Cached) ─────────────────────────────────
              if (provider.importHistory.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.history, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Import History (Cached)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 102,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: provider.importHistory.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final entry = provider.importHistory[i];
                      return InkWell(
                        onTap: () => _openHistoryBoard(entry),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 210,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: entry.previewUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: entry.previewUrl!,
                                        width: 56,
                                        height: 84,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, _, _) =>
                                            const Icon(Icons.photo),
                                      )
                                    : Container(
                                        width: 56,
                                        height: 84,
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.photo),
                                      ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      entry.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${entry.pinCount} pins cached',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
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

              // ── Board Preview Grid ──────────────────────────────────────
              if (provider.boardState == LoadState.loading) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 8),
                const Center(child: Text('Loading board pins…')),
              ] else if (provider.boardState == LoadState.error) ...[
                const SizedBox(height: 16),
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Import error: ${provider.boardError}',
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),
                ),
              ] else if (provider.boardState == LoadState.loaded &&
                  provider.boardItems.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Board Preview (${provider.boardItems.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        provider.boardFromCache ? 'From Cache' : 'Live Scrape',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh board from API',
                      icon: const Icon(Icons.refresh),
                      onPressed: () => _importAndPreview(forceRefresh: true),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 460,
                  child: WallpaperMasonryGrid(
                    items: provider.boardItems,
                    sourceBoard: _urlController.text.trim(),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _QueueBoardsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<QueueBoard> boards;
  final bool busy;
  final VoidCallback onSync;
  final ValueChanged<int> onRemove;

  const _QueueBoardsCard({
    required this.title,
    required this.icon,
    required this.boards,
    required this.busy,
    required this.onSync,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFFE60023)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$title (${boards.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (boards.isNotEmpty)
                  TextButton.icon(
                    onPressed: busy ? null : onSync,
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download Batch'),
                  ),
              ],
            ),
            if (boards.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'No boards added yet. Paste a board URL above and tap "Add to Queue".',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: boards
                    .map(
                      (b) => Chip(
                        label: Text(
                          b.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: b.id != null ? () => onRemove(b.id!) : null,
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinwall/services/wallpaper_provider.dart';
import 'package:pinwall/widgets/wallpaper_grid.dart';

/// Import screen — user pastes a Pinterest board URL,
/// the API scrapes it and returns wallpaper images.
class ImportScreen extends StatefulWidget {
  final VoidCallback? onImportComplete;

  const ImportScreen({super.key, this.onImportComplete});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _urlController = TextEditingController();
  bool _hasLoaded = false;

  void _startImport() {
    final url = _urlController.text.trim();
    if (url.isEmpty || !(Uri.tryParse(url)?.hasScheme ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid Pinterest board URL.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _hasLoaded = false);
    context.read<WallpaperProvider>().loadBoard(url).then((_) {
      if (mounted) setState(() => _hasLoaded = true);
    });
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
        title: const Text('Import from Board'),
        actions: [
          if (_hasLoaded)
            TextButton(
              onPressed: () {
                widget.onImportComplete?.call();
              },
              child: const Text('Done'),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── URL input ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _startImport(),
                  decoration: const InputDecoration(
                    labelText: 'Pinterest Board URL',
                    hintText: 'https://www.pinterest.com/username/board-name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _startImport,
                  icon: const Icon(Icons.download),
                  label: const Text('Import Wallpapers'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE60023),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Results ──────────────────────────────────────────────────
          Expanded(
            child: Consumer<WallpaperProvider>(
              builder: (context, provider, _) {
                switch (provider.state) {
                  case LoadState.loading:
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Scraping Pinterest board…'),
                        ],
                      ),
                    );
                  case LoadState.error:
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 12),
                          const Text('Failed to load board.\nCheck the URL and try again.',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _startImport,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  case LoadState.loaded when provider.items.isEmpty:
                    return const Center(child: Text('No images found in this board.'));
                  case LoadState.loaded:
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 8),
                              Text('Found ${provider.items.length} wallpapers',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Expanded(child: WallpaperMasonryGrid(items: provider.items)),
                      ],
                    );
                  default:
                    return const Center(
                      child: Text(
                        'Paste a Pinterest board URL above and tap Import.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

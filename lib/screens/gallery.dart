import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinwall/services/wallpaper_provider.dart';
import 'package:pinwall/widgets/wallpaper_grid.dart';
import 'package:pinwall/constants.dart';

/// Gallery screen — browse by genre with Load More support.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  String _selectedGenre = kGenres.first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WallpaperProvider>().loadGenre(_selectedGenre);
    });
  }

  void _selectGenre(String slug) {
    setState(() => _selectedGenre = slug);
    context.read<WallpaperProvider>().loadGenre(slug);
  }

  void _loadMore() {
    context.read<WallpaperProvider>().loadGenre(_selectedGenre);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: kGenres.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final slug = kGenres[i];
                final selected = slug == _selectedGenre;
                return ChoiceChip(
                  label: Text(
                    slug[0].toUpperCase() + slug.substring(1),
                    style: TextStyle(
                      color: selected ? Colors.white : null,
                      fontWeight: selected ? FontWeight.bold : null,
                    ),
                  ),
                  selected: selected,
                  selectedColor: const Color(0xFFE60023),
                  onSelected: (_) => _selectGenre(slug),
                );
              },
            ),
          ),
        ),
      ),
      body: Consumer<WallpaperProvider>(
        builder: (context, provider, _) {
          switch (provider.state) {
            case LoadState.loading:
              return const Center(child: CircularProgressIndicator());
            case LoadState.error:
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('Failed to load. Try again.'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _selectGenre(_selectedGenre),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            case LoadState.loaded when provider.items.isEmpty:
              return const Center(child: Text('No wallpapers found.'));
            case LoadState.loaded:
              return Column(
                children: [
                  Expanded(child: WallpaperMasonryGrid(items: provider.items)),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: ElevatedButton.icon(
                      onPressed: _loadMore,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Load More'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ),
                ],
              );
            default:
              return const SizedBox.shrink();
          }
        },
      ),
    );
  }
}

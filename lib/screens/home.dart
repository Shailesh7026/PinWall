import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinwall/services/wallpaper_provider.dart';
import 'package:pinwall/widgets/wallpaper_grid.dart';
import 'package:pinwall/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _selectedGenre = kGenres.first;

  @override
  void initState() {
    super.initState();
    // Load default genre on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WallpaperProvider>().loadGenre(_selectedGenre);
    });
  }

  void _onGenreSelected(String slug) {
    setState(() => _selectedGenre = slug);
    context.read<WallpaperProvider>().loadGenre(slug);
  }

  void _onSearch() {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    context.read<WallpaperProvider>().loadSearch(q);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PinWall'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              // ── Search bar ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _onSearch(),
                  decoration: InputDecoration(
                    hintText: 'Search wallpapers…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: _onSearch,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              // ── Genre chips ──────────────────────────────────────────
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: kGenres.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
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
                      onSelected: (_) => _onGenreSelected(slug),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
            ],
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
                    Text(
                      'Failed to load.\nCheck your connection.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _onGenreSelected(_selectedGenre),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            case LoadState.loaded when provider.items.isEmpty:
              return const Center(child: Text('No wallpapers found.'));
            case LoadState.loaded:
              return WallpaperMasonryGrid(items: provider.items);
            default:
              return const SizedBox.shrink();
          }
        },
      ),
    );
  }
}

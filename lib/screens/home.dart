import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinwall/constants.dart';
import 'package:pinwall/services/wallpaper_provider.dart';
import 'package:pinwall/widgets/wallpaper_grid.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _selectedGenre = kGenres.first;
  String? _activeSearch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<WallpaperProvider>();
      p.loadGenre(_selectedGenre);
      p.loadTrending();
    });
  }

  void _onGenreSelected(String slug, {bool forceRefresh = false}) {
    setState(() {
      _selectedGenre = slug;
      _activeSearch = null;
    });
    context
        .read<WallpaperProvider>()
        .loadGenre(slug, forceRefresh: forceRefresh);
  }

  void _onSearch({String? overrideQuery, bool forceRefresh = false}) {
    final q = (overrideQuery ?? _searchController.text).trim();
    if (q.isEmpty) return;
    _searchController.text = q;
    FocusScope.of(context).unfocus();
    setState(() => _activeSearch = q);
    context.read<WallpaperProvider>().loadSearch(q, forceRefresh: forceRefresh);
  }

  Future<void> _forceRefresh() async {
    if (_activeSearch != null) {
      await context
          .read<WallpaperProvider>()
          .loadSearch(_activeSearch!, forceRefresh: true);
    } else {
      await context
          .read<WallpaperProvider>()
          .loadGenre(_selectedGenre, forceRefresh: true);
    }
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
        title: const Text('PinWall Explore'),
        actions: [
          Consumer<WallpaperProvider>(
            builder: (_, provider, _) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  if (provider.state == LoadState.loaded)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                        provider.fromCache
                            ? Icons.offline_bolt
                            : Icons.cloud_done,
                        size: 16,
                      ),
                      label: Text(
                        provider.fromCache ? 'Cached' : 'Live',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Force refresh from API',
                    icon: const Icon(Icons.refresh),
                    onPressed: _forceRefresh,
                  ),
                ],
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _onSearch(),
                  decoration: InputDecoration(
                    hintText: 'Search Pinterest wallpapers…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _onGenreSelected(_selectedGenre);
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: _onSearch,
                        ),
                      ],
                    ),
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.45),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: kGenres.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final slug = kGenres[i];
                    final selected =
                        _activeSearch == null && slug == _selectedGenre;
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
          return Column(
            children: [
              if (provider.trending.isNotEmpty)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.trending_up,
                            size: 16,
                            color: Color(0xFFE60023),
                          ),
                        ),
                      ),
                      ...provider.trending.map(
                        (t) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            visualDensity: VisualDensity.compact,
                            label: Text(t, style: const TextStyle(fontSize: 12)),
                            onPressed: () => _onSearch(overrideQuery: t),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: switch (provider.state) {
                  LoadState.loading =>
                    const Center(child: CircularProgressIndicator()),
                  LoadState.error => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.wifi_off,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Failed to load.\n${provider.error}',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _forceRefresh,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  LoadState.loaded when provider.items.isEmpty =>
                    const Center(child: Text('No wallpapers found.')),
                  LoadState.loaded => WallpaperMasonryGrid(
                      items: provider.items,
                      onRefresh: _forceRefresh,
                    ),
                  _ => const SizedBox.shrink(),
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

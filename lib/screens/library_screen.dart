import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/catalog_item.dart';
import '../services/turso_service.dart';
import '../widgets/catalog_card.dart';
import '../widgets/empty_state.dart';
import 'scan_screen.dart';
import 'detail_screen.dart';

class LibraryProvider extends ChangeNotifier {
  final TursoService _turso = TursoService();
  List<CatalogItem> _items = [];
  List<CatalogItem> _filteredItems = [];
  bool _isLoading = true;
  String _searchQuery = '';
  CatalogType? _typeFilter;
  String? _error;

  List<CatalogItem> get items => _filteredItems;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  CatalogType? get typeFilter => _typeFilter;

  Future<void> loadItems() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _turso.initializeDatabase();
      final items = await _turso.getAllItems(
        onSyncComplete: (syncedItems) {
          // ignore: avoid_print
          print('[LibraryProvider] Background sync complete, refreshing UI with ${syncedItems.length} items');
          setItems(syncedItems);
        },
      );
      // ignore: avoid_print
      print('[LibraryProvider] loadItems: got ${items.length} items from DB');
      setItems(items);
    } catch (e) {
      // ignore: avoid_print
      print('[LibraryProvider] loadItems error: $e');
      setError('Failed to load library: $e');
    }
  }

  void setItems(List<CatalogItem> items) {
    _items = items;
    _applyFilters();
    _isLoading = false;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  void setTypeFilter(CatalogType? type) {
    _typeFilter = type;
    _applyFilters();
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadItems();
  }

  void _applyFilters() {
    var result = _items.toList();

    if (_typeFilter != null) {
      result = result.where((item) => item.type == _typeFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((item) {
        return item.title.toLowerCase().contains(query) ||
            item.authors.any((a) => a.toLowerCase().contains(query)) ||
            item.isbn.contains(query);
      }).toList();
    }

    _filteredItems = result;
  }

  void removeItem(String id) {
    _items.removeWhere((item) => item.id == id);
    _applyFilters();
    notifyListeners();
  }
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<LibraryProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('MateBooks'),
            centerTitle: false,
            actions: [
              if (provider.items.isNotEmpty)
                PopupMenuButton<CatalogType?>(
                  icon: const Icon(Icons.filter_list),
                  onSelected: (type) => provider.setTypeFilter(type),
                  itemBuilder: (context) => [
                    CheckedPopupMenuItem<CatalogType?>(
                      value: null,
                      checked: provider.typeFilter == null,
                      child: const Text('All'),
                    ),
                    CheckedPopupMenuItem<CatalogType?>(
                      value: CatalogType.book,
                      checked: provider.typeFilter == CatalogType.book,
                      child: const Text('Books'),
                    ),
                    CheckedPopupMenuItem<CatalogType?>(
                      value: CatalogType.magazine,
                      checked: provider.typeFilter == CatalogType.magazine,
                      child: const Text('Magazines'),
                    ),
                  ],
                ),
            ],
          ),
          body: Column(
            children: [
              // Search bar
              if (provider.items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SearchBar(
                    controller: _searchController,
                    hintText: 'Search by title, author, or ISBN...',
                    leading: const Icon(Icons.search),
                    trailing: [
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            provider.setSearchQuery('');
                          },
                        ),
                    ],
                    onChanged: provider.setSearchQuery,
                  ),
                ),
              // Content
              Expanded(
                child: _buildContent(provider, colorScheme),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _navigateToScan(context),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan ISBN'),
          ),
        );
      },
    );
  }

  Widget _buildContent(LibraryProvider provider, ColorScheme colorScheme) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(provider.error!, style: TextStyle(color: colorScheme.error)),
          ],
        ),
      );
    }

    if (provider.items.isEmpty) {
      return EmptyState(
        actionLabel: 'Scan First Book',
        onAction: () => _navigateToScan(context),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadItems(),
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: provider.items.length,
        itemBuilder: (context, index) {
          final item = provider.items[index];
          return CatalogCard(
            item: item,
            onTap: () => _navigateToDetail(context, item),
          );
        },
      ),
    );
  }

  Future<void> _navigateToScan(BuildContext context) async {
    final nav = Navigator.of(context);
    final provider = context.read<LibraryProvider>();
    final result = await nav.push<CatalogItem>(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (result != null && mounted) {
      // Reload library data after adding a new item
      await provider.loadItems();
      nav.push(
        MaterialPageRoute(builder: (_) => DetailScreen(item: result)),
      );
    }
  }

  void _navigateToDetail(BuildContext context, CatalogItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
    );
  }
}

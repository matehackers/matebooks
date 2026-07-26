import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/catalog_item.dart';
import '../services/turso_service.dart';
import 'edit_screen.dart';
import 'library_screen.dart';

class DetailScreen extends StatefulWidget {
  final CatalogItem item;

  const DetailScreen({super.key, required this.item});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late CatalogItem _item;
  final TursoService _turso = TursoService();

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.type == CatalogType.magazine ? 'Magazine' : 'Book'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editItem,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteItem,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            _buildCover(),
            const SizedBox(height: 16),
            // Back cover image if available
            if (_item.backImageBase64 != null) ...[
              _buildBackCover(),
              const SizedBox(height: 16),
            ],
            // Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type badge
                  Row(
                    children: [
                      _buildTypeChip(colorScheme),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Title
                  Text(
                    _item.title,
                    style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // Authors
                  if (_item.authors.isNotEmpty)
                    Text(
                      _item.authors.join(', '),
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Metadata
                  _buildMetadataSection(colorScheme, textTheme),
                  const SizedBox(height: 24),
                  // Description
                  if (_item.description != null && _item.description!.isNotEmpty) ...[
                    Text('Description', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      _item.description!,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // Categories
                  if (_item.categories.isNotEmpty) ...[
                    Text('Categories', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _item.categories.map((cat) {
                        return Chip(
                          label: Text(cat, style: const TextStyle(fontSize: 12)),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // Notes
                  if (_item.notes != null && _item.notes!.isNotEmpty) ...[
                    Text('Your Notes', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      _item.notes!,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // ISBN
                  Text(
                    'ISBN: ${_item.isbn}',
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover() {
    // Priority: base64 photo > network URL > placeholder
    if (_item.coverImageBase64 != null) {
      return _buildBase64Image(_item.coverImageBase64!);
    }
    if (_item.coverUrl != null && _item.coverUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _item.coverUrl!,
        fit: BoxFit.contain,
        height: 300,
        width: double.infinity,
        placeholder: (context, url) => Container(
          height: 300,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => _buildPlaceholderCover(),
      );
    }
    return _buildPlaceholderCover();
  }

  Widget _buildBackCover() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Back Cover',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        _buildBase64Image(_item.backImageBase64!),
      ],
    );
  }

  Widget _buildBase64Image(String base64Str) {
    Uint8List? bytes;
    try {
      bytes = base64Decode(base64Str);
    } catch (_) {
      return _buildPlaceholderCover();
    }
    return Container(
      height: 300,
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: InteractiveViewer(
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholderCover(),
        ),
      ),
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      height: 300,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          _item.type == CatalogType.magazine ? Icons.auto_stories : Icons.menu_book,
          size: 80,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildTypeChip(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _item.type == CatalogType.magazine
            ? Colors.orange.withValues(alpha: 0.15)
            : Colors.blue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _item.type == CatalogType.magazine ? 'Magazine' : 'Book',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: _item.type == CatalogType.magazine ? Colors.orange.shade800 : Colors.blue.shade800,
        ),
      ),
    );
  }

  Widget _buildMetadataSection(ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _metadataRow(Icons.business, 'Publisher', _item.publisher ?? 'Unknown'),
            const Divider(),
            _metadataRow(Icons.calendar_today, 'Published', _item.publishedDate ?? 'Unknown'),
            const Divider(),
            _metadataRow(Icons.description, 'Pages', _item.pageCount?.toString() ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _metadataRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text('$label: ', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
      ],
    );
  }

  Future<void> _editItem() async {
    final provider = context.read<LibraryProvider>();
    final result = await Navigator.push<CatalogItem>(
      context,
      MaterialPageRoute(builder: (_) => EditScreen(item: _item)),
    );
    if (result != null) {
      setState(() => _item = result);
      provider.loadItems();
    }
  }

  Future<void> _deleteItem() async {
    final provider = context.read<LibraryProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${_item.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _turso.deleteItem(_item.id);
      provider.loadItems();
      if (mounted) Navigator.pop(context);
    }
  }
}

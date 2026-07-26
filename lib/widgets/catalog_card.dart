import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/catalog_item.dart';

class CatalogCard extends StatelessWidget {
  final CatalogItem item;
  final VoidCallback onTap;

  const CatalogCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            Expanded(
              child: _buildCover(colorScheme),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildTypeChip(colorScheme),
                      const Spacer(),
                      Icon(Icons.chevron_right, size: 18, color: colorScheme.onSurfaceVariant),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(ColorScheme colorScheme) {
    if (item.coverImageBase64 != null) {
      return Image.memory(
        base64Decode(item.coverImageBase64!),
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) => _placeholderCover(colorScheme),
      );
    }
    if (item.coverUrl != null && item.coverUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: item.coverUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (context, url) => Container(
          color: colorScheme.surfaceContainerHighest,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (context, url, error) => _placeholderCover(colorScheme),
      );
    }
    return _placeholderCover(colorScheme);
  }

  Widget _placeholderCover(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          item.type == CatalogType.magazine ? Icons.auto_stories : Icons.menu_book,
          size: 48,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildTypeChip(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: item.type == CatalogType.magazine
            ? Colors.orange.withValues(alpha: 0.15)
            : Colors.blue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        item.type == CatalogType.magazine ? 'Magazine' : 'Book',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: item.type == CatalogType.magazine ? Colors.orange.shade800 : Colors.blue.shade800,
        ),
      ),
    );
  }
}

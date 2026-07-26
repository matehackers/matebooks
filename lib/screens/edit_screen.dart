import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/catalog_item.dart';
import '../services/data_lookup_service.dart';
import '../services/turso_service.dart';

class EditScreen extends StatefulWidget {
  final CatalogItem? item;
  final String? isbn;

  const EditScreen({super.key, this.item, this.isbn});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorsController = TextEditingController();
  final _publisherController = TextEditingController();
  final _publishedDateController = TextEditingController();
  final _pageCountController = TextEditingController();
  final _isbnController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoriesController = TextEditingController();
  final _notesController = TextEditingController();
  final _coverUrlController = TextEditingController();

  CatalogType _type = CatalogType.book;
  bool _isSaving = false;
  bool _isSearching = false;

  String? _coverImageBase64;
  String? _backImageBase64;

  final TursoService _turso = TursoService();
  final DataLookupService _dataLookup = DataLookupService();
  final ImagePicker _picker = ImagePicker();

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final item = widget.item!;
      _titleController.text = item.title;
      _authorsController.text = item.authors.join(', ');
      _publisherController.text = item.publisher ?? '';
      _publishedDateController.text = item.publishedDate ?? '';
      _pageCountController.text = item.pageCount?.toString() ?? '';
      _isbnController.text = item.isbn;
      _descriptionController.text = item.description ?? '';
      _categoriesController.text = item.categories.join(', ');
      _notesController.text = item.notes ?? '';
      _coverUrlController.text = item.coverUrl ?? '';
      _type = item.type;
      _coverImageBase64 = item.coverImageBase64;
      _backImageBase64 = item.backImageBase64;
    } else if (widget.isbn != null) {
      _isbnController.text = widget.isbn!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorsController.dispose();
    _publisherController.dispose();
    _publishedDateController.dispose();
    _pageCountController.dispose();
    _isbnController.dispose();
    _descriptionController.dispose();
    _categoriesController.dispose();
    _notesController.dispose();
    _coverUrlController.dispose();
    super.dispose();
  }

  Future<void> _takeCoverPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1024, maxHeight: 1024);
    if (file != null) {
      final bytes = await File(file.path).readAsBytes();
      setState(() {
        _coverImageBase64 = base64Encode(bytes);
      });
    }
  }

  Future<void> _takeBackPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1024, maxHeight: 1024);
    if (file != null) {
      final bytes = await File(file.path).readAsBytes();
      setState(() {
        _backImageBase64 = base64Encode(bytes);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Item' : 'Add Item'),
        actions: [
          if (!_isEditing && _isbnController.text.isNotEmpty)
            IconButton(
              icon: _isSearching
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_download),
              tooltip: 'Auto-fetch from online sources',
              onPressed: _fetchFromOnlineSources,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type selector
            SegmentedButton<CatalogType>(
              segments: const [
                ButtonSegment(value: CatalogType.book, label: Text('Book'), icon: Icon(Icons.menu_book)),
                ButtonSegment(value: CatalogType.magazine, label: Text('Magazine'), icon: Icon(Icons.auto_stories)),
              ],
              selected: {_type},
              onSelectionChanged: (selected) => setState(() => _type = selected.first),
            ),
            const SizedBox(height: 16),

            // ISBN
            TextFormField(
              controller: _isbnController,
              decoration: const InputDecoration(
                labelText: 'ISBN / ISSN',
                hintText: '978-3-16-148410-0',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9Xx]'))],
              validator: (v) => v == null || v.isEmpty ? 'ISBN is required' : null,
            ),
            const SizedBox(height: 16),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),

            // Authors
            TextFormField(
              controller: _authorsController,
              decoration: const InputDecoration(
                labelText: 'Authors',
                hintText: 'Separate multiple authors with commas',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.people),
              ),
            ),
            const SizedBox(height: 16),

            // Publisher & Date
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _publisherController,
                    decoration: const InputDecoration(
                      labelText: 'Publisher',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _publishedDateController,
                    decoration: const InputDecoration(
                      labelText: 'Published Date',
                      hintText: '2024',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Page count
            TextFormField(
              controller: _pageCountController,
              decoration: const InputDecoration(
                labelText: 'Page Count',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),

            // Cover URL
            TextFormField(
              controller: _coverUrlController,
              decoration: const InputDecoration(
                labelText: 'Cover Image URL',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.image),
              ),
            ),
            const SizedBox(height: 16),

            // Cover & Back photo buttons
            Row(
              children: [
                Expanded(
                  child: _buildPhotoButton(
                    label: 'Cover Photo',
                    base64: _coverImageBase64,
                    onTake: _takeCoverPhoto,
                    onClear: () => setState(() => _coverImageBase64 = null),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPhotoButton(
                    label: 'Back Photo',
                    base64: _backImageBase64,
                    onTake: _takeBackPhoto,
                    onClear: () => setState(() => _backImageBase64 = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Categories
            TextFormField(
              controller: _categoriesController,
              decoration: const InputDecoration(
                labelText: 'Categories',
                hintText: 'Separate with commas: Fiction, Fantasy, Science',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.article),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Your Notes',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
                alignLabelWithHint: true,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Save button
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_isEditing ? 'Update' : 'Save to Library'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoButton({
    required String label,
    required String? base64,
    required VoidCallback onTake,
    required VoidCallback onClear,
  }) {
    return Column(
      children: [
        if (base64 != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  base64Decode(base64),
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onClear,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onTake,
          icon: const Icon(Icons.camera_alt, size: 18),
          label: Text(label, style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Future<void> _fetchFromOnlineSources() async {
    final isbn = _isbnController.text.trim();
    if (isbn.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      Map<String, dynamic>? data;

      if (_type == CatalogType.book) {
        data = await _dataLookup.fetchByIsbn(isbn);
      } else {
        // For magazines, try ISSN lookup first, then ISBN
        data = await _dataLookup.fetchByIssn(isbn) ?? await _dataLookup.fetchByIsbn(isbn);
      }

      if (data != null && mounted) {
        _titleController.text = data['title'] as String? ?? '';
        _authorsController.text = data['authors'] as String? ?? '';
        _publisherController.text = data['publisher'] as String? ?? '';
        _publishedDateController.text = data['published_date'] as String? ?? '';
        _pageCountController.text = data['page_count']?.toString() ?? '';
        _coverUrlController.text = data['cover_url'] as String? ?? '';
        _descriptionController.text = data['description'] as String? ?? '';
        _categoriesController.text = data['categories'] as String? ?? '';

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data fetched from online sources!')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data found for this ISBN/ISSN')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final item = CatalogItem(
        id: _isEditing ? widget.item!.id : _isbnController.text.trim(),
        isbn: _isbnController.text.trim(),
        title: _titleController.text.trim(),
        authors: _authorsController.text
            .split(',')
            .map((a) => a.trim())
            .where((a) => a.isNotEmpty)
            .toList(),
        publisher: _publisherController.text.trim().isEmpty ? null : _publisherController.text.trim(),
        publishedDate: _publishedDateController.text.trim().isEmpty ? null : _publishedDateController.text.trim(),
        pageCount: int.tryParse(_pageCountController.text.trim()),
        coverUrl: _coverUrlController.text.trim().isEmpty ? null : _coverUrlController.text.trim(),
        coverImageBase64: _coverImageBase64,
        backImageBase64: _backImageBase64,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        categories: _categoriesController.text
            .split(',')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        type: _type,
        createdAt: _isEditing ? widget.item!.createdAt : null,
      );

      if (_isEditing) {
        await _turso.updateItem(item);
      } else {
        await _turso.insertItem(item);
      }

      // ignore: avoid_print
      print('[EditScreen] _save: item saved successfully, popping with item');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? 'Updated successfully!' : 'Saved to library!')),
        );
        Navigator.pop(context, item);
      }
    } catch (e) {
      // ignore: avoid_print
      print('[EditScreen] _save: error saving - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

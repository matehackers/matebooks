import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../models/catalog_item.dart';
import '../models/search_provider.dart';
import '../providers/settings_provider.dart';
import '../services/data_lookup_service.dart';
import '../services/turso_service.dart';
import 'edit_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final DataLookupService _dataLookup = DataLookupService();
  final TursoService _turso = TursoService();
  final TextEditingController _isbnController = TextEditingController();
  final FocusNode _isbnFocusNode = FocusNode();
  bool _isProcessing = false;
  bool _isManualMode = false;
  String? _statusMessage;

  @override
  void dispose() {
    _scannerController.dispose();
    _isbnController.dispose();
    _isbnFocusNode.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isManualMode = !_isManualMode;
      if (_isManualMode) {
        _scannerController.stop();
        _isbnFocusNode.requestFocus();
      } else {
        _scannerController.start();
      }
    });
  }

  void _submitManualIsbn() {
    final text = _isbnController.text.trim();
    if (text.isEmpty) return;
    _isbnFocusNode.unfocus();
    _processIsbn(text);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isManualMode ? 'Type ISBN' : 'Scan ISBN'),
        actions: [
          if (!_isManualMode) ...[
            IconButton(
              icon: const Icon(Icons.flash_on),
              onPressed: () => _scannerController.toggleTorch(),
            ),
            IconButton(
              icon: const Icon(Icons.switch_camera),
              onPressed: () => _scannerController.switchCamera(),
            ),
          ],
          IconButton(
            icon: Icon(_isManualMode ? Icons.qr_code_scanner : Icons.keyboard),
            tooltip: _isManualMode ? 'Scan barcode' : 'Type ISBN',
            onPressed: _toggleMode,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isManualMode)
            _buildManualInput(colorScheme)
          else ...[
            MobileScanner(
              controller: _scannerController,
              onDetect: _onBarcodeDetected,
            ),
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.primary, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Text(
                'Point camera at an ISBN barcode',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          if (_isProcessing || _statusMessage != null)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isProcessing) ...[
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          const Text('Looking up book data...'),
                        ] else ...[
                          Icon(
                            _statusMessage?.contains('Error') == true
                                ? Icons.error_outline
                                : Icons.check_circle,
                            size: 48,
                            color: _statusMessage?.contains('Error') == true
                                ? colorScheme.error
                                : colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(_statusMessage ?? ''),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => setState(() => _statusMessage = null),
                            child: const Text('Dismiss'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildManualInput(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book, size: 64, color: colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              'Enter ISBN',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Type the ISBN (10 or 13 digits)',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _isbnController,
              focusNode: _isbnFocusNode,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitManualIsbn(),
              decoration: InputDecoration(
                hintText: 'e.g. 9783161484100',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.numbers),
                suffixIcon: _isbnController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _isbnController.clear(),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isProcessing ? null : _submitManualIsbn,
                icon: const Icon(Icons.search),
                label: const Text('Look Up'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final isbn = barcode.rawValue;
      if (isbn == null || isbn.isEmpty) continue;

      final cleanIsbn = isbn.replaceAll(RegExp(r'[^0-9X]'), '');
      if (cleanIsbn.length < 10 || cleanIsbn.length > 13) continue;

      await _scannerController.stop();
      await _processIsbn(cleanIsbn);

      if (_isManualMode) return;
      await _scannerController.start();
      return;
    }
  }

  Future<void> _processIsbn(String rawIsbn) async {
    final cleanIsbn = rawIsbn.replaceAll(RegExp(r'[^0-9X]'), '');
    if (cleanIsbn.length < 10 || cleanIsbn.length > 13) {
      setState(() {
        _statusMessage = 'Invalid ISBN. Must be 10 or 13 digits.';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

    try {
      final existing = await _turso.getItemByIsbn(cleanIsbn);
      if (existing != null) {
        // ignore: avoid_print
        print('[ScanScreen] Book already in DB, popping with existing item');
        if (mounted) {
          Navigator.pop(context, existing);
        }
        return;
      }

      final settings = context.read<SettingsProvider>();
      final bookData = await _dataLookup.fetchByIsbn(cleanIsbn, enabled: settings.forLookup(LookupType.isbn));

      if (bookData != null) {
        final item = CatalogItem(
          id: cleanIsbn,
          isbn: cleanIsbn,
          title: bookData['title'] as String? ?? 'Unknown Title',
          authors: (bookData['authors'] as String?)?.split(', ').where((a) => a.isNotEmpty).toList() ?? [],
          publisher: bookData['publisher'] as String?,
          publishedDate: bookData['published_date'] as String?,
          pageCount: bookData['page_count'] as int?,
          coverUrl: bookData['cover_url'] as String?,
          description: bookData['description'] as String?,
          categories: (bookData['categories'] as String?)?.split(', ').where((c) => c.isNotEmpty).toList() ?? [],
        );

        await _turso.insertItem(item);

        // ignore: avoid_print
        print('[ScanScreen] Book found online, inserted and popping with item');
        if (mounted) {
          Navigator.pop(context, item);
        }
      } else {
        // ignore: avoid_print
        print('[ScanScreen] No data found online, navigating to EditScreen for manual entry');
        if (mounted) {
          final result = await Navigator.push<CatalogItem>(
            context,
            MaterialPageRoute(
              builder: (_) => EditScreen(
                isbn: cleanIsbn,
              ),
            ),
          );
          // ignore: avoid_print
          print('[ScanScreen] EditScreen returned: ${result != null ? 'item' : 'null/cancelled'}');
          if (result != null && mounted) {
            Navigator.pop(context, result);
          } else {
            setState(() => _isProcessing = false);
          }
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('[ScanScreen] Error processing ISBN: $e');
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Error: ${e.toString()}';
      });
    }
  }
}

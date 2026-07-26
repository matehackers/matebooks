import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/catalog_item.dart';
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
  bool _isProcessing = false;
  String? _statusMessage;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan ISBN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.switch_camera),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Scanner
          MobileScanner(
            controller: _scannerController,
            onDetect: _onBarcodeDetected,
          ),
          // Scan overlay
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
          // Status overlay
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
          // Hint text
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
      ),
    );
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final isbn = barcode.rawValue;
      if (isbn == null || isbn.isEmpty) continue;

      // Validate it looks like an ISBN (10 or 13 digits)
      final cleanIsbn = isbn.replaceAll(RegExp(r'[^0-9X]'), '');
      if (cleanIsbn.length < 10 || cleanIsbn.length > 13) continue;

      setState(() {
        _isProcessing = true;
        _statusMessage = null;
      });

      // Stop scanning while processing
      await _scannerController.stop();

      try {
        // Check if already in database
        final existing = await _turso.getItemByIsbn(cleanIsbn);
        if (existing != null) {
          // ignore: avoid_print
          print('[ScanScreen] Book already in DB, popping with existing item');
          if (mounted) {
            Navigator.pop(context, existing);
          }
          return;
        }

        // Try to fetch data using the lookup service (Open Library -> Google Books -> Crossref)
        final bookData = await _dataLookup.fetchByIsbn(cleanIsbn);

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
          // No data found -- show manual entry
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
              // User cancelled, resume scanning
              await _scannerController.start();
              setState(() => _isProcessing = false);
            }
          }
        }
      } catch (e) {
        // ignore: avoid_print
        print('[ScanScreen] Error in _onBarcodeDetected: $e');
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Error: ${e.toString()}';
        });
        await _scannerController.start();
      }
      return;
    }
  }
}

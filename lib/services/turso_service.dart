import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/catalog_item.dart';
import 'local_cache_service.dart';

class TursoService {
  static final TursoService _instance = TursoService._internal();
  factory TursoService() => _instance;
  TursoService._internal();

  final String _baseUrl = TursoConfig.databaseUrl;
  final String _authToken = TursoConfig.authToken;
  final LocalCacheService _cache = LocalCacheService();

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_authToken',
        'Content-Type': 'application/json',
      };

  Future<void> _execute(String sql, [List<dynamic>? params]) async {
    final request = {
      'type': 'execute',
      'stmt': {
        'sql': sql,
        if (params != null && params.isNotEmpty)
          'args': params.map((p) => _toTursoValue(p)).toList(),
      },
    };

    final body = {'requests': [request]};

    final response = await http.post(
      Uri.parse('$_baseUrl/v2/pipeline'),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Turso error: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body);
    final results = data['results'] as List?;
    if (results != null && results.isNotEmpty) {
      final firstResult = results[0] as Map?;
      if (firstResult?['type'] == 'error') {
        final error = firstResult?['error'] as Map?;
        throw Exception('Turso error: ${error?['message']} (code: ${error?['code']})');
      }
      final resp = firstResult?['response'] as Map?;
      final result = resp?['result'] as Map?;
      if (result != null && result['error'] != null) {
        final error = result['error'];
        throw Exception('Turso SQL error: ${error['message']} (code: ${error['code']})');
      }
    }
  }

  Future<List<Map<String, dynamic>>> _query(String sql, [List<dynamic>? params]) async {
    final request = {
      'type': 'execute',
      'stmt': {
        'sql': sql,
        if (params != null && params.isNotEmpty)
          'args': params.map((p) => _toTursoValue(p)).toList(),
      },
    };

    final body = {'requests': [request]};

    final response = await http.post(
      Uri.parse('$_baseUrl/v2/pipeline'),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Turso error: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body);
    final results = data['results'] as List?;
    if (results == null || results.isEmpty) return [];

    final firstResult = results[0] as Map?;
    if (firstResult?['type'] == 'error') {
      final error = firstResult?['error'] as Map?;
      throw Exception('Turso error: ${error?['message']} (code: ${error?['code']})');
    }
    final resp = firstResult?['response'] as Map?;
    final result = resp?['result'] as Map?;
    if (result == null) return [];

    if (result['error'] != null) {
      final error = result['error'];
      throw Exception('Turso SQL error: ${error['message']} (code: ${error['code']})');
    }

    final rows = result['rows'] as List?;
    if (rows == null || rows.isEmpty) return [];

    final cols = (result['cols'] as List?)
            ?.map((c) => c is Map ? (c['name'] as String?) ?? '' : '')
            .where((n) => n.isNotEmpty)
            .toList() ??
        [];

    return rows.map((row) {
      final map = <String, dynamic>{};
      if (row is List) {
        for (var i = 0; i < cols.length && i < row.length; i++) {
          final cell = row[i];
          if (cell is Map) {
            final type = cell['type'] as String?;
            if (type == 'null') {
              map[cols[i]] = null;
            } else if (cell['value'] != null) {
              map[cols[i]] = cell['value'];
            }
          } else {
            map[cols[i]] = cell;
          }
        }
      }
      return map;
    }).toList();
  }

  Map<String, dynamic> _toTursoValue(dynamic value) {
    if (value == null) {
      return {'type': 'null'};
    } else if (value is int) {
      return {'type': 'integer', 'value': value.toString()};
    } else if (value is double) {
      return {'type': 'float', 'value': value.toString()};
    } else if (value is bool) {
      return {'type': 'integer', 'value': value ? '1' : '0'};
    } else {
      return {'type': 'text', 'value': value.toString()};
    }
  }

  Future<void> initializeDatabase() async {
    await _execute('''
      CREATE TABLE IF NOT EXISTS books (
        id TEXT PRIMARY KEY,
        isbn TEXT UNIQUE NOT NULL,
        title TEXT NOT NULL,
        authors TEXT,
        publisher TEXT,
        published_date TEXT,
        page_count INTEGER,
        cover_url TEXT,
        cover_image_base64 TEXT,
        back_image_base64 TEXT,
        description TEXT,
        categories TEXT,
        notes TEXT,
        type TEXT DEFAULT 'book',
        created_at TEXT,
        updated_at TEXT
      )
    ''');
  }

  Future<List<CatalogItem>> _fetchAllFromRemote() async {
    final rows = await _query('SELECT * FROM books ORDER BY updated_at DESC');
    return rows.map((row) => CatalogItem.fromJson(row)).toList();
  }

  Future<List<CatalogItem>> getAllItems({void Function(List<CatalogItem>)? onSyncComplete}) async {
    final localItems = await _cache.getAllItems();

    if (localItems.isEmpty) {
      // ignore: avoid_print
      print('[TursoService] Local cache empty, fetching from remote...');
      try {
        final remoteItems = await _fetchAllFromRemote();
        if (remoteItems.isNotEmpty) {
          await _cache.replaceAll(remoteItems);
        }
        return remoteItems;
      } catch (e) {
        // ignore: avoid_print
        print('[TursoService] Remote fetch failed, returning empty: $e');
        return [];
      }
    }

    // ignore: avoid_print
    print('[TursoService] Loaded ${localItems.length} items from local cache');

    _backgroundSync().then((remoteItems) {
      if (remoteItems != null && onSyncComplete != null) {
        onSyncComplete(remoteItems);
      }
    });

    return localItems;
  }

  Future<List<CatalogItem>?> _backgroundSync() async {
    try {
      final remoteItems = await _fetchAllFromRemote();
      if (await _cache.needsSync(remoteItems)) {
        // ignore: avoid_print
        print('[TursoService] Background sync: updating local cache with ${remoteItems.length} items');
        await _cache.replaceAll(remoteItems);
        return remoteItems;
      }
      // ignore: avoid_print
      print('[TursoService] Background sync: local cache up to date');
    } catch (e) {
      // ignore: avoid_print
      print('[TursoService] Background sync failed: $e');
    }
    return null;
  }

  Future<CatalogItem?> getItemByIsbn(String isbn) async {
    final local = await _cache.getItemByIsbn(isbn);
    if (local != null) return local;

    final rows = await _query('SELECT * FROM books WHERE isbn = ?', [isbn]);
    if (rows.isEmpty) return null;
    final item = CatalogItem.fromJson(rows.first);
    await _cache.insertItem(item);
    return item;
  }

  Future<void> insertItem(CatalogItem item) async {
    // ignore: avoid_print
    print('[TursoService] insertItem: id=${item.id}, isbn=${item.isbn}, title=${item.title}');
    await _cache.insertItem(item);
    await _execute(
      '''INSERT OR REPLACE INTO books (id, isbn, title, authors, publisher, published_date, page_count, cover_url, cover_image_base64, back_image_base64, description, categories, notes, type, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        item.id,
        item.isbn,
        item.title,
        item.authors.join(', '),
        item.publisher,
        item.publishedDate,
        item.pageCount,
        item.coverUrl,
        item.coverImageBase64,
        item.backImageBase64,
        item.description,
        item.categories.join(', '),
        item.notes,
        item.type.name,
        item.createdAt.toIso8601String(),
        item.updatedAt.toIso8601String(),
      ],
    );
    // ignore: avoid_print
    print('[TursoService] insertItem: success');
  }

  Future<void> updateItem(CatalogItem item) async {
    await _cache.updateItem(item);
    await _execute(
      '''UPDATE books SET title = ?, authors = ?, publisher = ?, published_date = ?, page_count = ?, cover_url = ?, cover_image_base64 = ?, back_image_base64 = ?, description = ?, categories = ?, notes = ?, type = ?, updated_at = ?
       WHERE id = ?''',
      [
        item.title,
        item.authors.join(', '),
        item.publisher,
        item.publishedDate,
        item.pageCount,
        item.coverUrl,
        item.coverImageBase64,
        item.backImageBase64,
        item.description,
        item.categories.join(', '),
        item.notes,
        item.type.name,
        item.updatedAt.toIso8601String(),
        item.id,
      ],
    );
  }

  Future<void> deleteItem(String id) async {
    await _cache.deleteItem(id);
    await _execute('DELETE FROM books WHERE id = ?', [id]);
  }
}

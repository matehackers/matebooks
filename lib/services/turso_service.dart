import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/catalog_item.dart';

class TursoService {
  static final TursoService _instance = TursoService._internal();
  factory TursoService() => _instance;
  TursoService._internal();

  final String _baseUrl = TursoConfig.databaseUrl;
  final String _authToken = TursoConfig.authToken;

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

    // Check for errors in the response body
    final data = jsonDecode(response.body);
    final results = data['results'] as List?;
    if (results != null && results.isNotEmpty) {
      final firstResult = results[0] as Map?;
      // Check for error at the results level (type == "error")
      if (firstResult?['type'] == 'error') {
        final error = firstResult?['error'] as Map?;
        throw Exception('Turso error: ${error?['message']} (code: ${error?['code']})');
      }
      final resp = firstResult?['response'] as Map?;
      final result = resp?['result'] as Map?;
      // Check for SQL-level errors inside the result object
      if (result != null && result['error'] != null) {
        final error = result['error'];
        throw Exception('Turso SQL error: ${error['message']} (code: ${error['code']})');
      }
    }
  }

  /// Execute SQL ignoring errors (for migrations like ADD COLUMN)
  Future<void> _executeIgnoreError(String sql) async {
    try {
      await _execute(sql);
    } catch (e) {
      // ignore: avoid_print
      print('[TursoService] _executeIgnoreError: ignoring error for "$sql": $e');
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
    // Check for error at the results level (type == "error")
    if (firstResult?['type'] == 'error') {
      final error = firstResult?['error'] as Map?;
      throw Exception('Turso error: ${error?['message']} (code: ${error?['code']})');
    }
    final resp = firstResult?['response'] as Map?;
    final result = resp?['result'] as Map?;
    if (result == null) return [];

    // Check for SQL-level errors inside the result object
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

  /// Converts a Dart value to a Turso-compatible value.
  /// The libSQL pipeline API expects all `value` fields to be strings
  /// for integer, float, and text types.
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

    // Migration: add columns that might not exist in older table schemas
    await _executeIgnoreError('ALTER TABLE books ADD COLUMN cover_image_base64 TEXT');
    await _executeIgnoreError('ALTER TABLE books ADD COLUMN back_image_base64 TEXT');
  }

  Future<List<CatalogItem>> getAllItems() async {
    final rows = await _query('SELECT * FROM books ORDER BY updated_at DESC');
    // ignore: avoid_print
    print('[TursoService] getAllItems: returned ${rows.length} rows');
    return rows.map((row) => CatalogItem.fromJson(row)).toList();
  }

  Future<CatalogItem?> getItemByIsbn(String isbn) async {
    final rows = await _query('SELECT * FROM books WHERE isbn = ?', [isbn]);
    if (rows.isEmpty) return null;
    return CatalogItem.fromJson(rows.first);
  }

  Future<List<CatalogItem>> searchItems(String query) async {
    final searchTerm = '%$query%';
    final rows = await _query(
      'SELECT * FROM books WHERE title LIKE ? OR authors LIKE ? OR isbn LIKE ? ORDER BY updated_at DESC',
      [searchTerm, searchTerm, searchTerm],
    );
    return rows.map((row) => CatalogItem.fromJson(row)).toList();
  }

  Future<List<CatalogItem>> getItemsByType(String type) async {
    final rows = await _query('SELECT * FROM books WHERE type = ? ORDER BY updated_at DESC', [type]);
    return rows.map((row) => CatalogItem.fromJson(row)).toList();
  }

  Future<void> insertItem(CatalogItem item) async {
    // ignore: avoid_print
    print('[TursoService] insertItem: id=${item.id}, isbn=${item.isbn}, title=${item.title}, hasCover=${item.coverImageBase64 != null}, hasBack=${item.backImageBase64 != null}');
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
    await _execute('DELETE FROM books WHERE id = ?', [id]);
  }
}

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/catalog_item.dart';

class LocalCacheService {
  static final LocalCacheService _instance = LocalCacheService._internal();
  factory LocalCacheService() => _instance;
  LocalCacheService._internal();

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'matebooks_cache.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE books (
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
      },
    );
  }

  Future<List<CatalogItem>> getAllItems() async {
    final db = await _database;
    final rows = await db.query('books', orderBy: 'updated_at DESC');
    return rows.map(_rowToItem).toList();
  }

  Future<CatalogItem?> getItemByIsbn(String isbn) async {
    final db = await _database;
    final rows = await db.query('books', where: 'isbn = ?', whereArgs: [isbn]);
    if (rows.isEmpty) return null;
    return _rowToItem(rows.first);
  }

  Future<void> insertItem(CatalogItem item) async {
    final db = await _database;
    await db.insert('books', _itemToRow(item), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateItem(CatalogItem item) async {
    final db = await _database;
    await db.update('books', _itemToRow(item), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> deleteItem(String id) async {
    final db = await _database;
    await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> replaceAll(List<CatalogItem> items) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('books');
      for (final item in items) {
        await txn.insert('books', _itemToRow(item));
      }
    });
  }

  Future<bool> isEmpty() async {
    final db = await _database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM books'));
    return count == null || count == 0;
  }

  Future<bool> needsSync(List<CatalogItem> remoteItems) async {
    final local = await getAllItems();
    if (local.length != remoteItems.length) return true;
    final localByUpdated = <String, DateTime>{};
    for (final item in local) {
      localByUpdated[item.id] = item.updatedAt;
    }
    for (final item in remoteItems) {
      final localUpdated = localByUpdated[item.id];
      if (localUpdated == null) return true;
      if (item.updatedAt.isAfter(localUpdated)) return true;
    }
    return false;
  }

  CatalogItem _rowToItem(Map<String, dynamic> row) {
    return CatalogItem(
      id: row['id'] as String,
      isbn: row['isbn'] as String,
      title: row['title'] as String,
      authors: (row['authors'] as String?)?.split(', ').where((a) => a.isNotEmpty).toList() ?? [],
      publisher: row['publisher'] as String?,
      publishedDate: row['published_date'] as String?,
      pageCount: row['page_count'] is int
          ? row['page_count'] as int?
          : int.tryParse(row['page_count'] as String? ?? ''),
      coverUrl: row['cover_url'] as String?,
      coverImageBase64: row['cover_image_base64'] as String?,
      backImageBase64: row['back_image_base64'] as String?,
      description: row['description'] as String?,
      categories: (row['categories'] as String?)?.split(', ').where((c) => c.isNotEmpty).toList() ?? [],
      notes: row['notes'] as String?,
      type: row['type'] == 'magazine' ? CatalogType.magazine : CatalogType.book,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> _itemToRow(CatalogItem item) {
    return {
      'id': item.id,
      'isbn': item.isbn,
      'title': item.title,
      'authors': item.authors.join(', '),
      'publisher': item.publisher,
      'published_date': item.publishedDate,
      'page_count': item.pageCount,
      'cover_url': item.coverUrl,
      'cover_image_base64': item.coverImageBase64,
      'back_image_base64': item.backImageBase64,
      'description': item.description,
      'categories': item.categories.join(', '),
      'notes': item.notes,
      'type': item.type.name,
      'created_at': item.createdAt.toIso8601String(),
      'updated_at': item.updatedAt.toIso8601String(),
    };
  }
}

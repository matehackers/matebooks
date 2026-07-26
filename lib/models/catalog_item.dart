enum CatalogType { book, magazine }

class CatalogItem {
  final String id;
  final String isbn;
  String title;
  List<String> authors;
  String? publisher;
  String? publishedDate;
  int? pageCount;
  String? coverUrl;
  String? coverImageBase64;
  String? backImageBase64;
  String? description;
  List<String> categories;
  String? notes;
  CatalogType type;
  final DateTime createdAt;
  DateTime updatedAt;

  CatalogItem({
    required this.id,
    required this.isbn,
    required this.title,
    this.authors = const [],
    this.publisher,
    this.publishedDate,
    this.pageCount,
    this.coverUrl,
    this.coverImageBase64,
    this.backImageBase64,
    this.description,
    this.categories = const [],
    this.notes,
    this.type = CatalogType.book,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'isbn': isbn,
        'title': title,
        'authors': authors.join(', '),
        'publisher': publisher,
        'published_date': publishedDate,
        'page_count': pageCount,
        'cover_url': coverUrl,
        'cover_image_base64': coverImageBase64,
        'back_image_base64': backImageBase64,
        'description': description,
        'categories': categories.join(', '),
        'notes': notes,
        'type': type.name,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory CatalogItem.fromJson(Map<String, dynamic> json) => CatalogItem(
        id: json['id'] as String,
        isbn: json['isbn'] as String,
        title: json['title'] as String,
        authors: (json['authors'] as String?)?.split(', ').where((a) => a.isNotEmpty).toList() ?? [],
        publisher: json['publisher'] as String?,
        publishedDate: json['published_date'] as String?,
        pageCount: json['page_count'] is int
            ? json['page_count'] as int?
            : int.tryParse(json['page_count'] as String? ?? ''),
        coverUrl: json['cover_url'] as String?,
        coverImageBase64: json['cover_image_base64'] as String?,
        backImageBase64: json['back_image_base64'] as String?,
        description: json['description'] as String?,
        categories: (json['categories'] as String?)?.split(', ').where((c) => c.isNotEmpty).toList() ?? [],
        notes: json['notes'] as String?,
        type: json['type'] == 'magazine' ? CatalogType.magazine : CatalogType.book,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toInsertJson() => {
        'id': id,
        'isbn': isbn,
        'title': title,
        'authors': authors.join(', '),
        'publisher': publisher,
        'published_date': publishedDate,
        'page_count': pageCount,
        'cover_url': coverUrl,
        'cover_image_base64': coverImageBase64,
        'back_image_base64': backImageBase64,
        'description': description,
        'categories': categories.join(', '),
        'notes': notes,
        'type': type.name,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  CatalogItem copyWith({
    String? title,
    List<String>? authors,
    String? publisher,
    String? publishedDate,
    int? pageCount,
    String? coverUrl,
    String? coverImageBase64,
    String? backImageBase64,
    String? description,
    List<String>? categories,
    String? notes,
    CatalogType? type,
  }) =>
      CatalogItem(
        id: id,
        isbn: isbn,
        title: title ?? this.title,
        authors: authors ?? this.authors,
        publisher: publisher ?? this.publisher,
        publishedDate: publishedDate ?? this.publishedDate,
        pageCount: pageCount ?? this.pageCount,
        coverUrl: coverUrl ?? this.coverUrl,
        coverImageBase64: coverImageBase64 ?? this.coverImageBase64,
        backImageBase64: backImageBase64 ?? this.backImageBase64,
        description: description ?? this.description,
        categories: categories ?? this.categories,
        notes: notes ?? this.notes,
        type: type ?? this.type,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}

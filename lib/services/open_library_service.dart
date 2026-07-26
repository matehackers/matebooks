import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenLibraryService {
  static final OpenLibraryService _instance = OpenLibraryService._internal();
  factory OpenLibraryService() => _instance;
  OpenLibraryService._internal();

  /// Fetch book/magazine data by ISBN from Open Library (no API key needed).
  Future<Map<String, dynamic>?> fetchByIsbn(String isbn) async {
    try {
      // ignore: avoid_print
      print('[OpenLibraryService] Trying Open Library API for ISBN: $isbn');
      final response = await http.get(
        Uri.parse('https://openlibrary.org/isbn/$isbn.json'),
      );
      // ignore: avoid_print
      print('[OpenLibraryService] Open Library response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = _parseOpenLibraryData(data, isbn);
        // ignore: avoid_print
        print('[OpenLibraryService] Open Library result: $result');
        return result;
      } else {
        // ignore: avoid_print
        print('[OpenLibraryService] Open Library returned non-200: ${response.body}');
      }
    } catch (e) {
      // ignore: avoid_print
      print('[OpenLibraryService] Open Library error: $e');
    }
    return null;
  }

  /// Search by title/author from Open Library
  Future<List<Map<String, dynamic>>> searchByTitle(String query, {int limit = 20}) async {
    try {
      final response = await http.get(
        Uri.parse('https://openlibrary.org/search.json?q=${Uri.encodeQueryComponent(query)}&limit=$limit'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final docs = data['docs'] as List? ?? [];
        return docs.map((doc) => _parseSearchResult(doc)).toList();
      }
    } catch (_) {
      // Silently fail
    }
    return [];
  }

  Map<String, dynamic> _parseOpenLibraryData(Map<String, dynamic> data, String isbn) {
    final authors = (data['authors'] as List?)
            ?.map((a) => a['name'] as String? ?? 'Unknown')
            .join(', ') ??
        '';

    final subjects = (data['subjects'] as List?)
            ?.take(5)
            .map((s) => s.toString())
            .join(', ') ??
        '';

    final coverId = data['covers'] is List && (data['covers'] as List).isNotEmpty
        ? (data['covers'] as List).first.toString()
        : null;

    return {
      'isbn': isbn,
      'title': data['title'] as String? ?? 'Unknown Title',
      'authors': authors,
      'publisher': data['publishers'] is List
          ? (data['publishers'] as List).first.toString()
          : null,
      'published_date': data['publish_date'] as String?,
      'page_count': data['number_of_pages'] as int?,
      'cover_url': coverId != null
          ? 'https://covers.openlibrary.org/b/id/$coverId-L.jpg'
          : 'https://covers.openlibrary.org/b/isbn/$isbn-L.jpg',
      'description': data['description'] is Map
          ? (data['description'] as Map)['value'] as String?
          : data['description'] as String?,
      'categories': subjects,
    };
  }

  Map<String, dynamic> _parseSearchResult(Map<String, dynamic> doc) {
    final isbnList = doc['isbn'] as List?;
    final coverI = doc['cover_i'] as int?;
    final isbn = isbnList != null && isbnList.isNotEmpty ? isbnList.first.toString() : '';

    return {
      'isbn': isbn,
      'title': doc['title'] as String? ?? 'Unknown Title',
      'authors': (doc['author_name'] as List?)?.join(', ') ?? '',
      'publisher': (doc['publisher'] as List?)?.first.toString(),
      'published_date': doc['first_publish_year']?.toString(),
      'page_count': null,
      'cover_url': coverI != null
          ? 'https://covers.openlibrary.org/b/id/$coverI-L.jpg'
          : null,
      'description': null,
      'categories': (doc['subject'] as List?)?.take(5).join(', ') ?? '',
    };
  }
}

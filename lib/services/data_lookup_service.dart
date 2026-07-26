import 'dart:convert';
import 'package:http/http.dart' as http;
import 'open_library_service.dart';

/// Unified data lookup service that tries multiple sources.
/// Fallback chain:
///   For books: Open Library -> Google Books -> Crossref -> manual
///   For magazines: Open Library -> Google Books -> DOAJ -> Crossref -> manual
class DataLookupService {
  static final DataLookupService _instance = DataLookupService._internal();
  factory DataLookupService() => _instance;
  DataLookupService._internal();

  final OpenLibraryService _openLibrary = OpenLibraryService();

  /// Fetch data by ISBN. Returns normalized map or null.
  Future<Map<String, dynamic>?> fetchByIsbn(String isbn) async {
    // ignore: avoid_print
    print('[DataLookupService] fetchByIsbn: starting lookup for ISBN: $isbn');

    // 1. Try Open Library (free, no key needed)
    // ignore: avoid_print
    print('[DataLookupService] Attempt 1/3: Open Library API...');
    final openLib = await _openLibrary.fetchByIsbn(isbn);
    if (openLib != null) {
      // ignore: avoid_print
      print('[DataLookupService] Open Library succeeded: title="${openLib['title']}"');
      return openLib;
    }
    // ignore: avoid_print
    print('[DataLookupService] Open Library returned null, trying next source...');

    // 2. Try Google Books API
    // ignore: avoid_print
    print('[DataLookupService] Attempt 2/3: Google Books API...');
    final google = await _fetchFromGoogleBooks(isbn);
    if (google != null) {
      // ignore: avoid_print
      print('[DataLookupService] Google Books succeeded: title="${google['title']}"');
      return google;
    }
    // ignore: avoid_print
    print('[DataLookupService] Google Books returned null, trying next source...');

    // 3. Try Crossref
    // ignore: avoid_print
    print('[DataLookupService] Attempt 3/3: Crossref API...');
    final crossref = await _fetchFromCrossrefByIsbn(isbn);
    if (crossref != null) {
      // ignore: avoid_print
      print('[DataLookupService] Crossref succeeded: title="${crossref['title']}"');
      return crossref;
    }
    // ignore: avoid_print
    print('[DataLookupService] All ISBN sources returned null');

    return null;
  }

  /// Fetch data by ISSN (for magazines). Returns normalized map or null.
  Future<Map<String, dynamic>?> fetchByIssn(String issn) async {
    // ignore: avoid_print
    print('[DataLookupService] fetchByIssn: starting lookup for ISSN: $issn');

    // 1. Try DOAJ
    // ignore: avoid_print
    print('[DataLookupService] Attempt 1/2: DOAJ API...');
    final doaj = await _fetchFromDoaj(issn);
    if (doaj != null) {
      // ignore: avoid_print
      print('[DataLookupService] DOAJ succeeded: title="${doaj['title']}"');
      return doaj;
    }
    // ignore: avoid_print
    print('[DataLookupService] DOAJ returned null, trying next source...');

    // 2. Try Crossref
    // ignore: avoid_print
    print('[DataLookupService] Attempt 2/2: Crossref API...');
    final crossref = await _fetchFromCrossrefByIssn(issn);
    if (crossref != null) {
      // ignore: avoid_print
      print('[DataLookupService] Crossref succeeded: title="${crossref['title']}"');
      return crossref;
    }
    // ignore: avoid_print
    print('[DataLookupService] All ISSN sources returned null');

    return null;
  }

  /// Fetch from Google Books API (no API key needed for basic queries)
  Future<Map<String, dynamic>?> _fetchFromGoogleBooks(String isbn) async {
    try {
      // ignore: avoid_print
      print('[DataLookupService] Google Books: fetching isbn=$isbn');
      final response = await http.get(
        Uri.parse('https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn'),
      );
      // ignore: avoid_print
      print('[DataLookupService] Google Books response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List?;
        if (items != null && items.isNotEmpty) {
          final volumeInfo = items[0]['volumeInfo'] as Map<String, dynamic>?;
          if (volumeInfo != null) {
            final result = _parseGoogleBooksData(volumeInfo, isbn);
            // ignore: avoid_print
            print('[DataLookupService] Google Books result: $result');
            return result;
          }
        }
        // ignore: avoid_print
        print('[DataLookupService] Google Books: no items found in response');
      } else {
        // ignore: avoid_print
        print('[DataLookupService] Google Books non-200: ${response.statusCode} ${response.body.substring(0, (response.body.length).clamp(0, 500))}');
      }
    } catch (e) {
      // ignore: avoid_print
      print('[DataLookupService] Google Books error: $e');
    }
    return null;
  }

  /// Fetch from Crossref API by ISBN
  Future<Map<String, dynamic>?> _fetchFromCrossrefByIsbn(String isbn) async {
    try {
      // ignore: avoid_print
      print('[DataLookupService] Crossref (ISBN): fetching isbn=$isbn');
      final response = await http.get(
        Uri.parse('https://api.crossref.org/works?filter=isbn:$isbn&rows=1'),
      );
      // ignore: avoid_print
      print('[DataLookupService] Crossref (ISBN) response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final message = data['message'] as Map<String, dynamic>?;
        final items = message?['items'] as List?;
        if (items != null && items.isNotEmpty) {
          final result = _parseCrossrefData(items[0] as Map<String, dynamic>, isbn);
          // ignore: avoid_print
          print('[DataLookupService] Crossref (ISBN) result: $result');
          return result;
        }
        // ignore: avoid_print
        print('[DataLookupService] Crossref (ISBN): no items found');
      } else {
        // ignore: avoid_print
        print('[DataLookupService] Crossref (ISBN) non-200: ${response.statusCode} ${response.body.substring(0, (response.body.length).clamp(0, 500))}');
      }
    } catch (e) {
      // ignore: avoid_print
      print('[DataLookupService] Crossref (ISBN) error: $e');
    }
    return null;
  }

  /// Fetch from Crossref API by ISSN
  Future<Map<String, dynamic>?> _fetchFromCrossrefByIssn(String issn) async {
    try {
      // ignore: avoid_print
      print('[DataLookupService] Crossref (ISSN): fetching issn=$issn');
      final response = await http.get(
        Uri.parse('https://api.crossref.org/works?filter=issn:$issn&rows=1'),
      );
      // ignore: avoid_print
      print('[DataLookupService] Crossref (ISSN) response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final message = data['message'] as Map<String, dynamic>?;
        final items = message?['items'] as List?;
        if (items != null && items.isNotEmpty) {
          final result = _parseCrossrefData(items[0] as Map<String, dynamic>, null);
          // ignore: avoid_print
          print('[DataLookupService] Crossref (ISSN) result: $result');
          return result;
        }
        // ignore: avoid_print
        print('[DataLookupService] Crossref (ISSN): no items found');
      } else {
        // ignore: avoid_print
        print('[DataLookupService] Crossref (ISSN) non-200: ${response.statusCode} ${response.body.substring(0, (response.body.length).clamp(0, 500))}');
      }
    } catch (e) {
      // ignore: avoid_print
      print('[DataLookupService] Crossref (ISSN) error: $e');
    }
    return null;
  }

  /// Fetch from DOAJ API by ISSN
  Future<Map<String, dynamic>?> _fetchFromDoaj(String issn) async {
    try {
      // ignore: avoid_print
      print('[DataLookupService] DOAJ: fetching issn=$issn');
      final response = await http.get(
        Uri.parse('https://doaj.org/api/search/journals/issn%3A$issn'),
      );
      // ignore: avoid_print
      print('[DataLookupService] DOAJ response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final journal = results[0] as Map<String, dynamic>;
          final bibjson = journal['bibjson'] as Map<String, dynamic>?;
          if (bibjson != null) {
            final result = _parseDoajData(bibjson, issn);
            // ignore: avoid_print
            print('[DataLookupService] DOAJ result: $result');
            return result;
          }
        }
        // ignore: avoid_print
        print('[DataLookupService] DOAJ: no results found');
      } else {
        // ignore: avoid_print
        print('[DataLookupService] DOAJ non-200: ${response.statusCode} ${response.body.substring(0, (response.body.length).clamp(0, 500))}');
      }
    } catch (e) {
      // ignore: avoid_print
      print('[DataLookupService] DOAJ error: $e');
    }
    return null;
  }

  /// Parse Google Books response into normalized format
  Map<String, dynamic> _parseGoogleBooksData(Map<String, dynamic> info, String isbn) {
    final authors = (info['authors'] as List?)
            ?.map((a) => a.toString())
            .join(', ') ??
        '';

    final imageLinks = info['imageLinks'] as Map<String, dynamic>?;
    final thumbnail = imageLinks?['thumbnail'] as String?;
    // Google Books thumbnails sometimes use http; upgrade to https
    final coverUrl = thumbnail?.replaceFirst('http://', 'https://');

    final categories = (info['categories'] as List?)
            ?.take(5)
            .map((c) => c.toString())
            .join(', ') ??
        '';

    return {
      'isbn': isbn,
      'title': info['title'] as String? ?? 'Unknown Title',
      'authors': authors,
      'publisher': info['publisher'] as String?,
      'published_date': info['publishedDate'] as String?,
      'page_count': info['pageCount'] as int?,
      'cover_url': coverUrl,
      'description': info['description'] as String?,
      'categories': categories,
    };
  }

  /// Parse Crossref response into normalized format
  Map<String, dynamic> _parseCrossrefData(Map<String, dynamic> work, String? isbn) {
    final titleList = work['title'] as List?;
    final title = titleList != null && titleList.isNotEmpty
        ? titleList.first.toString()
        : 'Unknown Title';

    final authorList = work['author'] as List?;
    final authors = authorList
            ?.map((a) {
              final given = (a['given'] as String? ?? '');
              final family = (a['family'] as String? ?? '');
              return '$given $family'.trim();
            })
            .where((a) => a.isNotEmpty)
            .join(', ') ??
        '';

    final dateParts = (work['published-print']?['date-parts'] as List?) ??
        (work['published-online']?['date-parts'] as List?);
    String? publishedDate;
    if (dateParts != null && dateParts.isNotEmpty) {
      final parts = dateParts[0] as List;
      publishedDate = parts.join('-');
    }

    final isbnList = work['ISBN'] as List?;
    final resolvedIsbn = isbn ?? (isbnList != null && isbnList.isNotEmpty ? isbnList.first.toString() : '');

    final subjectList = work['subject'] as List?;
    final categories = subjectList?.take(5).join(', ') ?? '';

    return {
      'isbn': resolvedIsbn,
      'title': title,
      'authors': authors,
      'publisher': work['publisher'] as String?,
      'published_date': publishedDate,
      'page_count': null, // Crossref doesn't reliably provide page counts
      'cover_url': null,
      'description': null,
      'categories': categories,
    };
  }

  /// Parse DOAJ response into normalized format
  Map<String, dynamic> _parseDoajData(Map<String, dynamic> bibjson, String issn) {
    final title = bibjson['title'] as String? ?? 'Unknown Title';

    final publisher = bibjson['publisher'] as String?;

    final authors = (bibjson['author'] as List?)
            ?.map((a) => a is Map ? (a['name'] as String? ?? '') : a.toString())
            .where((a) => a.isNotEmpty)
            .join(', ') ??
        '';

    final subjects = (bibjson['subject'] as List?)
            ?.map((s) => s is Map ? (s['term'] as String? ?? '') : s.toString())
            .where((s) => s.isNotEmpty)
            .take(5)
            .join(', ') ??
        '';

    return {
      'isbn': issn,
      'title': title,
      'authors': authors,
      'publisher': publisher,
      'published_date': null,
      'page_count': null,
      'cover_url': null,
      'description': bibjson['description'] as String?,
      'categories': subjects,
    };
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/search_provider.dart';
import 'open_library_service.dart';

/// Unified data lookup service that tries multiple sources.
/// Provider order is configurable via [enabledProviders] parameter.
class DataLookupService {
  static final DataLookupService _instance = DataLookupService._internal();
  factory DataLookupService() => _instance;
  DataLookupService._internal();

  final OpenLibraryService _openLibrary = OpenLibraryService();

  Future<Map<String, dynamic>?> fetchByIsbn(
    String isbn, {
    List<SearchProviderId>? enabled,
  }) {
    final providers = enabled ?? defaultIsbnProviderOrder;
    return _sequentialLookup(isbn, providers, LookupType.isbn);
  }

  Future<Map<String, dynamic>?> fetchByIssn(
    String issn, {
    List<SearchProviderId>? enabled,
  }) {
    final providers = enabled ?? defaultIssnProviderOrder;
    return _sequentialLookup(issn, providers, LookupType.issn);
  }

  Future<Map<String, dynamic>?> _sequentialLookup(
    String identifier,
    List<SearchProviderId> providers,
    LookupType type,
  ) async {
    print('[DataLookupService] $_lookupLabel(type): starting with providers: ${providers.map((p) => p.name).join(' -> ')}');

    for (var i = 0; i < providers.length; i++) {
      final id = providers[i];
      if (!getProviderById(id).lookupTypes.contains(type)) continue;

      print('[DataLookupService] Attempt ${i + 1}/${providers.length}: ${getProviderById(id).label}...');
      final result = await _callProvider(id, identifier, type);
      if (result != null) {
        print('[DataLookupService] ${getProviderById(id).label} succeeded: title="${result['title']}"');
        return result;
      }
      print('[DataLookupService] ${getProviderById(id).label} returned null, trying next source...');
    }

    print('[DataLookupService] All sources returned null');
    return null;
  }

  Future<Map<String, dynamic>?> fetchAllSourcesByIsbn(
    String isbn, {
    List<SearchProviderId>? enabled,
  }) {
    final providers = enabled ?? defaultIsbnProviderOrder;
    return _parallelLookup(isbn, providers, LookupType.isbn);
  }

  Future<Map<String, dynamic>?> fetchAllSourcesByIssn(
    String issn, {
    List<SearchProviderId>? enabled,
  }) {
    final providers = enabled ?? defaultIssnProviderOrder;
    return _parallelLookup(issn, providers, LookupType.issn);
  }

  Future<Map<String, dynamic>?> _parallelLookup(
    String identifier,
    List<SearchProviderId> providers,
    LookupType type,
  ) async {
    print('[DataLookupService] $_lookupLabel(type): parallel lookup with providers: ${providers.map((p) => p.name).join(', ')}');

    final futures = <Future<Map<String, dynamic>?>>[];
    for (final id in providers) {
      if (!getProviderById(id).lookupTypes.contains(type)) continue;
      futures.add(_callProvider(id, identifier, type));
    }

    final results = await Future.wait(futures);
    final valid = <Map<String, dynamic>>[];
    for (final r in results) {
      if (r != null) valid.add(r);
    }
    if (valid.isEmpty) return null;

    return _mergeResults(valid);
  }

  Future<Map<String, dynamic>?> _callProvider(
    SearchProviderId id,
    String identifier,
    LookupType type,
  ) async {
    switch (id) {
      case SearchProviderId.openLibrary:
        return _openLibrary.fetchByIsbn(identifier);
      case SearchProviderId.googleBooks:
        return _fetchFromGoogleBooks(identifier);
      case SearchProviderId.crossref:
        if (type == LookupType.isbn) {
          return _fetchFromCrossrefByIsbn(identifier);
        } else {
          return _fetchFromCrossrefByIssn(identifier);
        }
      case SearchProviderId.doaj:
        return _fetchFromDoaj(identifier);
    }
  }

  String _lookupLabel(LookupType type) {
    return type == LookupType.isbn ? 'ISBN' : 'ISSN';
  }

  static final _mergeFields = [
    'title', 'authors', 'publisher', 'published_date',
    'page_count', 'cover_url', 'description', 'categories',
  ];

  Map<String, dynamic> _mergeResults(List<Map<String, dynamic>> results) {
    final merged = <String, dynamic>{};
    for (final field in _mergeFields) {
      for (final result in results) {
        final value = result[field];
        if (value == null) continue;
        if (value == '') continue;
        if (field == 'title' && value == 'Unknown Title') continue;
        merged[field] = value;
        break;
      }
    }
    return merged;
  }

  Future<Map<String, dynamic>?> _fetchFromGoogleBooks(String isbn) async {
    try {
      print('[DataLookupService] Google Books: fetching isbn=$isbn');
      var url = 'https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn';
      if (TursoConfig.googleBooksApiKey.isNotEmpty) {
        url += '&key=${TursoConfig.googleBooksApiKey}';
      }
      final response = await http.get(Uri.parse(url));
      print('[DataLookupService] Google Books response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List?;
        if (items != null && items.isNotEmpty) {
          final volumeInfo = items[0]['volumeInfo'] as Map<String, dynamic>?;
          if (volumeInfo != null) {
            final result = _parseGoogleBooksData(volumeInfo, isbn);
            print('[DataLookupService] Google Books result: $result');
            return result;
          }
        }
        print('[DataLookupService] Google Books: no items found in response');
      } else {
        print('[DataLookupService] Google Books non-200: ${response.statusCode} ${response.body.substring(0, (response.body.length).clamp(0, 500))}');
      }
    } catch (e) {
      print('[DataLookupService] Google Books error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchFromCrossrefByIsbn(String isbn) async {
    try {
      print('[DataLookupService] Crossref (ISBN): fetching isbn=$isbn');
      final response = await http.get(
        Uri.parse('https://api.crossref.org/works?filter=isbn:$isbn&rows=1'),
      );
      print('[DataLookupService] Crossref (ISBN) response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final message = data['message'] as Map<String, dynamic>?;
        final items = message?['items'] as List?;
        if (items != null && items.isNotEmpty) {
          final result = _parseCrossrefData(items[0] as Map<String, dynamic>, isbn);
          print('[DataLookupService] Crossref (ISBN) result: $result');
          return result;
        }
        print('[DataLookupService] Crossref (ISBN): no items found');
      } else {
        print('[DataLookupService] Crossref (ISBN) non-200: ${response.statusCode} ${response.body.substring(0, (response.body.length).clamp(0, 500))}');
      }
    } catch (e) {
      print('[DataLookupService] Crossref (ISBN) error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchFromCrossrefByIssn(String issn) async {
    try {
      print('[DataLookupService] Crossref (ISSN): fetching issn=$issn');
      final response = await http.get(
        Uri.parse('https://api.crossref.org/works?filter=issn:$issn&rows=1'),
      );
      print('[DataLookupService] Crossref (ISSN) response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final message = data['message'] as Map<String, dynamic>?;
        final items = message?['items'] as List?;
        if (items != null && items.isNotEmpty) {
          final result = _parseCrossrefData(items[0] as Map<String, dynamic>, null);
          print('[DataLookupService] Crossref (ISSN) result: $result');
          return result;
        }
        print('[DataLookupService] Crossref (ISSN): no items found');
      } else {
        print('[DataLookupService] Crossref (ISSN) non-200: ${response.statusCode} ${response.body.substring(0, (response.body.length).clamp(0, 500))}');
      }
    } catch (e) {
      print('[DataLookupService] Crossref (ISSN) error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchFromDoaj(String issn) async {
    try {
      print('[DataLookupService] DOAJ: fetching issn=$issn');
      final response = await http.get(
        Uri.parse('https://doaj.org/api/search/journals/issn%3A$issn'),
      );
      print('[DataLookupService] DOAJ response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final journal = results[0] as Map<String, dynamic>;
          final bibjson = journal['bibjson'] as Map<String, dynamic>?;
          if (bibjson != null) {
            final result = _parseDoajData(bibjson, issn);
            print('[DataLookupService] DOAJ result: $result');
            return result;
          }
        }
        print('[DataLookupService] DOAJ: no results found');
      } else {
        print('[DataLookupService] DOAJ non-200: ${response.statusCode} ${response.body.substring(0, (response.body.length).clamp(0, 500))}');
      }
    } catch (e) {
      print('[DataLookupService] DOAJ error: $e');
    }
    return null;
  }

  Map<String, dynamic> _parseGoogleBooksData(Map<String, dynamic> info, String isbn) {
    final authors = (info['authors'] as List?)
            ?.map((a) => a.toString())
            .join(', ') ??
        '';

    final imageLinks = info['imageLinks'] as Map<String, dynamic>?;
    final thumbnail = imageLinks?['thumbnail'] as String?;
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
      'page_count': null,
      'cover_url': null,
      'description': null,
      'categories': categories,
    };
  }

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

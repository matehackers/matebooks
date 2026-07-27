enum SearchProviderId { openLibrary, googleBooks, crossref, doaj }

enum LookupType { isbn, issn }

class SearchProvider {
  final SearchProviderId id;
  final String label;
  final String description;
  final Set<LookupType> lookupTypes;

  const SearchProvider({
    required this.id,
    required this.label,
    required this.description,
    required this.lookupTypes,
  });
}

const allSearchProviders = [
  SearchProvider(
    id: SearchProviderId.openLibrary,
    label: 'Open Library',
    description: 'Free public library catalog via OpenLibrary.org',
    lookupTypes: {LookupType.isbn},
  ),
  SearchProvider(
    id: SearchProviderId.googleBooks,
    label: 'Google Books',
    description: 'Comprehensive book database via Google Books API',
    lookupTypes: {LookupType.isbn},
  ),
  SearchProvider(
    id: SearchProviderId.crossref,
    label: 'Crossref',
    description: 'Academic metadata for books & journals via Crossref.org',
    lookupTypes: {LookupType.isbn, LookupType.issn},
  ),
  SearchProvider(
    id: SearchProviderId.doaj,
    label: 'DOAJ',
    description: 'Directory of Open Access Journals via DOAJ.org',
    lookupTypes: {LookupType.issn},
  ),
];

const defaultIsbnProviderOrder = [
  SearchProviderId.openLibrary,
  SearchProviderId.googleBooks,
  SearchProviderId.crossref,
];

const defaultIssnProviderOrder = [
  SearchProviderId.doaj,
  SearchProviderId.crossref,
];

SearchProvider getProviderById(SearchProviderId id) {
  return allSearchProviders.firstWhere((p) => p.id == id);
}

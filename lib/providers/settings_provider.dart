import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/search_provider.dart';

class SettingsProvider extends ChangeNotifier {
  static const _key = 'enabledSearchProviders';

  final List<SearchProviderId> _enabledProviders =
      List.from(defaultIsbnProviderOrder);

  List<SearchProviderId> get enabledProviders =>
      List.unmodifiable(_enabledProviders);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key);
    if (saved != null && saved.isNotEmpty) {
      final parsed = <SearchProviderId>[];
      for (final s in saved) {
        final id = SearchProviderId.values.cast<SearchProviderId?>().firstWhere(
              (e) => e?.name == s,
              orElse: () => null,
            );
        if (id != null) parsed.add(id);
      }
      if (parsed.isNotEmpty) {
        _enabledProviders
          ..clear()
          ..addAll(parsed);
      }
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      _enabledProviders.map((e) => e.name).toList(),
    );
  }

  bool isEnabled(SearchProviderId id) => _enabledProviders.contains(id);

  void toggle(SearchProviderId id) {
    if (_enabledProviders.contains(id)) {
      if (_enabledProviders.length <= 1) return;
      _enabledProviders.remove(id);
    } else {
      _enabledProviders.add(id);
    }
    _save();
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    final item = _enabledProviders.removeAt(oldIndex);
    _enabledProviders.insert(newIndex, item);
    _save();
    notifyListeners();
  }

  List<SearchProviderId> forLookup(LookupType type) {
    return _enabledProviders
        .where((id) => getProviderById(id).lookupTypes.contains(type))
        .toList();
  }
}

import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _keyBrand = 'preferred_brand';
  static const _keyRecentSearches = 'recent_searches';
  static const _maxRecentSearches = 10;

  static Future<String> getPreferredBrand() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBrand) ?? 'tj';
  }

  static Future<void> setPreferredBrand(String brand) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBrand, brand);
  }

  static Future<List<String>> getRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyRecentSearches) ?? [];
  }

  static Future<void> addRecentSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyRecentSearches) ?? [];
    list.remove(q);
    list.insert(0, q);
    if (list.length > _maxRecentSearches) list.removeLast();
    await prefs.setStringList(_keyRecentSearches, list);
  }
}

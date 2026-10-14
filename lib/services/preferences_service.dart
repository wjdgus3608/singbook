import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _keyBrand = 'preferred_brand';

  static Future<String> getPreferredBrand() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBrand) ?? 'tj';
  }

  static Future<void> setPreferredBrand(String brand) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBrand, brand);
  }
}

import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static SharedPreferences? _prefs;

  /// Initializes the SharedPreferences instance (must be called before use)
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<void> setAdminPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('adminPin', pin);
  }

  static Future<String?> getAdminPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('adminPin');
  }

  /// Save any type of setting
  static Future<void> set(String key, dynamic value) async {
    await init();
    if (value is String) {
      await _prefs!.setString(key, value);
    } else if (value is bool) {
      await _prefs!.setBool(key, value);
    } else if (value is int) {
      await _prefs!.setInt(key, value);
    } else if (value is double) {
      await _prefs!.setDouble(key, value);
    }
  }

  /// Get setting value or default
  static T get<T>(String key, T defaultValue) {
    if (_prefs == null) return defaultValue;
    return _prefs!.get(key) as T? ?? defaultValue;
  }
}

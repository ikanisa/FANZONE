import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Lightweight JSON read/write on top of SharedPreferences.
/// Uses SharedPreferences directly (no DI) since it's a static utility.
abstract final class PreferencesJsonStore {
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<Map<String, dynamic>?> readMap(
    String key, {
    String? debugLabel,
  }) async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> readList(
    String key, {
    String? debugLabel,
  }) async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(key);
    if (raw == null) return const [];
    try {
      final list = json.decode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> write(String key, Object value) async {
    final prefs = await _getPrefs();
    await prefs.setString(key, json.encode(value));
  }
}

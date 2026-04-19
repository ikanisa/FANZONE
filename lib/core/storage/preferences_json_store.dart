import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../logging/app_logger.dart';

abstract final class PreferencesJsonStore {
  static Future<Map<String, dynamic>?> readMap(
    String key, {
    String? debugLabel,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (error) {
      _logDecodeError(debugLabel ?? key, error);
    }

    return null;
  }

  static Future<List<Map<String, dynamic>>> readList(
    String key, {
    String? debugLabel,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      return decoded
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } catch (error) {
      _logDecodeError(debugLabel ?? key, error);
      return const [];
    }
  }

  static Future<void> write(String key, Object value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }

  static void _logDecodeError(String label, Object error) {
    AppLogger.d('Failed to decode $label cache: $error');
  }
}

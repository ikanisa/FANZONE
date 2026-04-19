import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logging/app_logger.dart';
import 'cache_service.dart';

@LazySingleton(as: CacheService)
class SharedPreferencesCacheService implements CacheService {
  SharedPreferencesCacheService(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<String?> getString(String key) async => _prefs.getString(key);

  @override
  Future<bool?> getBool(String key) async => _prefs.getBool(key);

  @override
  Future<List<String>> getStringList(String key) async =>
      List<String>.from(_prefs.getStringList(key) ?? const <String>[]);

  @override
  Future<Map<String, dynamic>?> getJsonMap(
    String key, {
    String? debugLabel,
  }) async {
    final raw = _prefs.getString(key);
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

  @override
  Future<List<Map<String, dynamic>>> getJsonList(
    String key, {
    String? debugLabel,
  }) async {
    final raw = _prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      return decoded
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    } catch (error) {
      _logDecodeError(debugLabel ?? key, error);
      return const [];
    }
  }

  @override
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    await _prefs.setStringList(key, value);
  }

  @override
  Future<void> setJson(String key, Object value) async {
    await _prefs.setString(key, jsonEncode(value));
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  void _logDecodeError(String label, Object error) {
    AppLogger.d('Failed to decode $label cache: $error');
  }
}

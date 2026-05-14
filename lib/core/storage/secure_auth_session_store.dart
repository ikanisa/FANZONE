import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../logging/app_logger.dart';

abstract final class SecureAuthSessionStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(storageNamespace: 'fanzone.auth.session.v1'),
    iOptions: IOSOptions(
      accountName: 'fanzone.auth.session',
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
    mOptions: MacOsOptions(
      accountName: 'fanzone.auth.session',
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
  );

  static Future<void> writeMap(String key, Map<String, dynamic> payload) {
    return _storage.write(key: key, value: jsonEncode(payload));
  }

  static Future<Map<String, dynamic>?> readMap(String key) async {
    final raw = await _storage.read(key: key);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (error) {
      AppLogger.d('Failed to decode secure auth session for $key: $error');
      await delete(key);
    }

    return null;
  }

  static Future<void> delete(String key) {
    return _storage.delete(key: key);
  }
}

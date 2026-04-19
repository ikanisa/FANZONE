import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../logging/app_logger.dart';

enum StructuredCacheKind { map, list }

class StructuredCacheSnapshot<T> {
  const StructuredCacheSnapshot({
    required this.key,
    required this.kind,
    required this.payload,
    required this.cachedAt,
    required this.expiresAt,
  });

  final String key;
  final StructuredCacheKind kind;
  final T payload;
  final DateTime cachedAt;
  final DateTime? expiresAt;

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}

abstract final class StructuredCacheStore {
  static const _boxName = 'structured_offline_cache_v1';
  static const _schemaVersion = 1;

  static Box<dynamic>? _box;
  static Future<void>? _openBoxFuture;
  static final Set<String> _refreshingKeys = <String>{};

  static Future<void> init({String? directory}) async {
    if (_box?.isOpen ?? false) return;

    if (directory == null) {
      await Hive.initFlutter();
    } else {
      Hive.init(directory);
    }
    await _openBox();
  }

  static Future<void> resetForTest() async {
    _refreshingKeys.clear();
    if (_box != null && _box!.isOpen) {
      await _box!.deleteFromDisk();
    }
    _box = null;
    _openBoxFuture = null;
  }

  static Future<void> writeMap(
    String key,
    Map<String, dynamic> payload, {
    Duration? ttl,
    Map<String, dynamic>? metadata,
  }) {
    return _write(
      key,
      kind: StructuredCacheKind.map,
      payload: payload,
      ttl: ttl,
      metadata: metadata,
    );
  }

  static Future<void> writeList(
    String key,
    List<Map<String, dynamic>> payload, {
    Duration? ttl,
    Map<String, dynamic>? metadata,
  }) {
    return _write(
      key,
      kind: StructuredCacheKind.list,
      payload: payload,
      ttl: ttl,
      metadata: metadata,
    );
  }

  static Future<StructuredCacheSnapshot<Map<String, dynamic>>?> readMap(
    String key, {
    bool allowExpired = true,
  }) async {
    final snapshot = await _read(key);
    if (snapshot == null || snapshot.kind != StructuredCacheKind.map) {
      return null;
    }
    if (!allowExpired && snapshot.isExpired) {
      return null;
    }

    final payload = snapshot.payload;
    if (payload is Map<String, dynamic>) {
      return StructuredCacheSnapshot<Map<String, dynamic>>(
        key: snapshot.key,
        kind: snapshot.kind,
        payload: payload,
        cachedAt: snapshot.cachedAt,
        expiresAt: snapshot.expiresAt,
      );
    }

    if (payload is Map) {
      return StructuredCacheSnapshot<Map<String, dynamic>>(
        key: snapshot.key,
        kind: snapshot.kind,
        payload: Map<String, dynamic>.from(payload),
        cachedAt: snapshot.cachedAt,
        expiresAt: snapshot.expiresAt,
      );
    }

    return null;
  }

  static Future<StructuredCacheSnapshot<List<Map<String, dynamic>>>?> readList(
    String key, {
    bool allowExpired = true,
  }) async {
    final snapshot = await _read(key);
    if (snapshot == null || snapshot.kind != StructuredCacheKind.list) {
      return null;
    }
    if (!allowExpired && snapshot.isExpired) {
      return null;
    }

    final payload = snapshot.payload;
    if (payload is! List) return null;

    return StructuredCacheSnapshot<List<Map<String, dynamic>>>(
      key: snapshot.key,
      kind: snapshot.kind,
      payload: payload
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList(growable: false),
      cachedAt: snapshot.cachedAt,
      expiresAt: snapshot.expiresAt,
    );
  }

  static Future<void> delete(String key) async {
    final box = await _openBox();
    await box.delete(key);
  }

  static void scheduleRefresh(
    String key,
    Future<void> Function() refresh, {
    String? debugLabel,
  }) {
    if (!_refreshingKeys.add(key)) return;

    unawaited(() async {
      try {
        await refresh();
      } catch (error) {
        AppLogger.d(
          'Background cache refresh failed for ${debugLabel ?? key}: $error',
        );
      } finally {
        _refreshingKeys.remove(key);
      }
    }());
  }

  static Future<Box<dynamic>> _openBox() async {
    if (_box?.isOpen ?? false) return _box!;

    final existingFuture = _openBoxFuture;
    if (existingFuture != null) {
      await existingFuture;
      return _box!;
    }

    final completer = Completer<void>();
    _openBoxFuture = completer.future;

    try {
      _box = await Hive.openBox<dynamic>(_boxName);
      completer.complete();
      return _box!;
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
      rethrow;
    } finally {
      _openBoxFuture = null;
    }
  }

  static Future<void> _write(
    String key, {
    required StructuredCacheKind kind,
    required Object payload,
    Duration? ttl,
    Map<String, dynamic>? metadata,
  }) async {
    final box = await _openBox();
    final now = DateTime.now();

    await box.put(key, <String, dynamic>{
      'schema_version': _schemaVersion,
      'kind': kind.name,
      'payload_json': jsonEncode(payload),
      'cached_at_ms': now.millisecondsSinceEpoch,
      'expires_at_ms': ttl == null ? null : now.add(ttl).millisecondsSinceEpoch,
      'metadata': metadata ?? const <String, dynamic>{},
    });
  }

  static Future<StructuredCacheSnapshot<dynamic>?> _read(String key) async {
    final box = await _openBox();
    final raw = box.get(key);
    if (raw is! Map) return null;

    try {
      final rawMap = Map<String, dynamic>.from(raw);
      if (rawMap['schema_version'] != _schemaVersion) {
        await box.delete(key);
        return null;
      }

      final kindName = rawMap['kind']?.toString();
      final payloadJson = rawMap['payload_json']?.toString();
      if (kindName == null || payloadJson == null) return null;

      final cachedAt = DateTime.fromMillisecondsSinceEpoch(
        (rawMap['cached_at_ms'] as num?)?.toInt() ?? 0,
      );
      final expiresAtMs = (rawMap['expires_at_ms'] as num?)?.toInt();
      final expiresAt = expiresAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiresAtMs);

      return StructuredCacheSnapshot<dynamic>(
        key: key,
        kind: StructuredCacheKind.values.byName(kindName),
        payload: jsonDecode(payloadJson),
        cachedAt: cachedAt,
        expiresAt: expiresAt,
      );
    } catch (error) {
      AppLogger.d('Failed to decode structured cache for $key: $error');
      await box.delete(key);
      return null;
    }
  }
}

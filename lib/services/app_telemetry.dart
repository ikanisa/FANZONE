import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../core/logging/app_logger.dart';
import '../core/runtime/app_runtime_state.dart';
import '../core/storage/structured_cache_store.dart';

/// Supabase-backed runtime error capture with offline queueing.
///
/// This keeps a production-visible error trail without changing the user
/// experience or requiring a separate third-party crash provider.
class AppTelemetry {
  AppTelemetry._();

  static const String _queueCacheKey = 'app_runtime_error_queue_v1';
  static const int _maxQueueLength = 50;
  static final String _sessionId = const Uuid().v4();

  static final List<_TelemetryEvent> _queue = <_TelemetryEvent>[];
  static bool _started = false;
  static bool _restored = false;

  static Future<void> start() async {
    if (_started) return;
    _started = true;
    await _restoreQueue();
    await flush();
  }

  static Future<void> captureException(
    Object error,
    StackTrace stackTrace, {
    String? reason,
  }) async {
    final event = _TelemetryEvent(
      reason: (reason ?? 'app_exception').trim(),
      message: error.toString().trim(),
      stackTrace: stackTrace.toString().trim(),
      sessionId: _sessionId,
      platform: defaultTargetPlatform.name,
      appVersion: AppConfig.appVersion,
      capturedAt: DateTime.now().toUtc(),
    );

    _queue.add(event);
    _trimQueue();
    await _persistQueue();
    AppLogger.e(reason ?? 'Captured error', error, stackTrace);
    unawaited(flush());
  }

  static Future<void> flush() async {
    if (_queue.isEmpty || !appRuntime.supabaseInitialized) return;

    final batch = List<_TelemetryEvent>.from(_queue);
    _queue.clear();

    try {
      final client = Supabase.instance.client;
      final payload = batch
          .map((event) => event.toJson())
          .toList(growable: false);
      await client.rpc(
        'log_app_runtime_errors_batch',
        params: {'p_errors': payload},
      );
      await _persistQueue();
    } catch (error, stackTrace) {
      _queue.insertAll(0, batch);
      _trimQueue();
      await _persistQueue();
      AppLogger.e('Failed to flush runtime errors', error, stackTrace);
    }
  }

  static Future<void> _restoreQueue() async {
    if (_restored) return;
    _restored = true;

    try {
      final snapshot = await StructuredCacheStore.readList(_queueCacheKey);
      final restored =
          snapshot?.payload
              .map(_TelemetryEvent.fromJson)
              .whereType<_TelemetryEvent>()
              .toList(growable: false) ??
          const <_TelemetryEvent>[];
      if (restored.isEmpty) return;

      _queue
        ..clear()
        ..addAll(restored);
      _trimQueue();
    } catch (error, stackTrace) {
      AppLogger.e('Failed to restore runtime error queue', error, stackTrace);
    }
  }

  static Future<void> _persistQueue() async {
    try {
      if (_queue.isEmpty) {
        await StructuredCacheStore.delete(_queueCacheKey);
        return;
      }

      await StructuredCacheStore.writeList(
        _queueCacheKey,
        _queue.map((event) => event.toJson()).toList(growable: false),
      );
    } catch (error, stackTrace) {
      AppLogger.e('Failed to persist runtime error queue', error, stackTrace);
    }
  }

  static void _trimQueue() {
    if (_queue.length <= _maxQueueLength) return;
    _queue.removeRange(0, _queue.length - _maxQueueLength);
  }
}

class _TelemetryEvent {
  const _TelemetryEvent({
    required this.reason,
    required this.message,
    required this.stackTrace,
    required this.sessionId,
    required this.platform,
    required this.appVersion,
    required this.capturedAt,
  });

  final String reason;
  final String message;
  final String stackTrace;
  final String sessionId;
  final String platform;
  final String appVersion;
  final DateTime capturedAt;

  Map<String, dynamic> toJson() => {
    'reason': reason,
    'error_message': message,
    'stack_trace': stackTrace,
    'session_id': sessionId,
    'platform': platform,
    'app_version': appVersion,
    'captured_at': capturedAt.toIso8601String(),
  };

  static _TelemetryEvent? fromJson(Map<String, dynamic> json) {
    final reason = json['reason']?.toString().trim();
    final message = json['error_message']?.toString().trim();
    final stackTrace = json['stack_trace']?.toString().trim() ?? '';
    final sessionId = json['session_id']?.toString().trim();
    final platform = json['platform']?.toString().trim();
    final appVersion = json['app_version']?.toString().trim();
    final capturedAtRaw = json['captured_at']?.toString();

    if (reason == null ||
        reason.isEmpty ||
        message == null ||
        message.isEmpty ||
        sessionId == null ||
        sessionId.isEmpty ||
        platform == null ||
        platform.isEmpty ||
        appVersion == null ||
        appVersion.isEmpty ||
        capturedAtRaw == null) {
      return null;
    }

    final capturedAt = DateTime.tryParse(capturedAtRaw)?.toUtc();
    if (capturedAt == null) return null;

    return _TelemetryEvent(
      reason: reason,
      message: message,
      stackTrace: stackTrace,
      sessionId: sessionId,
      platform: platform,
      appVersion: appVersion,
      capturedAt: capturedAt,
    );
  }
}

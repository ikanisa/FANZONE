import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/runtime/app_runtime_state.dart';
import '../core/storage/structured_cache_store.dart';
import '../core/logging/app_logger.dart';
import '../core/supabase/supabase_connection.dart';

/// Lightweight product analytics service backed by Supabase.
///
/// Events are queued in memory and flushed to the `log_product_events_batch`
/// RPC every [_flushInterval] seconds or when the queue hits [_maxBatchSize].
///
/// Usage:
/// ```dart
/// ProductAnalytics.trackScreen('home_feed');
/// ProductAnalytics.trackAction('prediction_submitted', {'match_id': '...'});
/// ```
class ProductAnalytics {
  ProductAnalytics._();

  // ── Configuration ──

  static const Duration _flushInterval = Duration(seconds: 5);
  static const int _maxBatchSize = 10;
  static const int _maxQueueLength = 100;
  static const String _queueCacheKey = 'product_analytics_queue_v1';

  // ── State ──

  static final String _sessionId = const Uuid().v4();
  static final List<_AnalyticsEvent> _queue = [];
  static Timer? _flushTimer;
  static bool _initialized = false;
  static bool _restored = false;
  static final SupabaseConnection _connection = SupabaseConnectionImpl();

  // ── Lifecycle ──

  /// Call once from main.dart after Supabase is initialized.
  static void initialize() {
    if (_initialized) return;
    _initialized = true;
    _flushTimer = Timer.periodic(_flushInterval, (_) => flush());
    unawaited(_restoreQueue());
    AppLogger.d('[Analytics] Initialized with session $_sessionId');
  }

  /// Flush remaining events on app pause/dispose.
  static Future<void> dispose() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    await flush();
  }

  // ── Tracking API ──

  /// Track a screen view.
  static void trackScreen(String screenName) {
    _enqueue('screen_view', {'screen': screenName});
  }

  /// Track a user action with optional properties.
  static void trackAction(String actionName, [Map<String, dynamic>? props]) {
    _enqueue(actionName, props ?? {});
  }

  // ── Convenience Methods (typed, discoverable) ──

  static void predictionSubmitted({
    required String matchId,
    required String market,
    required String selection,
  }) {
    _enqueue('prediction_submitted', {
      'match_id': matchId,
      'market': market,
      'selection': selection,
    });
  }

  static void poolJoined({required String poolId}) {
    _enqueue('pool_joined', {'pool_id': poolId});
  }

  static void poolCreated({required String poolId}) {
    _enqueue('pool_created', {'pool_id': poolId});
  }

  static void dailyChallengeEntered({required String challengeId}) {
    _enqueue('daily_challenge_entered', {'challenge_id': challengeId});
  }

  static void walletAction({required String action, required int amountFet}) {
    _enqueue('wallet_action', {'action': action, 'amount_fet': amountFet});
  }

  static void fanIdViewed() {
    _enqueue('fan_id_viewed', {});
  }

  static void teamSupported({required String teamId}) {
    _enqueue('team_supported', {'team_id': teamId});
  }

  static void searchPerformed({required String query}) {
    _enqueue('search_performed', {'query_length': query.length});
  }

  static void matchDetailViewed({required String matchId}) {
    _enqueue('match_detail_viewed', {'match_id': matchId});
  }

  static void notificationOpened({String? type}) {
    _enqueue('notification_opened', {'type': type ?? 'unknown'});
  }

  // ── Internal ──

  static void _enqueue(String eventName, Map<String, dynamic> properties) {
    if (!_initialized) return;

    _queue.add(
      _AnalyticsEvent(
        eventName: eventName,
        properties: properties,
        sessionId: _sessionId,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    _trimQueue();
    unawaited(_persistQueue());

    if (_queue.length >= _maxBatchSize) {
      unawaited(flush());
    }
  }

  /// Flush queued events to Supabase. Safe to call multiple times.
  static Future<void> flush() async {
    if (_queue.isEmpty) return;

    final batch = List<_AnalyticsEvent>.from(_queue);
    _queue.clear();

    try {
      final client = _connection.client;
      if (client == null) {
        _queue.insertAll(0, batch);
        _trimQueue();
        await _persistQueue();
        return;
      }

      // Only log if user is authenticated (anonymous events skip)
      if (_connection.currentUser == null) {
        // Re-queue — user might authenticate soon
        _queue.insertAll(0, batch);
        _trimQueue();
        await _persistQueue();
        return;
      }

      final payload = batch
          .map(
            (event) => {
              'event_name': event.eventName,
              'properties': event.properties,
              'session_id': event.sessionId,
              'created_at': event.createdAt.toIso8601String(),
            },
          )
          .toList();

      await client.rpc(
        'log_product_events_batch',
        params: {'p_events': payload},
      );
      await _persistQueue();

      if (kDebugMode) {
        AppLogger.d('[Analytics] Flushed ${batch.length} events');
      }
    } catch (error) {
      // Re-queue on failure (best effort — drop if queue is too large)
      _queue.insertAll(0, batch);
      _trimQueue();
      await _persistQueue();
      AppLogger.d('[Analytics] Flush failed: $error');
    }
  }

  static Future<void> _restoreQueue() async {
    if (_restored) return;
    _restored = true;

    final snapshot = await StructuredCacheStore.readList(_queueCacheKey);
    final restored =
        snapshot?.payload
            .map(_AnalyticsEvent.fromJson)
            .whereType<_AnalyticsEvent>()
            .toList(growable: false) ??
        const <_AnalyticsEvent>[];
    if (restored.isEmpty) return;

    _queue.insertAll(0, restored);
    _trimQueue();
    if (appRuntime.supabaseInitialized && _connection.currentUser != null) {
      unawaited(flush());
    }
  }

  static Future<void> _persistQueue() async {
    if (_queue.isEmpty) {
      await StructuredCacheStore.delete(_queueCacheKey);
      return;
    }

    await StructuredCacheStore.writeList(
      _queueCacheKey,
      _queue.map((event) => event.toJson()).toList(growable: false),
    );
  }

  static void _trimQueue() {
    if (_queue.length <= _maxQueueLength) return;
    _queue.removeRange(0, _queue.length - _maxQueueLength);
  }
}

class _AnalyticsEvent {
  const _AnalyticsEvent({
    required this.eventName,
    required this.properties,
    required this.sessionId,
    required this.createdAt,
  });

  final String eventName;
  final Map<String, dynamic> properties;
  final String sessionId;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'event_name': eventName,
    'properties': properties,
    'session_id': sessionId,
    'created_at': createdAt.toIso8601String(),
  };

  static _AnalyticsEvent? fromJson(Map<String, dynamic> json) {
    final eventName = json['event_name']?.toString().trim();
    final sessionId = json['session_id']?.toString().trim();
    final createdAtRaw = json['created_at']?.toString();
    final propertiesRaw = json['properties'];
    if (eventName == null ||
        eventName.isEmpty ||
        sessionId == null ||
        sessionId.isEmpty ||
        createdAtRaw == null) {
      return null;
    }

    final createdAt = DateTime.tryParse(createdAtRaw)?.toUtc();
    if (createdAt == null) return null;

    final properties = propertiesRaw is Map
        ? Map<String, dynamic>.from(propertiesRaw)
        : const <String, dynamic>{};

    return _AnalyticsEvent(
      eventName: eventName,
      properties: properties,
      sessionId: sessionId,
      createdAt: createdAt,
    );
  }
}

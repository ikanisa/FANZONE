import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/logging/app_logger.dart';
import '../main.dart' show supabaseInitialized;
import '../providers/auth_provider.dart';
import '../models/notification_model.dart';

part 'notification_service.g.dart';

const _matchAlertStorageKey = 'fz_match_alert_match_ids';

/// Service for managing device tokens, notification preferences, and notification log.
@riverpod
class NotificationService extends _$NotificationService {
  @override
  FutureOr<NotificationPreferences> build() async {
    ref.watch(authStateProvider);

    if (!supabaseInitialized) return const NotificationPreferences();

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return const NotificationPreferences();

    final data = await client
        .from('notification_preferences')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (data == null) return const NotificationPreferences();

    return NotificationPreferences(
      goalAlerts: data['goal_alerts'] as bool? ?? true,
      poolUpdates: data['pool_updates'] as bool? ?? true,
      dailyChallenge: data['daily_challenge'] as bool? ?? true,
      walletActivity: data['wallet_activity'] as bool? ?? true,
      communityNews: data['community_news'] as bool? ?? true,
      marketing: data['marketing'] as bool? ?? false,
    );
  }

  /// Update notification preferences.
  Future<void> updatePreferences(NotificationPreferences prefs) async {
    if (!supabaseInitialized) return;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    await client.from('notification_preferences').upsert({
      'user_id': userId,
      'goal_alerts': prefs.goalAlerts,
      'pool_updates': prefs.poolUpdates,
      'daily_challenge': prefs.dailyChallenge,
      'wallet_activity': prefs.walletActivity,
      'community_news': prefs.communityNews,
      'marketing': prefs.marketing,
      'updated_at': DateTime.now().toIso8601String(),
    });

    state = AsyncValue.data(prefs);
  }

  /// Register a device token for push notifications.
  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    if (!supabaseInitialized) return;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    await client.from('device_tokens').upsert({
      'user_id': userId,
      'token': token,
      'platform': platform,
      'is_active': true,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,token');

    AppLogger.d(
      '[FANZONE] Device token registered: ${token.substring(0, 8)}...',
    );
  }

  /// Deactivate a device token (on logout).
  Future<void> deactivateDeviceToken(String token) async {
    if (!supabaseInitialized) return;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    await client
        .from('device_tokens')
        .update({
          'is_active': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('token', token);
  }

  /// Mark a notification as read.
  Future<void> markAsRead(String notificationId) async {
    if (!supabaseInitialized) return;

    final client = Supabase.instance.client;
    await client
        .from('notification_log')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('id', notificationId);

    ref.invalidate(notificationLogProvider);
    ref.invalidate(unreadNotificationCountProvider);
  }

  /// Mark all notifications as read.
  Future<void> markAllRead() async {
    if (!supabaseInitialized) return;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    await client
        .from('notification_log')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('user_id', userId)
        .isFilter('read_at', null);

    ref.invalidate(notificationLogProvider);
    ref.invalidate(unreadNotificationCountProvider);
  }

  /// Enable or disable kickoff/goal/result alerts for a specific match.
  Future<void> setMatchAlerts({
    required String matchId,
    required bool enabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (!supabaseInitialized) {
      await _persistLocalMatchAlertPreference(
        prefs: prefs,
        matchId: matchId,
        enabled: enabled,
      );
      ref.invalidate(matchAlertEnabledProvider(matchId));
      return;
    }

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      await _persistLocalMatchAlertPreference(
        prefs: prefs,
        matchId: matchId,
        enabled: enabled,
      );
      ref.invalidate(matchAlertEnabledProvider(matchId));
      return;
    }

    if (enabled) {
      await client.from('match_alert_subscriptions').upsert({
        'user_id': userId,
        'match_id': matchId,
        'alert_kickoff': true,
        'alert_goals': true,
        'alert_result': true,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,match_id');
    } else {
      await client
          .from('match_alert_subscriptions')
          .delete()
          .eq('user_id', userId)
          .eq('match_id', matchId);
    }

    ref.invalidate(matchAlertEnabledProvider(matchId));
  }

  Future<void> _persistLocalMatchAlertPreference({
    required SharedPreferences prefs,
    required String matchId,
    required bool enabled,
  }) async {
    final current = prefs.getStringList(_matchAlertStorageKey) ?? const [];
    final next = {...current};
    if (enabled) {
      next.add(matchId);
    } else {
      next.remove(matchId);
    }
    await prefs.setStringList(_matchAlertStorageKey, next.toList()..sort());
  }
}

/// Provider for notification log (recent notifications).
@riverpod
FutureOr<List<NotificationItem>> notificationLog(Ref ref) async {
  ref.watch(authStateProvider);

  if (!supabaseInitialized) return const [];

  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return const [];

  final data = await client
      .from('notification_log')
      .select()
      .eq('user_id', userId)
      .order('sent_at', ascending: false)
      .limit(50);

  return (data as List)
      .map(
        (row) => NotificationItem(
          id: row['id']?.toString() ?? '',
          type: row['type']?.toString() ?? '',
          title: row['title']?.toString() ?? '',
          body: row['body']?.toString() ?? '',
          data: _normalizeNotificationData(row['data']),
          sentAt:
              DateTime.tryParse(row['sent_at']?.toString() ?? '') ??
              DateTime.now(),
          readAt: row['read_at'] != null
              ? DateTime.tryParse(row['read_at'].toString())
              : null,
        ),
      )
      .toList();
}

/// Provider for unread notification count.
@riverpod
FutureOr<int> unreadNotificationCount(Ref ref) async {
  final notifications = await ref.watch(notificationLogProvider.future);
  return notifications.where((n) => n.readAt == null).length;
}

final matchAlertEnabledProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, matchId) async {
      ref.watch(authStateProvider);

      final prefs = await SharedPreferences.getInstance();
      final localIds = prefs.getStringList(_matchAlertStorageKey) ?? const [];

      if (!supabaseInitialized) {
        return localIds.contains(matchId);
      }

      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        return localIds.contains(matchId);
      }

      final data = await client
          .from('match_alert_subscriptions')
          .select('match_id')
          .eq('user_id', userId)
          .eq('match_id', matchId)
          .maybeSingle();
      return data != null;
    });

/// Provider for user stats (prediction streaks, etc.).
@riverpod
FutureOr<UserStats> userStats(Ref ref) async {
  ref.watch(authStateProvider);

  if (!supabaseInitialized) return const UserStats();

  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return const UserStats();

  final data = await client
      .from('user_status')
      .select()
      .eq('user_id', userId)
      .maybeSingle();

  if (data == null) return const UserStats();

  return UserStats(
    predictionStreak: (data['prediction_streak'] as num?)?.toInt() ?? 0,
    longestStreak: (data['longest_streak'] as num?)?.toInt() ?? 0,
    totalPredictions: (data['total_predictions'] as num?)?.toInt() ?? 0,
    totalPoolsEntered: (data['total_pools_entered'] as num?)?.toInt() ?? 0,
    totalPoolsWon: (data['total_pools_won'] as num?)?.toInt() ?? 0,
    totalFetEarned: (data['total_fet_earned'] as num?)?.toInt() ?? 0,
    totalFetSpent: (data['total_fet_spent'] as num?)?.toInt() ?? 0,
  );
}

Map<String, dynamic> _normalizeNotificationData(dynamic rawData) {
  if (rawData is Map<String, dynamic>) return rawData;
  if (rawData is Map) {
    return rawData.map((key, value) => MapEntry(key.toString(), value));
  }
  if (rawData is String && rawData.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(rawData);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      return const {};
    }
  }
  return const {};
}

import 'package:injectable/injectable.dart';

import '../../../config/app_config.dart';
import '../../../core/cache/cache_service.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/notification_model.dart';
import 'preferences_gateway_shared.dart';

abstract interface class NotificationSettingsGateway {
  Future<NotificationPreferences> getNotificationPreferences(String userId);

  Future<void> saveNotificationPreferences(
    String userId,
    NotificationPreferences preferences,
  );

  Future<void> ensureDefaultNotificationPreferences(String userId);

  Future<void> registerDeviceToken({
    String? userId,
    required String token,
    required String platform,
  });

  Future<void> deactivateDeviceToken({String? userId, required String token});

  Future<void> markNotificationAsRead(String notificationId);

  Future<void> markAllNotificationsRead(String userId);

  Future<void> setMatchAlertEnabled({
    String? userId,
    required String matchId,
    required bool enabled,
  });

  Future<List<NotificationItem>> getNotificationLog(String userId);

  Future<bool> isMatchAlertEnabled({String? userId, required String matchId});

  Future<int> getUnreadNotificationCount(String userId);

  Future<UserStats> getUserStats(String userId);
}

@LazySingleton(as: NotificationSettingsGateway)
class SupabaseNotificationSettingsGateway
    implements NotificationSettingsGateway {
  SupabaseNotificationSettingsGateway(this._cache, this._connection);

  final CacheService _cache;
  final SupabaseConnection _connection;

  @override
  Future<NotificationPreferences> getNotificationPreferences(
    String userId,
  ) async {
    final cached = await _cachedNotificationPreferences(userId);
    final client = _connection.client;
    if (client == null) return cached ?? const NotificationPreferences();

    try {
      final row = await client
          .from('notification_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return cached ?? const NotificationPreferences();

      final preferences = NotificationPreferences.fromJson(
        Map<String, dynamic>.from(row),
      );
      await _cacheNotificationPreferences(userId, preferences);
      return preferences;
    } catch (error) {
      AppLogger.d('Failed to load notification preferences: $error');
      return cached ?? const NotificationPreferences();
    }
  }

  @override
  Future<void> saveNotificationPreferences(
    String userId,
    NotificationPreferences preferences,
  ) async {
    await _cacheNotificationPreferences(userId, preferences);

    final client = _connection.client;
    if (client == null) return;

    try {
      await client.from('notification_preferences').upsert({
        'user_id': userId,
        'goal_alerts': preferences.goalAlerts,
        'pool_updates': preferences.poolUpdates,
        'daily_challenge': preferences.dailyChallenge,
        'wallet_activity': preferences.walletActivity,
        'community_news': preferences.communityNews,
        'marketing': preferences.marketing,
      }, onConflict: 'user_id');
    } catch (error) {
      AppLogger.d('Failed to save notification preferences: $error');
    }
  }

  @override
  Future<void> ensureDefaultNotificationPreferences(String userId) async {
    final current = await getNotificationPreferences(userId);
    if (current != const NotificationPreferences()) return;
    await saveNotificationPreferences(userId, const NotificationPreferences());
  }

  @override
  Future<void> registerDeviceToken({
    String? userId,
    required String token,
    required String platform,
  }) async {
    final scopedUser = userId ?? 'guest';
    final key = '$deviceTokensCachePrefix$scopedUser';
    final next = {...await _cache.getStringList(key), '$platform:$token'}
      ..removeWhere((value) => value.trim().isEmpty);
    await _cache.setStringList(key, next.toList()..sort());

    final client = _connection.client;
    if (client == null || userId == null) return;

    try {
      await client.from('device_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': platform,
        'is_active': true,
      }, onConflict: 'user_id,token');
    } catch (error) {
      AppLogger.d('Failed to register device token: $error');
    }
  }

  @override
  Future<void> deactivateDeviceToken({
    String? userId,
    required String token,
  }) async {
    final scopedUser = userId ?? 'guest';
    final key = '$deviceTokensCachePrefix$scopedUser';
    final next = (await _cache.getStringList(
      key,
    )).where((value) => !value.endsWith(':$token')).toList(growable: false);
    await _cache.setStringList(key, next);

    final client = _connection.client;
    if (client == null || userId == null) return;

    try {
      await client
          .from('device_tokens')
          .update({'is_active': false})
          .eq('user_id', userId)
          .eq('token', token);
    } catch (error) {
      AppLogger.d('Failed to deactivate device token: $error');
    }
  }

  @override
  Future<void> markNotificationAsRead(String notificationId) async {
    final userId = _connection.currentUser?.id;
    final client = _connection.client;
    if (client != null) {
      try {
        await client
            .from('notification_log')
            .update({'read_at': DateTime.now().toUtc().toIso8601String()})
            .eq('id', notificationId);
      } catch (error) {
        AppLogger.d('Failed to mark notification as read: $error');
      }
    }

    if (userId == null) return;
    final notifications = await getNotificationLog(userId);
    final updated = notifications
        .map(
          (item) => item.id == notificationId
              ? item.copyWith(readAt: DateTime.now())
              : item,
        )
        .toList(growable: false);
    await _cacheNotificationLog(userId, updated);
  }

  @override
  Future<void> markAllNotificationsRead(String userId) async {
    final client = _connection.client;
    if (client != null) {
      try {
        await client
            .from('notification_log')
            .update({'read_at': DateTime.now().toUtc().toIso8601String()})
            .eq('user_id', userId);
      } catch (error) {
        AppLogger.d('Failed to mark all notifications read: $error');
      }
    }

    final notifications = await getNotificationLog(userId);
    final updated = notifications
        .map((item) => item.copyWith(readAt: item.readAt ?? DateTime.now()))
        .toList(growable: false);
    await _cacheNotificationLog(userId, updated);
  }

  @override
  Future<void> setMatchAlertEnabled({
    String? userId,
    required String matchId,
    required bool enabled,
  }) async {
    final scopedUser = userId ?? 'guest';
    final key = '$matchAlertsCachePrefix$scopedUser';
    final client = _connection.client;

    if (client != null && userId != null) {
      try {
        if (enabled) {
          await client.from('match_alert_subscriptions').upsert({
            'user_id': userId,
            'match_id': matchId,
            'alert_kickoff': true,
            'alert_goals': true,
            'alert_result': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'user_id,match_id');
        } else {
          await client
              .from('match_alert_subscriptions')
              .delete()
              .eq('user_id', userId)
              .eq('match_id', matchId);
        }
      } catch (error) {
        AppLogger.d('Failed to update match alert subscription: $error');
        rethrow;
      }
    }

    final next = {...await _cache.getStringList(key)};
    if (enabled) {
      next.add(matchId);
    } else {
      next.remove(matchId);
    }
    await _cache.setStringList(key, next.toList()..sort());
  }

  @override
  Future<List<NotificationItem>> getNotificationLog(String userId) async {
    final cached = await _cachedNotificationLog(userId);
    final client = _connection.client;
    if (client == null) return cached;

    try {
      final rows = await client
          .from('notification_log')
          .select()
          .eq('user_id', userId)
          .order('sent_at', ascending: false);
      final notifications = (rows as List)
          .whereType<Map>()
          .map(
            (row) => NotificationItem.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
      if (notifications.isNotEmpty) {
        await _cacheNotificationLog(userId, notifications);
        return notifications;
      }
      return cached;
    } catch (error) {
      AppLogger.d('Failed to load notification log: $error');
      return cached;
    }
  }

  @override
  Future<bool> isMatchAlertEnabled({
    String? userId,
    required String matchId,
  }) async {
    final scopedUser = userId ?? 'guest';
    final cacheKey = '$matchAlertsCachePrefix$scopedUser';
    final client = _connection.client;

    if (client != null && userId != null) {
      try {
        final row = await client
            .from('match_alert_subscriptions')
            .select('match_id')
            .eq('user_id', userId)
            .eq('match_id', matchId)
            .maybeSingle();
        final enabled = row != null;
        final next = {...await _cache.getStringList(cacheKey)};
        if (enabled) {
          next.add(matchId);
        } else {
          next.remove(matchId);
        }
        await _cache.setStringList(cacheKey, next.toList()..sort());
        return enabled;
      } catch (error) {
        AppLogger.d('Failed to load match alert subscription: $error');
      }
    }

    final existing = await _cache.getStringList(cacheKey);
    return existing.contains(matchId);
  }

  @override
  Future<int> getUnreadNotificationCount(String userId) async {
    final notifications = await getNotificationLog(userId);
    return notifications.where((item) => item.readAt == null).length;
  }

  @override
  Future<UserStats> getUserStats(String userId) async {
    final client = _connection.client;
    if (client == null) {
      return AppConfig.isProduction ? const UserStats() : fallbackUserStats;
    }

    try {
      final row = await client
          .from('user_status')
          .select(
            'prediction_streak, longest_streak, total_predictions, total_pools_entered, total_pools_won, total_fet_earned, total_fet_spent',
          )
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) {
        return AppConfig.isProduction ? const UserStats() : fallbackUserStats;
      }
      return UserStats.fromJson(Map<String, dynamic>.from(row));
    } catch (error) {
      AppLogger.d('Failed to load user stats: $error');
      return AppConfig.isProduction ? const UserStats() : fallbackUserStats;
    }
  }

  Future<NotificationPreferences?> _cachedNotificationPreferences(
    String userId,
  ) async {
    final row = await _cache.getJsonMap(
      '$notificationPreferencesCachePrefix$userId',
      debugLabel: 'notification preferences',
    );
    return row == null ? null : NotificationPreferences.fromJson(row);
  }

  Future<void> _cacheNotificationPreferences(
    String userId,
    NotificationPreferences preferences,
  ) {
    return _cache.setJson(
      '$notificationPreferencesCachePrefix$userId',
      preferences.toJson(),
    );
  }

  Future<List<NotificationItem>> _cachedNotificationLog(String userId) async {
    final rows = await _cache.getJsonList(
      '$notificationLogCachePrefix$userId',
      debugLabel: 'notification log',
    );
    return rows.map(NotificationItem.fromJson).toList(growable: false);
  }

  Future<void> _cacheNotificationLog(
    String userId,
    List<NotificationItem> notifications,
  ) {
    return _cache.setJson(
      '$notificationLogCachePrefix$userId',
      notifications.map((item) => item.toJson()).toList(growable: false),
    );
  }
}

import 'package:injectable/injectable.dart';

import '../../../core/cache/cache_service.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/account_deletion_request_model.dart';
import '../../../models/notification_model.dart';
import '../../../models/privacy_settings_model.dart';
import '../../../models/user_market_preferences_model.dart';

class FavouriteSelectionsDto {
  const FavouriteSelectionsDto({
    this.teamIds = const <String>{},
    this.competitionIds = const <String>{},
  });

  final Set<String> teamIds;
  final Set<String> competitionIds;
}

abstract interface class PreferencesGateway {
  Future<FavouriteSelectionsDto> readCachedFavourites({required String scope});

  Future<void> writeCachedFavourites({
    required String scope,
    required FavouriteSelectionsDto selections,
  });

  Future<FavouriteSelectionsDto> readRemoteFavourites(String userId);

  Future<void> setRemoteTeamFavourite({
    required String userId,
    required String teamId,
    required bool enabled,
  });

  Future<void> setRemoteCompetitionFavourite({
    required String userId,
    required String competitionId,
    required bool enabled,
  });

  Future<AccountDeletionRequestModel?> getAccountDeletionRequest(String userId);

  Future<AccountDeletionRequestModel> submitAccountDeletionRequest({
    required String userId,
    required String reason,
    String? feedback,
  });

  Future<void> cancelAccountDeletionRequest(String userId);

  Future<PrivacySettingsModel> getPrivacySettings(String userId);

  Future<void> savePrivacySettings(
    String userId,
    PrivacySettingsModel settings,
  );

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

  Future<UserMarketPreferences> getCachedMarketPreferences();

  Future<UserMarketPreferences> getUserMarketPreferences();

  Future<void> saveUserMarketPreferences(UserMarketPreferences preferences);

  Future<void> syncCachedMarketPreferencesIfAuthenticated();
}

@LazySingleton(as: PreferencesGateway)
class SupabasePreferencesGateway implements PreferencesGateway {
  SupabasePreferencesGateway(this._cache, this._connection);

  static const _marketPrefsKey = 'preferences.market';
  static const _privacyPrefix = 'preferences.privacy.';
  static const _deletionPrefix = 'preferences.account_deletion.';
  static const _notificationPrefsPrefix = 'preferences.notifications.';
  static const _notificationLogPrefix = 'preferences.notification_log.';
  static const _matchAlertsPrefix = 'preferences.match_alerts.';
  static const _deviceTokensPrefix = 'preferences.device_tokens.';
  static const _teamIdsPrefix = 'preferences.favourites.teams.';
  static const _competitionIdsPrefix = 'preferences.favourites.competitions.';

  final CacheService _cache;
  final SupabaseConnection _connection;

  @override
  Future<FavouriteSelectionsDto> readCachedFavourites({
    required String scope,
  }) async {
    final teamIds = await _cache.getStringList('$_teamIdsPrefix$scope');
    final competitionIds = await _cache.getStringList(
      '$_competitionIdsPrefix$scope',
    );
    return FavouriteSelectionsDto(
      teamIds: teamIds.toSet(),
      competitionIds: competitionIds.toSet(),
    );
  }

  @override
  Future<void> writeCachedFavourites({
    required String scope,
    required FavouriteSelectionsDto selections,
  }) async {
    final teamIds = selections.teamIds.toList()..sort();
    final competitionIds = selections.competitionIds.toList()..sort();
    await _cache.setStringList('$_teamIdsPrefix$scope', teamIds);
    await _cache.setStringList(
      '$_competitionIdsPrefix$scope',
      competitionIds,
    );
  }

  @override
  Future<FavouriteSelectionsDto> readRemoteFavourites(String userId) async {
    final fallback = await readCachedFavourites(scope: 'user_$userId');
    final client = _connection.client;
    if (client == null) return fallback;

    try {
      final teamRows = await client
          .from('user_followed_teams')
          .select('team_id')
          .eq('user_id', userId);
      final competitionRows = await client
          .from('user_followed_competitions')
          .select('competition_id')
          .eq('user_id', userId);

      final teamIds = (teamRows as List)
          .whereType<Map>()
          .map((row) => row['team_id']?.toString())
          .whereType<String>()
          .toSet();
      final competitionIds = (competitionRows as List)
          .whereType<Map>()
          .map((row) => row['competition_id']?.toString())
          .whereType<String>()
          .toSet();

      if (teamIds.isEmpty && competitionIds.isEmpty) {
        return fallback;
      }

      return FavouriteSelectionsDto(
        teamIds: teamIds,
        competitionIds: competitionIds,
      );
    } catch (error) {
      AppLogger.d('Failed to load remote favourites: $error');
      return fallback;
    }
  }

  @override
  Future<void> setRemoteTeamFavourite({
    required String userId,
    required String teamId,
    required bool enabled,
  }) async {
    final cached = await readCachedFavourites(scope: 'user_$userId');
    final nextTeamIds = Set<String>.from(cached.teamIds);
    if (enabled) {
      nextTeamIds.add(teamId);
    } else {
      nextTeamIds.remove(teamId);
    }

    await writeCachedFavourites(
      scope: 'user_$userId',
      selections: FavouriteSelectionsDto(
        teamIds: nextTeamIds,
        competitionIds: cached.competitionIds,
      ),
    );

    final client = _connection.client;
    if (client == null) return;

    try {
      if (enabled) {
        await client.from('user_followed_teams').upsert(
          {'user_id': userId, 'team_id': teamId},
          onConflict: 'user_id,team_id',
        );
      } else {
        await client
            .from('user_followed_teams')
            .delete()
            .eq('user_id', userId)
            .eq('team_id', teamId);
      }
    } catch (error) {
      AppLogger.d('Failed to sync followed team: $error');
    }
  }

  @override
  Future<void> setRemoteCompetitionFavourite({
    required String userId,
    required String competitionId,
    required bool enabled,
  }) async {
    final cached = await readCachedFavourites(scope: 'user_$userId');
    final nextCompetitionIds = Set<String>.from(cached.competitionIds);
    if (enabled) {
      nextCompetitionIds.add(competitionId);
    } else {
      nextCompetitionIds.remove(competitionId);
    }

    await writeCachedFavourites(
      scope: 'user_$userId',
      selections: FavouriteSelectionsDto(
        teamIds: cached.teamIds,
        competitionIds: nextCompetitionIds,
      ),
    );

    final client = _connection.client;
    if (client == null) return;

    try {
      if (enabled) {
        await client.from('user_followed_competitions').upsert(
          {'user_id': userId, 'competition_id': competitionId},
          onConflict: 'user_id,competition_id',
        );
      } else {
        await client
            .from('user_followed_competitions')
            .delete()
            .eq('user_id', userId)
            .eq('competition_id', competitionId);
      }
    } catch (error) {
      AppLogger.d('Failed to sync followed competition: $error');
    }
  }

  @override
  Future<AccountDeletionRequestModel?> getAccountDeletionRequest(
    String userId,
  ) async {
    final cached = await _cachedDeletionRequest(userId);
    final client = _connection.client;
    if (client == null) return cached;

    try {
      final row = await client
          .from('account_deletion_requests')
          .select()
          .eq('user_id', userId)
          .order('requested_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return cached;

      final request = AccountDeletionRequestModel.fromJson(
        Map<String, dynamic>.from(row),
      );
      await _cacheDeletionRequest(userId, request);
      return request;
    } catch (error) {
      AppLogger.d('Failed to load account deletion request: $error');
      return cached;
    }
  }

  @override
  Future<AccountDeletionRequestModel> submitAccountDeletionRequest({
    required String userId,
    required String reason,
    String? feedback,
  }) async {
    final client = _connection.client;
    if (client == null) {
      final request = AccountDeletionRequestModel(
        id: 'delete_${DateTime.now().millisecondsSinceEpoch}',
        status: 'pending',
        requestedAt: DateTime.now(),
        reason: reason,
        contactEmail: feedback,
      );
      await _cacheDeletionRequest(userId, request);
      return request;
    }

    try {
      final row = await client
          .from('account_deletion_requests')
          .insert({
            'user_id': userId,
            'reason': reason,
            'contact_email': feedback,
            'status': 'pending',
          })
          .select()
          .single();
      final request = AccountDeletionRequestModel.fromJson(
        Map<String, dynamic>.from(row),
      );
      await _cacheDeletionRequest(userId, request);
      return request;
    } catch (error) {
      AppLogger.d('Failed to create account deletion request: $error');
      final request = AccountDeletionRequestModel(
        id: 'delete_${DateTime.now().millisecondsSinceEpoch}',
        status: 'pending',
        requestedAt: DateTime.now(),
        reason: reason,
        contactEmail: feedback,
      );
      await _cacheDeletionRequest(userId, request);
      return request;
    }
  }

  @override
  Future<void> cancelAccountDeletionRequest(String userId) async {
    final client = _connection.client;
    if (client != null) {
      try {
        await client
            .from('account_deletion_requests')
            .update({
              'status': 'cancelled',
              'processed_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('user_id', userId)
            .eq('status', 'pending');
      } catch (error) {
        AppLogger.d('Failed to cancel account deletion request: $error');
      }
    }

    final existing = await getAccountDeletionRequest(userId);
    if (existing == null) return;

    await _cacheDeletionRequest(
      userId,
      AccountDeletionRequestModel(
        id: existing.id,
        status: 'cancelled',
        requestedAt: existing.requestedAt,
        reason: existing.reason,
        contactEmail: existing.contactEmail,
        resolutionNotes: existing.resolutionNotes,
        processedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<PrivacySettingsModel> getPrivacySettings(String userId) async {
    final cached = await _cachedPrivacySettings(userId);
    final client = _connection.client;
    if (client == null) return cached ?? PrivacySettingsModel.defaults;

    try {
      final row = await client
          .from('profiles')
          .select('show_name_on_leaderboards, allow_fan_discovery')
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return cached ?? PrivacySettingsModel.defaults;

      final settings = PrivacySettingsModel(
        showNameOnLeaderboards:
            row['show_name_on_leaderboards'] as bool? ?? false,
        allowFanDiscovery: row['allow_fan_discovery'] as bool? ?? false,
      );
      await _cachePrivacySettings(userId, settings);
      return settings;
    } catch (error) {
      AppLogger.d('Failed to load privacy settings: $error');
      return cached ?? PrivacySettingsModel.defaults;
    }
  }

  @override
  Future<void> savePrivacySettings(
    String userId,
    PrivacySettingsModel settings,
  ) async {
    await _cachePrivacySettings(userId, settings);

    final client = _connection.client;
    if (client == null) return;

    try {
      await client
          .from('profiles')
          .update({
            'show_name_on_leaderboards': settings.showNameOnLeaderboards,
            'allow_fan_discovery': settings.allowFanDiscovery,
          })
          .eq('id', userId);
    } catch (error) {
      AppLogger.d('Failed to save privacy settings: $error');
    }
  }

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
      await client.from('notification_preferences').upsert(
        {
          'user_id': userId,
          'goal_alerts': preferences.goalAlerts,
          'pool_updates': preferences.poolUpdates,
          'daily_challenge': preferences.dailyChallenge,
          'wallet_activity': preferences.walletActivity,
          'community_news': preferences.communityNews,
          'marketing': preferences.marketing,
        },
        onConflict: 'user_id',
      );
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
    final key = '$_deviceTokensPrefix$scopedUser';
    final next = {...await _cache.getStringList(key), '$platform:$token'}
      ..removeWhere((value) => value.trim().isEmpty);
    await _cache.setStringList(key, next.toList()..sort());

    final client = _connection.client;
    if (client == null || userId == null) return;

    try {
      await client.from('device_tokens').upsert(
        {
          'user_id': userId,
          'token': token,
          'platform': platform,
          'is_active': true,
        },
        onConflict: 'user_id,token',
      );
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
    final key = '$_deviceTokensPrefix$scopedUser';
    final next = (await _cache.getStringList(key))
        .where((value) => !value.endsWith(':$token'))
        .toList(growable: false);
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
    final key = '$_matchAlertsPrefix$scopedUser';
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
    final existing = await _cache.getStringList('$_matchAlertsPrefix$scopedUser');
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
    if (client == null) return _fallbackUserStats;

    try {
      final row = await client
          .from('user_status')
          .select(
            'prediction_streak, longest_streak, total_predictions, total_pools_entered, total_pools_won, total_fet_earned, total_fet_spent',
          )
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return _fallbackUserStats;
      return UserStats.fromJson(Map<String, dynamic>.from(row));
    } catch (error) {
      AppLogger.d('Failed to load user stats: $error');
      return _fallbackUserStats;
    }
  }

  @override
  Future<UserMarketPreferences> getCachedMarketPreferences() async {
    final row = await _cache.getJsonMap(
      _marketPrefsKey,
      debugLabel: 'market preferences',
    );
    if (row == null) return UserMarketPreferences.defaults;
    return UserMarketPreferences.fromJson(row);
  }

  @override
  Future<UserMarketPreferences> getUserMarketPreferences() async {
    final cached = await getCachedMarketPreferences();
    final userId = _connection.currentUser?.id;
    final client = _connection.client;
    if (client == null || userId == null) return cached;

    try {
      final row = await client
          .from('user_market_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return cached;
      final preferences = UserMarketPreferences.fromJson(
        Map<String, dynamic>.from(row),
      );
      await _cache.setJson(_marketPrefsKey, preferences.toJson());
      return preferences;
    } catch (error) {
      AppLogger.d('Failed to load market preferences: $error');
      return cached;
    }
  }

  @override
  Future<void> saveUserMarketPreferences(
    UserMarketPreferences preferences,
  ) async {
    await _cache.setJson(_marketPrefsKey, preferences.toJson());

    final userId = _connection.currentUser?.id;
    final client = _connection.client;
    if (client == null || userId == null) return;

    try {
      await client.from('user_market_preferences').upsert(
        {'user_id': userId, ...preferences.toJson()},
        onConflict: 'user_id',
      );
    } catch (error) {
      AppLogger.d('Failed to save market preferences: $error');
    }
  }

  @override
  Future<void> syncCachedMarketPreferencesIfAuthenticated() async {
    final userId = _connection.currentUser?.id;
    final client = _connection.client;
    if (client == null || userId == null) return;

    final cached = await getCachedMarketPreferences();
    if (!cached.hasCustomSelections) return;

    try {
      await client.from('user_market_preferences').upsert(
        {'user_id': userId, ...cached.toJson()},
        onConflict: 'user_id',
      );
    } catch (error) {
      AppLogger.d('Failed to sync cached market preferences: $error');
    }
  }

  Future<AccountDeletionRequestModel?> _cachedDeletionRequest(String userId) async {
    final row = await _cache.getJsonMap(
      '$_deletionPrefix$userId',
      debugLabel: 'account deletion',
    );
    return row == null ? null : AccountDeletionRequestModel.fromJson(row);
  }

  Future<void> _cacheDeletionRequest(
    String userId,
    AccountDeletionRequestModel request,
  ) {
    return _cache.setJson('$_deletionPrefix$userId', _accountDeletionToJson(request));
  }

  Future<PrivacySettingsModel?> _cachedPrivacySettings(String userId) async {
    final row = await _cache.getJsonMap(
      '$_privacyPrefix$userId',
      debugLabel: 'privacy settings',
    );
    if (row == null) return null;
    return PrivacySettingsModel(
      showNameOnLeaderboards: row['show_name_on_leaderboards'] as bool? ?? false,
      allowFanDiscovery: row['allow_fan_discovery'] as bool? ?? false,
    );
  }

  Future<void> _cachePrivacySettings(
    String userId,
    PrivacySettingsModel settings,
  ) {
    return _cache.setJson('$_privacyPrefix$userId', {
      'show_name_on_leaderboards': settings.showNameOnLeaderboards,
      'allow_fan_discovery': settings.allowFanDiscovery,
    });
  }

  Future<NotificationPreferences?> _cachedNotificationPreferences(
    String userId,
  ) async {
    final row = await _cache.getJsonMap(
      '$_notificationPrefsPrefix$userId',
      debugLabel: 'notification preferences',
    );
    return row == null ? null : NotificationPreferences.fromJson(row);
  }

  Future<void> _cacheNotificationPreferences(
    String userId,
    NotificationPreferences preferences,
  ) {
    return _cache.setJson(
      '$_notificationPrefsPrefix$userId',
      preferences.toJson(),
    );
  }

  Future<List<NotificationItem>> _cachedNotificationLog(String userId) async {
    final rows = await _cache.getJsonList(
      '$_notificationLogPrefix$userId',
      debugLabel: 'notification log',
    );
    return rows.map(NotificationItem.fromJson).toList(growable: false);
  }

  Future<void> _cacheNotificationLog(
    String userId,
    List<NotificationItem> notifications,
  ) {
    return _cache.setJson(
      '$_notificationLogPrefix$userId',
      notifications.map((item) => item.toJson()).toList(growable: false),
    );
  }
}

Map<String, dynamic> _accountDeletionToJson(
  AccountDeletionRequestModel request,
) {
  return {
    'id': request.id,
    'status': request.status,
    'requested_at': request.requestedAt.toIso8601String(),
    'reason': request.reason,
    'contact_email': request.contactEmail,
    'resolution_notes': request.resolutionNotes,
    'processed_at': request.processedAt?.toIso8601String(),
  };
}

const _fallbackUserStats = UserStats(
  predictionStreak: 3,
  longestStreak: 7,
  totalPredictions: 24,
  totalPoolsEntered: 9,
  totalPoolsWon: 2,
  totalFetEarned: 420,
  totalFetSpent: 180,
);

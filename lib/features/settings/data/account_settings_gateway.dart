import 'package:injectable/injectable.dart';

import '../../../core/cache/cache_service.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/account_deletion_request_model.dart';
import '../../../models/privacy_settings_model.dart';
import 'preferences_gateway_shared.dart';

abstract interface class AccountSettingsGateway {
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
}

@LazySingleton(as: AccountSettingsGateway)
class SupabaseAccountSettingsGateway implements AccountSettingsGateway {
  SupabaseAccountSettingsGateway(this._cache, this._connection);

  final CacheService _cache;
  final SupabaseConnection _connection;

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

  Future<AccountDeletionRequestModel?> _cachedDeletionRequest(
    String userId,
  ) async {
    final row = await _cache.getJsonMap(
      '$deletionRequestCachePrefix$userId',
      debugLabel: 'account deletion',
    );
    return row == null ? null : AccountDeletionRequestModel.fromJson(row);
  }

  Future<void> _cacheDeletionRequest(
    String userId,
    AccountDeletionRequestModel request,
  ) {
    return _cache.setJson(
      '$deletionRequestCachePrefix$userId',
      accountDeletionToJson(request),
    );
  }

  Future<PrivacySettingsModel?> _cachedPrivacySettings(String userId) async {
    final row = await _cache.getJsonMap(
      '$privacySettingsCachePrefix$userId',
      debugLabel: 'privacy settings',
    );
    if (row == null) return null;
    return PrivacySettingsModel(
      showNameOnLeaderboards:
          row['show_name_on_leaderboards'] as bool? ?? false,
      allowFanDiscovery: row['allow_fan_discovery'] as bool? ?? false,
    );
  }

  Future<void> _cachePrivacySettings(
    String userId,
    PrivacySettingsModel settings,
  ) {
    return _cache.setJson('$privacySettingsCachePrefix$userId', {
      'show_name_on_leaderboards': settings.showNameOnLeaderboards,
      'allow_fan_discovery': settings.allowFanDiscovery,
    });
  }
}

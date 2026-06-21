import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/cache/shared_preferences_cache_service.dart';
import '../core/supabase/supabase_connection.dart';
import '../features/settings/data/account_settings_gateway.dart';
import '../models/auth_and_user/account_data_request_model.dart';

/// Static account data request service for privacy support flows.
/// Requests are support-reviewed and do not expose raw data immediately.
class AccountDataRequestService {
  const AccountDataRequestService._();

  static final SupabaseConnection _connection = SupabaseConnectionImpl();

  static String? get _userId => _connection.currentUser?.id;

  static AccountSettingsGateway? _gateway;
  static AccountSettingsGateway get _accountSettings =>
      _gateway ??= SupabaseAccountSettingsGateway(
        SharedPreferencesCacheService.global,
        _connection,
      );

  static Future<AccountDataRequestModel?> getLatestRequest() async {
    final userId = _userId;
    if (userId == null) return null;
    return _accountSettings.getAccountDataRequest(userId);
  }

  static Future<AccountDataRequestModel> createRequest({
    required String reason,
    String? contactEmail,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw const AuthException('Sign in to request account data access.');
    }

    final trimmedReason = reason.trim();
    if (trimmedReason.length < 10) {
      throw ArgumentError(
        'Add a short reason so support can verify the request safely.',
      );
    }

    return _accountSettings.submitAccountDataRequest(
      userId: userId,
      reason: trimmedReason,
      contactEmail: contactEmail,
    );
  }

  static Future<AccountDataRequestModel> cancelRequest(String requestId) async {
    final userId = _userId;
    if (userId == null) {
      throw const AuthException('Sign in to manage account data requests.');
    }

    await _accountSettings.cancelAccountDataRequest(userId);
    final latest = await _accountSettings.getAccountDataRequest(userId);
    if (latest == null) {
      throw const AuthException('Data request could not be loaded.');
    }
    return latest;
  }
}

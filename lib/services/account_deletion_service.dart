import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/cache/shared_preferences_cache_service.dart';
import '../core/supabase/supabase_connection.dart';
import '../features/settings/data/account_settings_gateway.dart';
import '../models/account_deletion_request_model.dart';

/// Static account deletion service.
/// Uses Supabase directly for auth and creates its own gateway instance,
/// since it's called from non-Riverpod contexts.
class AccountDeletionService {
  const AccountDeletionService._();

  static final SupabaseConnection _connection = SupabaseConnectionImpl();

  static String? get _userId => _connection.currentUser?.id;

  static AccountSettingsGateway? _gateway;
  static AccountSettingsGateway get _accountSettings =>
      _gateway ??= SupabaseAccountSettingsGateway(
        SharedPreferencesCacheService.global,
        _connection,
      );

  static Future<AccountDeletionRequestModel?> getLatestRequest() async {
    final userId = _userId;
    if (userId == null) return null;
    return _accountSettings.getAccountDeletionRequest(userId);
  }

  static Future<AccountDeletionRequestModel> createRequest({
    required String reason,
    String? contactEmail,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw const AuthException('Sign in to request account deletion.');
    }

    final trimmedReason = reason.trim();
    if (trimmedReason.length < 10) {
      throw ArgumentError(
        'Add a short reason so support can verify the request safely.',
      );
    }

    return _accountSettings.submitAccountDeletionRequest(
      userId: userId,
      reason: trimmedReason,
      feedback: contactEmail,
    );
  }

  static Future<AccountDeletionRequestModel> cancelRequest(
    String requestId,
  ) async {
    final userId = _userId;
    if (userId == null) {
      throw const AuthException('Sign in to manage deletion requests.');
    }

    await _accountSettings.cancelAccountDeletionRequest(userId);
    final latest = await _accountSettings.getAccountDeletionRequest(userId);
    if (latest == null) {
      throw const AuthException('Deletion request could not be loaded.');
    }
    return latest;
  }
}

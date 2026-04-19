import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/di/injection.dart';
import '../features/settings/data/preferences_gateway.dart';
import '../models/account_deletion_request_model.dart';
import 'auth_service.dart';

class AccountDeletionService {
  const AccountDeletionService._();

  static Future<AccountDeletionRequestModel?> getLatestRequest() async {
    final userId = getIt<AuthService>().currentUser?.id;
    if (userId == null) return null;
    return getIt<AccountSettingsGateway>().getAccountDeletionRequest(userId);
  }

  static Future<AccountDeletionRequestModel> createRequest({
    required String reason,
    String? contactEmail,
  }) async {
    final userId = getIt<AuthService>().currentUser?.id;
    if (userId == null) {
      throw const AuthException('Sign in to request account deletion.');
    }

    final trimmedReason = reason.trim();
    if (trimmedReason.length < 10) {
      throw ArgumentError(
        'Add a short reason so support can verify the request safely.',
      );
    }

    return getIt<AccountSettingsGateway>().submitAccountDeletionRequest(
      userId: userId,
      reason: trimmedReason,
      feedback: contactEmail,
    );
  }

  static Future<AccountDeletionRequestModel> cancelRequest(
    String requestId,
  ) async {
    final userId = getIt<AuthService>().currentUser?.id;
    if (userId == null) {
      throw const AuthException('Sign in to manage deletion requests.');
    }

    await getIt<AccountSettingsGateway>().cancelAccountDeletionRequest(userId);
    final latest = await getIt<AccountSettingsGateway>()
        .getAccountDeletionRequest(userId);
    if (latest == null) {
      throw const AuthException('Deletion request could not be loaded.');
    }
    return latest;
  }
}

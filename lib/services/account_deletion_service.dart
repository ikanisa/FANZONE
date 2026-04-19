import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart' show supabaseInitialized;
import '../models/account_deletion_request_model.dart';

class AccountDeletionService {
  const AccountDeletionService._();

  static Future<AccountDeletionRequestModel?> getLatestRequest() async {
    if (!supabaseInitialized) return null;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await client
        .from('account_deletion_requests')
        .select(
          'id, status, reason, contact_email, requested_at, processed_at, resolution_notes',
        )
        .eq('user_id', userId)
        .order('requested_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (data == null) return null;
    return AccountDeletionRequestModel.fromJson(data);
  }

  static Future<AccountDeletionRequestModel> createRequest({
    required String reason,
    String? contactEmail,
  }) async {
    if (!supabaseInitialized) {
      throw const AuthException(
        'Server not available. Please try again later.',
      );
    }

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Sign in to request account deletion.');
    }

    final trimmedReason = reason.trim();
    if (trimmedReason.length < 10) {
      throw ArgumentError(
        'Add a short reason so support can verify the request safely.',
      );
    }

    final response = await client
        .from('account_deletion_requests')
        .insert({
          'user_id': userId,
          'reason': trimmedReason,
          'contact_email': contactEmail?.trim().isEmpty ?? true
              ? null
              : contactEmail!.trim(),
        })
        .select(
          'id, status, reason, contact_email, requested_at, processed_at, resolution_notes',
        )
        .single();

    return AccountDeletionRequestModel.fromJson(response);
  }

  static Future<AccountDeletionRequestModel> cancelRequest(
    String requestId,
  ) async {
    if (!supabaseInitialized) {
      throw const AuthException(
        'Server not available. Please try again later.',
      );
    }

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Sign in to manage deletion requests.');
    }

    final response = await client
        .from('account_deletion_requests')
        .update({
          'status': 'cancelled',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', requestId)
        .eq('user_id', userId)
        .eq('status', 'pending')
        .select(
          'id, status, reason, contact_email, requested_at, processed_at, resolution_notes',
        )
        .single();

    return AccountDeletionRequestModel.fromJson(response);
  }
}

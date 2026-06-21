import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/app_config.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/hospitality/venue_support_request_model.dart';

abstract interface class VenueSupportGateway {
  Future<VenueSupportRequestModel> createVenueSupportRequest({
    required String venueId,
    required String topic,
    required String message,
    String? orderId,
    String? tableNumber,
  });
}

class SupabaseVenueSupportGateway implements VenueSupportGateway {
  SupabaseVenueSupportGateway(this._connection);

  final SupabaseConnection _connection;

  @override
  Future<VenueSupportRequestModel> createVenueSupportRequest({
    required String venueId,
    required String topic,
    required String message,
    String? orderId,
    String? tableNumber,
  }) async {
    _assertReviewMutationAllowed('Venue support requests');
    final client = _connection.client;
    final userId = _connection.currentUser?.id;
    if (client == null || userId == null) {
      throw const AuthException('Sign in to contact venue support.');
    }

    try {
      final row = await client
          .from('venue_support_requests')
          .insert({
            'venue_id': venueId,
            'user_id': userId,
            'topic': topic.trim(),
            'message': message.trim(),
            if (orderId?.trim().isNotEmpty ?? false)
              'order_id': orderId!.trim(),
            if (tableNumber?.trim().isNotEmpty ?? false)
              'table_number': tableNumber!.trim(),
            'status': 'open',
          })
          .select()
          .single();

      return VenueSupportRequestModel.fromJson(Map<String, dynamic>.from(row));
    } catch (error) {
      AppLogger.w('Failed to create venue support request: $error');
      rethrow;
    }
  }

  void _assertReviewMutationAllowed(String action) {
    if (!AppConfig.isReviewMode) return;
    throw StateError(
      '$action are disabled in the FANZONE review PWA. Use staging-safe test data for browser review.',
    );
  }
}

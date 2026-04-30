import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/hospitality/bell_request_model.dart';

/// Gateway for bell request CRUD and realtime subscriptions.
abstract interface class BellGateway {
  /// Ring the bell — create a new bell request.
  Future<BellRequestModel> ringBell({
    required String venueId,
    required String tableId,
    String? message,
  });

  /// Acknowledge a bell request (venue staff action).
  Future<void> acknowledgeBell(String bellId);

  /// List active (unacknowledged) bell requests for a venue.
  Future<List<BellRequestModel>> getActiveBells(String venueId, {int limit});

  /// Subscribe to realtime bell requests for a venue.
  RealtimeChannel subscribeToVenueBells(
    String venueId,
    void Function(BellRequestModel bell) onBell,
  );
}

class SupabaseBellGateway implements BellGateway {
  SupabaseBellGateway(this._connection);

  final SupabaseConnection _connection;

  @override
  Future<BellRequestModel> ringBell({
    required String venueId,
    required String tableId,
    String? message,
  }) async {
    final client = _connection.client;
    if (client == null) {
      throw StateError('Cannot ring bell: no connection');
    }

    final row = await client
        .from('bell_requests')
        .insert({
          'venue_id': venueId,
          'table_id': tableId,
          'message': message,
        })
        .select()
        .single();

    return BellRequestModel.fromJson(row);
  }

  @override
  Future<void> acknowledgeBell(String bellId) async {
    final client = _connection.client;
    if (client == null) {
      throw StateError('Cannot acknowledge bell: no connection');
    }

    await client.from('bell_requests').update({
      'acknowledged_at': DateTime.now().toUtc().toIso8601String(),
      'acknowledged_by': client.auth.currentUser?.id,
    }).eq('id', bellId);
  }

  @override
  Future<List<BellRequestModel>> getActiveBells(
    String venueId, {
    int limit = 50,
  }) async {
    final client = _connection.client;
    if (client == null) return const [];

    try {
      final rows = await client
          .from('bell_requests')
          .select()
          .eq('venue_id', venueId)
          .isFilter('acknowledged_at', null)
          .order('created_at', ascending: false)
          .limit(limit);

      return (rows as List)
          .whereType<Map>()
          .map(
            (row) =>
                BellRequestModel.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    } catch (error) {
      AppLogger.w('Failed to load active bells: $error');
      return const [];
    }
  }

  @override
  RealtimeChannel subscribeToVenueBells(
    String venueId,
    void Function(BellRequestModel bell) onBell,
  ) {
    final client = _connection.client!;
    return client
        .channel('venue_bells_$venueId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'bell_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'venue_id',
            value: venueId,
          ),
          callback: (payload) {
            try {
              final data = payload.newRecord;
              if (data.isNotEmpty) {
                onBell(BellRequestModel.fromJson(data));
              }
            } catch (e) {
              AppLogger.w('Error parsing realtime bell: $e');
            }
          },
        )
        .subscribe();
  }
}

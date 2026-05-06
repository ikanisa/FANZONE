import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/hospitality/bell_request_model.dart';

abstract interface class BellGateway {
  Future<BellRequestModel> ringBell({
    required String venueId,
    required String tableId,
    String? message,
  });

  Future<void> acknowledgeBell(String bellId);

  Future<List<BellRequestModel>> getActiveBells(String venueId, {int limit});

  RealtimeChannel subscribeToVenueBells(
    String venueId,
    void Function(BellRequestModel bell) onBell,
  );
}

class SupabaseBellGateway implements BellGateway {
  SupabaseBellGateway(this._connection);

  final SupabaseConnection _connection;

  Map<String, String>? get _authHeaders {
    final token = _connection.currentSession?.accessToken;
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }

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

    final response = await client.functions.invoke(
      'ring_bell',
      headers: _authHeaders,
      body: {
        'venue_id': venueId,
        'table_id': tableId,
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim(),
      },
    );

    final data = Map<String, dynamic>.from(
      response.data as Map<String, dynamic>? ?? const {},
    );
    if (data['success'] != true || data['bell'] is! Map) {
      throw StateError(data['error']?.toString() ?? 'Could not ring staff');
    }

    return BellRequestModel.fromJson(
      Map<String, dynamic>.from(data['bell'] as Map),
    );
  }

  @override
  Future<void> acknowledgeBell(String bellId) async {
    final client = _connection.client;
    if (client == null) {
      throw StateError('Cannot acknowledge bell: no connection');
    }

    await client
        .from('bell_requests')
        .update({
          'acknowledged_at': DateTime.now().toUtc().toIso8601String(),
          'acknowledged_by': client.auth.currentUser?.id,
        })
        .eq('id', bellId);
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
            (row) => BellRequestModel.fromJson(Map<String, dynamic>.from(row)),
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
    final client = _connection.client;
    if (client == null) {
      throw StateError('Cannot subscribe to bells: no connection');
    }

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
            } catch (error) {
              AppLogger.w('Error parsing realtime bell: $error');
            }
          },
        )
        .subscribe();
  }
}

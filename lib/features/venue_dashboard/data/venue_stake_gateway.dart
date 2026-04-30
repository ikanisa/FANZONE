import 'dart:async';
import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/hospitality/venue_match_stake_model.dart';
import '../../../services/app_telemetry.dart';

abstract interface class VenueStakeGateway {
  Future<List<VenueMatchStakeModel>> getStakesForVenue(String venueId);
  Future<VenueMatchStakeModel?> getActiveStakeForMatch(
    String venueId,
    String matchId,
  );
  Future<void> createStake({
    required String venueId,
    required String matchId,
    required int entryFeeFet,
  });
  Future<void> joinStake(String stakeId);
}

class SupabaseVenueStakeGateway implements VenueStakeGateway {
  SupabaseVenueStakeGateway(this._connection);

  final SupabaseConnection _connection;

  @override
  Future<List<VenueMatchStakeModel>> getStakesForVenue(String venueId) async {
    final client = _connection.client;
    if (client == null) return [];

    try {
      final response = await client
          .from('venue_match_stakes')
          .select()
          .eq('venue_id', venueId)
          .order('created_at');

      return (response as List)
          .map((json) => VenueMatchStakeModel.fromJson(json))
          .toList();
    } catch (e) {
      AppLogger.w('Failed to fetch venue stakes: $e');
      return [];
    }
  }

  @override
  Future<VenueMatchStakeModel?> getActiveStakeForMatch(
    String venueId,
    String matchId,
  ) async {
    final client = _connection.client;
    if (client == null) return null;

    try {
      final response = await client
          .from('venue_match_stakes')
          .select()
          .eq('venue_id', venueId)
          .eq('match_id', matchId)
          .maybeSingle();

      if (response == null) return null;
      return VenueMatchStakeModel.fromJson(response);
    } catch (e) {
      AppLogger.w('Failed to fetch match stake: $e');
      return null;
    }
  }

  @override
  Future<void> createStake({
    required String venueId,
    required String matchId,
    required int entryFeeFet,
  }) async {
    final client = _connection.client;
    if (client == null) return;

    await client.from('venue_match_stakes').insert({
      'venue_id': venueId,
      'match_id': matchId,
      'entry_fee_fet': entryFeeFet,
      'status': 'open',
    });
  }

  @override
  Future<void> joinStake(String stakeId) async {
    final client = _connection.client;
    if (client == null) return;

    await client.rpc(
      'join_venue_match_stake',
      params: {'p_stake_id': stakeId},
    );

    // Track telemetry
    unawaited(AppTelemetry.trackEvent('pool_joined', metadata: {
      'stake_id': stakeId,
    }));
  }
}

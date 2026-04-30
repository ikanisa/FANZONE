import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/hospitality/venue_match_stake_model.dart';
import '../../../core/di/gateway_providers.dart';

final venueStakesProvider =
    FutureProvider.family.autoDispose<List<VenueMatchStakeModel>, String>((
  ref,
  venueId,
) async {
  final gateway = ref.watch(venueStakeGatewayProvider);
  return gateway.getStakesForVenue(venueId);
});

final activeMatchStakeProvider = FutureProvider.family.autoDispose<
    VenueMatchStakeModel?,
    ({String venueId, String matchId})>((ref, arg) async {
  final gateway = ref.watch(venueStakeGatewayProvider);
  return gateway.getActiveStakeForMatch(arg.venueId, arg.matchId);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/gateway_providers.dart';
import '../../../models/hospitality/venue_model.dart';

final activeVenuesProvider = FutureProvider.autoDispose<List<VenueModel>>((
  ref,
) async {
  return ref.read(venueGatewayProvider).listActiveVenues(limit: 40);
});

final venueSearchProvider = FutureProvider.family
    .autoDispose<List<VenueModel>, String>((ref, rawQuery) async {
      final query = rawQuery.trim();
      if (query.isEmpty) {
        return ref.read(activeVenuesProvider.future);
      }
      return ref.read(venueGatewayProvider).searchVenues(query, limit: 24);
    });

final venueDetailByIdProvider = FutureProvider.family
    .autoDispose<VenueModel?, String>((ref, venueId) {
      return ref.read(venueGatewayProvider).getVenueById(venueId);
    });

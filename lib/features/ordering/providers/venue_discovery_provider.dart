import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/gateway_providers.dart';
import '../../../core/location/location_service.dart';
import '../../../models/hospitality/venue_model.dart';

const venueDiscoveryRadiusKm = 20.0;

final activeVenuesProvider = FutureProvider.autoDispose<List<VenueModel>>((
  ref,
) async {
  final location = ref.watch(locationAccessProvider).position;
  if (location == null) {
    return ref.read(venueGatewayProvider).listActiveVenues(limit: 40);
  }

  return ref
      .read(venueGatewayProvider)
      .listNearbyVenues(
        latitude: location.latitude,
        longitude: location.longitude,
        radiusKm: venueDiscoveryRadiusKm,
        limit: 40,
      );
});

final venueSearchProvider = FutureProvider.family
    .autoDispose<List<VenueModel>, String>((ref, rawQuery) async {
      final location = ref.watch(locationAccessProvider).position;
      final query = rawQuery.trim();
      if (query.isEmpty) {
        return ref.read(activeVenuesProvider.future);
      }

      if (location == null) {
        return ref.read(venueGatewayProvider).searchVenues(query, limit: 24);
      }

      return ref
          .read(venueGatewayProvider)
          .listNearbyVenues(
            latitude: location.latitude,
            longitude: location.longitude,
            radiusKm: venueDiscoveryRadiusKm,
            query: query,
            limit: 24,
          );
    });

final venueDetailByIdProvider = FutureProvider.family
    .autoDispose<VenueModel?, String>((ref, venueId) {
      return ref.read(venueGatewayProvider).getVenueById(venueId);
    });

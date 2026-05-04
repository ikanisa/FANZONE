import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fanzone/core/location/location_service.dart';
import 'package:fanzone/features/ordering/data/venue_gateway.dart';
import 'package:fanzone/models/hospitality/venue_model.dart';

void main() {
  group('LocationAccessController', () {
    test('stores granted foreground location for venue discovery', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = _FakeLocationService(
        permission: AppLocationPermissionStatus.granted,
        position: UserLocation(
          latitude: 35.8997,
          longitude: 14.5146,
          acquiredAt: DateTime(2026, 5, 4, 12),
        ),
      );

      final controller = LocationAccessController(service, prefs);
      final success = await controller.requestCurrentLocation();

      expect(success, isTrue);
      expect(
        controller.state.permissionStatus,
        AppLocationPermissionStatus.granted,
      );
      expect(controller.state.position?.latitude, 35.8997);
      expect(prefs.getDouble('venue_discovery_latitude'), 35.8997);
    });

    test('surfaces denied permission without storing a location', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = _FakeLocationService(
        permission: AppLocationPermissionStatus.denied,
      );

      final controller = LocationAccessController(service, prefs);
      final success = await controller.requestCurrentLocation();

      expect(success, isFalse);
      expect(
        controller.state.permissionStatus,
        AppLocationPermissionStatus.denied,
      );
      expect(controller.state.position, isNull);
      expect(controller.state.errorMessage, contains('denied'));
    });
  });

  group('VenueDistance', () {
    test('calculates venue distance from a foreground location', () {
      const venue = VenueModel(
        id: 'venue-1',
        name: 'Valletta Sports Bar',
        countryCode: CountryCode.mt,
        venueType: VenueType.bar,
        currencyCode: 'EUR',
        latitude: 35.8989,
        longitude: 14.5146,
      );

      final distance = venue.distanceKmFrom(35.8997, 14.5146);

      expect(distance, isNotNull);
      expect(distance!, lessThan(0.2));
    });

    test('returns null when a venue has no coordinates', () {
      const venue = VenueModel(
        id: 'venue-2',
        name: 'No Coordinates',
        countryCode: CountryCode.mt,
        venueType: VenueType.bar,
        currencyCode: 'EUR',
      );

      expect(venue.distanceKmFrom(35.8997, 14.5146), isNull);
    });
  });
}

class _FakeLocationService implements LocationService {
  _FakeLocationService({required this.permission, this.position});

  final AppLocationPermissionStatus permission;
  final UserLocation? position;

  @override
  Future<UserLocation> currentLocation() async {
    final resolved = position;
    if (resolved == null) throw StateError('No fake location configured');
    return resolved;
  }

  @override
  Future<AppLocationPermissionStatus> permissionStatus() async => permission;

  @override
  Future<AppLocationPermissionStatus> requestPermission() async => permission;
}

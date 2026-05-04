import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../di/gateway_providers.dart';

enum AppLocationPermissionStatus {
  unknown,
  serviceDisabled,
  denied,
  deniedForever,
  granted,
}

class UserLocation {
  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.acquiredAt,
  });

  final double latitude;
  final double longitude;
  final DateTime acquiredAt;

  bool get isFresh => DateTime.now().difference(acquiredAt).inHours < 12;
}

class LocationAccessState {
  const LocationAccessState({
    this.position,
    this.permissionStatus = AppLocationPermissionStatus.unknown,
    this.isLoading = false,
    this.errorMessage,
  });

  final UserLocation? position;
  final AppLocationPermissionStatus permissionStatus;
  final bool isLoading;
  final String? errorMessage;

  bool get hasLocation => position != null;

  bool get hasFreshLocation => position?.isFresh == true;

  LocationAccessState copyWith({
    UserLocation? position,
    bool clearPosition = false,
    AppLocationPermissionStatus? permissionStatus,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LocationAccessState(
      position: clearPosition ? null : position ?? this.position,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

abstract interface class LocationService {
  Future<AppLocationPermissionStatus> permissionStatus();

  Future<AppLocationPermissionStatus> requestPermission();

  Future<UserLocation> currentLocation();
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<AppLocationPermissionStatus> permissionStatus() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return AppLocationPermissionStatus.serviceDisabled;
    return _mapPermission(await Geolocator.checkPermission());
  }

  @override
  Future<AppLocationPermissionStatus> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return AppLocationPermissionStatus.serviceDisabled;

    final current = await Geolocator.checkPermission();
    if (current == LocationPermission.always ||
        current == LocationPermission.whileInUse) {
      return AppLocationPermissionStatus.granted;
    }

    final requested = await Geolocator.requestPermission();
    return _mapPermission(requested);
  }

  @override
  Future<UserLocation> currentLocation() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 12),
      ),
    );
    return UserLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      acquiredAt: DateTime.now(),
    );
  }

  AppLocationPermissionStatus _mapPermission(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return AppLocationPermissionStatus.granted;
      case LocationPermission.deniedForever:
        return AppLocationPermissionStatus.deniedForever;
      case LocationPermission.denied:
        return AppLocationPermissionStatus.denied;
      case LocationPermission.unableToDetermine:
        return AppLocationPermissionStatus.unknown;
    }
  }
}

final locationServiceProvider = Provider<LocationService>((ref) {
  return GeolocatorLocationService();
});

final locationAccessProvider =
    StateNotifierProvider<LocationAccessController, LocationAccessState>((ref) {
      return LocationAccessController(
        ref.watch(locationServiceProvider),
        ref.watch(sharedPreferencesProvider),
      );
    });

class LocationAccessController extends StateNotifier<LocationAccessState> {
  LocationAccessController(this._service, this._prefs)
    : super(_stateFromCache(_prefs));

  static const _latKey = 'venue_discovery_latitude';
  static const _lngKey = 'venue_discovery_longitude';
  static const _timeKey = 'venue_discovery_location_acquired_at';

  final LocationService _service;
  final SharedPreferences _prefs;

  Future<void> refreshPermissionStatus() async {
    final status = await _service.permissionStatus();
    state = state.copyWith(permissionStatus: status, clearError: true);
  }

  Future<bool> requestCurrentLocation() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final permission = await _service.requestPermission();
      if (permission != AppLocationPermissionStatus.granted) {
        state = state.copyWith(
          permissionStatus: permission,
          isLoading: false,
          errorMessage: _messageForPermission(permission),
        );
        return false;
      }

      final position = await _service.currentLocation();
      await _cacheLocation(position);
      state = state.copyWith(
        position: position,
        permissionStatus: AppLocationPermissionStatus.granted,
        isLoading: false,
        clearError: true,
      );
      return true;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not read your location. Please try again.',
      );
      return false;
    }
  }

  Future<void> clearLocation() async {
    await _prefs.remove(_latKey);
    await _prefs.remove(_lngKey);
    await _prefs.remove(_timeKey);
    state = state.copyWith(clearPosition: true, clearError: true);
  }

  Future<void> _cacheLocation(UserLocation position) async {
    await _prefs.setDouble(_latKey, position.latitude);
    await _prefs.setDouble(_lngKey, position.longitude);
    await _prefs.setString(_timeKey, position.acquiredAt.toIso8601String());
  }

  static LocationAccessState _stateFromCache(SharedPreferences prefs) {
    final latitude = prefs.getDouble(_latKey);
    final longitude = prefs.getDouble(_lngKey);
    final acquiredAt = DateTime.tryParse(prefs.getString(_timeKey) ?? '');
    if (latitude == null || longitude == null || acquiredAt == null) {
      return const LocationAccessState();
    }

    final position = UserLocation(
      latitude: latitude,
      longitude: longitude,
      acquiredAt: acquiredAt,
    );
    return LocationAccessState(
      position: position.isFresh ? position : null,
      permissionStatus: position.isFresh
          ? AppLocationPermissionStatus.granted
          : AppLocationPermissionStatus.unknown,
    );
  }

  String _messageForPermission(AppLocationPermissionStatus status) {
    switch (status) {
      case AppLocationPermissionStatus.serviceDisabled:
        return 'Turn on device location services to find nearby venues.';
      case AppLocationPermissionStatus.denied:
        return 'Location permission was denied. Allow location access to discover nearby venues.';
      case AppLocationPermissionStatus.deniedForever:
        return 'Location permission is blocked. Enable it in system settings to use Near Me.';
      case AppLocationPermissionStatus.unknown:
      case AppLocationPermissionStatus.granted:
        return 'Location is unavailable right now.';
    }
  }
}

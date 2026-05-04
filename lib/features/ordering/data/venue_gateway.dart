import 'dart:math' as math;

import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/hospitality/menu_category_model.dart';
import '../../../models/hospitality/menu_item_model.dart';
import '../../../models/hospitality/venue_model.dart';
import '../../../models/hospitality/venue_table_model.dart';

/// Gateway for venue and menu data access via Supabase.
abstract interface class VenueGateway {
  /// Fetch a single venue by slug (QR deep-link entry).
  Future<VenueModel?> getVenueBySlug(String slug);

  /// Fetch a single venue by ID.
  Future<VenueModel?> getVenueById(String venueId);

  /// List active venues, optionally filtered by country.
  Future<List<VenueModel>> listActiveVenues({String? countryCode, int limit});

  /// Search venues by name.
  Future<List<VenueModel>> searchVenues(
    String query, {
    String? countryCode,
    int limit,
  });

  /// List active venues ordered by distance from a foreground device location.
  Future<List<VenueModel>> listNearbyVenues({
    required double latitude,
    required double longitude,
    double radiusKm,
    String query,
    int limit,
  });

  /// Fetch tables for a venue.
  Future<List<VenueTableModel>> getVenueTables(String venueId);

  /// Fetch menu categories for a venue (ordered).
  Future<List<MenuCategoryModel>> getMenuCategories(String venueId);

  /// Fetch menu items for a venue, optionally filtered by category.
  Future<List<MenuItemModel>> getMenuItems(
    String venueId, {
    String? categoryId,
    bool availableOnly,
  });

  /// Fetch full menu grouped by category (categories → items map).
  Future<Map<MenuCategoryModel, List<MenuItemModel>>> getFullMenu(
    String venueId,
  );

  /// Fetch venues owned by a user (for venue dashboard entry).
  Future<List<VenueModel>> getMyVenues(String userId);
}

class SupabaseVenueGateway implements VenueGateway {
  SupabaseVenueGateway(this._connection);

  final SupabaseConnection _connection;

  @override
  Future<VenueModel?> getVenueBySlug(String slug) async {
    final client = _connection.client;
    if (client == null) return null;

    try {
      final row = await client
          .from('venues')
          .select()
          .eq('slug', slug)
          .eq('is_active', true)
          .maybeSingle();
      if (row == null) return null;
      return VenueModel.fromJson(row);
    } catch (error) {
      AppLogger.w('Failed to load venue by slug "$slug": $error');
      return null;
    }
  }

  @override
  Future<VenueModel?> getVenueById(String venueId) async {
    final client = _connection.client;
    if (client == null) return null;

    try {
      final row = await client
          .from('venues')
          .select()
          .eq('id', venueId)
          .maybeSingle();
      if (row == null) return null;
      return VenueModel.fromJson(row);
    } catch (error) {
      AppLogger.w('Failed to load venue by id: $error');
      return null;
    }
  }

  @override
  Future<List<VenueModel>> listActiveVenues({
    String? countryCode,
    int limit = 50,
  }) async {
    final client = _connection.client;
    if (client == null) return const [];

    try {
      var query = client
          .from('venues')
          .select()
          .eq('is_active', true)
          .eq('is_open', true);

      if (countryCode != null) {
        query = query.eq('country_code', countryCode);
      }

      final rows = await query.order('name').limit(limit);

      return (rows as List)
          .whereType<Map>()
          .map((row) => VenueModel.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } catch (error) {
      AppLogger.w('Failed to list active venues: $error');
      return const [];
    }
  }

  @override
  Future<List<VenueModel>> searchVenues(
    String query, {
    String? countryCode,
    int limit = 20,
  }) async {
    final client = _connection.client;
    if (client == null) return const [];

    try {
      var request = client
          .from('venues')
          .select()
          .eq('is_active', true)
          .eq('is_open', true);

      if (countryCode != null && countryCode.trim().isNotEmpty) {
        request = request.eq('country_code', countryCode.trim().toUpperCase());
      }

      final normalizedQuery = query.trim();
      if (normalizedQuery.isNotEmpty) {
        final pattern = '%$normalizedQuery%';
        request = request.or(
          'name.ilike.$pattern,city.ilike.$pattern,'
          'address_line1.ilike.$pattern,primary_category.ilike.$pattern',
        );
      }

      final rows = await request.order('name').limit(limit);

      return (rows as List)
          .whereType<Map>()
          .map((row) => VenueModel.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } catch (error) {
      AppLogger.w('Failed to search venues: $error');
      return const [];
    }
  }

  @override
  Future<List<VenueModel>> listNearbyVenues({
    required double latitude,
    required double longitude,
    double radiusKm = 20,
    String query = '',
    int limit = 40,
  }) async {
    final client = _connection.client;
    if (client == null) return const [];

    try {
      final rows = await client.rpc(
        'search_nearby_venues',
        params: {
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_limit': math.max(limit, 80),
        },
      );

      final venues = (rows as List)
          .whereType<Map>()
          .map((row) => VenueModel.fromJson(Map<String, dynamic>.from(row)))
          .where(
            (venue) =>
                (venue.distanceKmFrom(latitude, longitude) ??
                    double.infinity) <=
                radiusKm,
          )
          .where((venue) => _matchesVenueQuery(venue, query))
          .take(limit)
          .toList(growable: false);
      return venues;
    } catch (error) {
      AppLogger.w('Failed to load nearby venues via RPC: $error');
      return _listNearbyVenuesClientSide(
        connection: _connection,
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        query: query,
        limit: limit,
      );
    }
  }

  @override
  Future<List<VenueTableModel>> getVenueTables(String venueId) async {
    final client = _connection.client;
    if (client == null) return const [];

    try {
      final rows = await client
          .from('venue_tables')
          .select()
          .eq('venue_id', venueId)
          .eq('is_active', true)
          .order('table_number');

      return (rows as List)
          .whereType<Map>()
          .map((row) => VenueTableModel.fromJson(_normalizeVenueTableRow(row)))
          .toList(growable: false);
    } catch (error) {
      AppLogger.w('Failed to load venue tables: $error');
      return const [];
    }
  }

  @override
  Future<List<MenuCategoryModel>> getMenuCategories(String venueId) async {
    final client = _connection.client;
    if (client == null) return const [];

    try {
      final rows = await client
          .from('menu_categories')
          .select()
          .eq('venue_id', venueId)
          .eq('is_visible', true)
          .order('display_order');

      return (rows as List)
          .whereType<Map>()
          .map(
            (row) => MenuCategoryModel.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    } catch (error) {
      AppLogger.w('Failed to load menu categories: $error');
      return const [];
    }
  }

  @override
  Future<List<MenuItemModel>> getMenuItems(
    String venueId, {
    String? categoryId,
    bool availableOnly = true,
  }) async {
    final client = _connection.client;
    if (client == null) return const [];

    try {
      var query = client.from('menu_items').select().eq('venue_id', venueId);

      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }

      if (availableOnly) {
        query = query.eq('is_available', true);
      }

      final rows = await query.order('display_order').order('name');

      return (rows as List)
          .whereType<Map>()
          .map((row) => MenuItemModel.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } catch (error) {
      AppLogger.w('Failed to load menu items: $error');
      return const [];
    }
  }

  @override
  Future<Map<MenuCategoryModel, List<MenuItemModel>>> getFullMenu(
    String venueId,
  ) async {
    final categories = await getMenuCategories(venueId);
    final items = await getMenuItems(venueId);

    final grouped = <MenuCategoryModel, List<MenuItemModel>>{};
    for (final category in categories) {
      grouped[category] = items
          .where((item) => item.categoryId == category.id)
          .toList(growable: false);
    }
    return grouped;
  }

  @override
  Future<List<VenueModel>> getMyVenues(String userId) async {
    final client = _connection.client;
    if (client == null) return const [];

    try {
      final rows = await client
          .from('venues')
          .select()
          .eq('owner_id', userId)
          .eq('is_active', true)
          .order('name');

      return (rows as List)
          .whereType<Map>()
          .map((row) => VenueModel.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } catch (error) {
      AppLogger.w('Failed to load user venues: $error');
      return const [];
    }
  }
}

extension VenueDistance on VenueModel {
  double? distanceKmFrom(double latitude, double longitude) {
    final venueLat = this.latitude;
    final venueLng = this.longitude;
    if (venueLat == null || venueLng == null) return null;
    return _distanceKm(latitude, longitude, venueLat, venueLng);
  }
}

Future<List<VenueModel>> _listNearbyVenuesClientSide({
  required SupabaseConnection connection,
  required double latitude,
  required double longitude,
  required double radiusKm,
  required String query,
  required int limit,
}) async {
  final client = connection.client;
  if (client == null) return const [];

  try {
    final request = client
        .from('venues')
        .select()
        .eq('is_active', true)
        .eq('is_open', true)
        .not('latitude', 'is', null)
        .not('longitude', 'is', null);

    final rows = await request.limit(500);
    final venues = (rows as List)
        .whereType<Map>()
        .map((row) => VenueModel.fromJson(Map<String, dynamic>.from(row)))
        .where(
          (venue) =>
              (venue.distanceKmFrom(latitude, longitude) ?? double.infinity) <=
              radiusKm,
        )
        .where((venue) => _matchesVenueQuery(venue, query))
        .toList(growable: false);

    venues.sort((left, right) {
      final leftDistance = left.distanceKmFrom(latitude, longitude);
      final rightDistance = right.distanceKmFrom(latitude, longitude);
      if (leftDistance == null && rightDistance == null) {
        return left.name.compareTo(right.name);
      }
      if (leftDistance == null) return 1;
      if (rightDistance == null) return -1;
      final distanceCompare = leftDistance.compareTo(rightDistance);
      if (distanceCompare != 0) return distanceCompare;
      return left.name.compareTo(right.name);
    });

    return venues.take(limit).toList(growable: false);
  } catch (error) {
    AppLogger.w('Failed to load nearby venues client-side: $error');
    return const [];
  }
}

bool _matchesVenueQuery(VenueModel venue, String rawQuery) {
  final query = rawQuery.trim().toLowerCase();
  if (query.isEmpty) return true;
  final haystack = [
    venue.name,
    venue.city ?? '',
    venue.addressLine1 ?? '',
    venue.primaryCategory ?? '',
  ].join(' ').toLowerCase();
  return haystack.contains(query);
}

double _distanceKm(
  double fromLatitude,
  double fromLongitude,
  double toLatitude,
  double toLongitude,
) {
  const earthRadiusKm = 6371.0;
  final dLat = _degreesToRadians(toLatitude - fromLatitude);
  final dLng = _degreesToRadians(toLongitude - fromLongitude);
  final lat1 = _degreesToRadians(fromLatitude);
  final lat2 = _degreesToRadians(toLatitude);

  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

double _degreesToRadians(double degrees) => degrees * math.pi / 180;

Map<String, dynamic> _normalizeVenueTableRow(Map<dynamic, dynamic> row) {
  final data = Map<String, dynamic>.from(row);
  data['qr_code_url'] ??= data['qr_url'];
  return data;
}

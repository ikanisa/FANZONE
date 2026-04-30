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
  Future<List<VenueModel>> searchVenues(String query, {int limit});

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

      final rows = await query
          .order('name')
          .limit(limit);

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
  Future<List<VenueModel>> searchVenues(String query, {int limit = 20}) async {
    final client = _connection.client;
    if (client == null) return const [];

    try {
      final rows = await client
          .from('venues')
          .select()
          .eq('is_active', true)
          .ilike('name', '%$query%')
          .order('name')
          .limit(limit);

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
  Future<List<VenueTableModel>> getVenueTables(String venueId) async {
    final client = _connection.client;
    if (client == null) return const [];

    try {
      final rows = await client
          .from('tables')
          .select()
          .eq('venue_id', venueId)
          .eq('is_active', true)
          .order('table_number');

      return (rows as List)
          .whereType<Map>()
          .map(
            (row) =>
                VenueTableModel.fromJson(Map<String, dynamic>.from(row)),
          )
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
            (row) =>
                MenuCategoryModel.fromJson(Map<String, dynamic>.from(row)),
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
      var query = client
          .from('menu_items')
          .select()
          .eq('venue_id', venueId);

      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }

      if (availableOnly) {
        query = query.eq('is_available', true);
      }

      final rows = await query
          .order('display_order')
          .order('name');

      return (rows as List)
          .whereType<Map>()
          .map(
            (row) => MenuItemModel.fromJson(Map<String, dynamic>.from(row)),
          )
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

/// Riverpod provider for active venue context.
///
/// Set when user enters via QR deep link (`/v/:slug?t=:table`)
/// or selects a venue from discovery. All ordering operations
/// read from this provider to determine the target venue/table.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/hospitality/menu_category_model.dart';
import '../../../models/hospitality/menu_item_model.dart';
import '../../../models/hospitality/venue_model.dart';
import '../../../models/hospitality/venue_table_model.dart';
import '../data/venue_gateway.dart';
import '../../../core/di/gateway_providers.dart';

// ═══════════════════════════════════════════════════════════
// VENUE CONTEXT STATE
// ═══════════════════════════════════════════════════════════

/// Holds the active venue + table context for the current ordering session.
class VenueContext {
  const VenueContext({
    this.venue,
    this.table,
    this.tableNumber,
  });

  final VenueModel? venue;
  final VenueTableModel? table;
  final String? tableNumber; // from QR param before table lookup

  bool get hasVenue => venue != null;
  bool get hasTable => table != null;

  String? get venueId => venue?.id;
  String? get tableId => table?.id;
  String get currencyCode => venue?.currencyCode ?? 'EUR';

  VenueContext copyWith({
    VenueModel? venue,
    VenueTableModel? table,
    String? tableNumber,
  }) {
    return VenueContext(
      venue: venue ?? this.venue,
      table: table ?? this.table,
      tableNumber: tableNumber ?? this.tableNumber,
    );
  }

  static const empty = VenueContext();
}

/// Manages the active venue context for ordering.
class VenueContextNotifier extends StateNotifier<VenueContext> {
  VenueContextNotifier(this._gateway) : super(VenueContext.empty);

  final VenueGateway _gateway;

  /// Set venue by slug (from QR deep link).
  /// Optionally resolves table number to a VenueTableModel.
  Future<bool> setVenueBySlug(String slug, {String? tableNumber}) async {
    final venue = await _gateway.getVenueBySlug(slug);
    if (venue == null) return false;

    VenueTableModel? table;
    if (tableNumber != null) {
      final tables = await _gateway.getVenueTables(venue.id);
      table = tables.cast<VenueTableModel?>().firstWhere(
            (t) => t!.tableNumber.toString() == tableNumber,
            orElse: () => null,
          );
    }

    state = VenueContext(
      venue: venue,
      table: table,
      tableNumber: tableNumber,
    );
    return true;
  }

  /// Set venue by ID (e.g., from venue list selection).
  Future<bool> setVenueById(String venueId, {String? tableNumber}) async {
    final venue = await _gateway.getVenueById(venueId);
    if (venue == null) return false;

    state = VenueContext(
      venue: venue,
      tableNumber: tableNumber,
    );
    return true;
  }

  /// Directly set venue and table (when both are already resolved).
  void setContext(VenueModel venue, {VenueTableModel? table}) {
    state = VenueContext(venue: venue, table: table);
  }

  /// Clear the venue context (e.g., leaving a venue).
  void clear() {
    state = VenueContext.empty;
  }
}

final venueContextProvider =
    StateNotifierProvider<VenueContextNotifier, VenueContext>((ref) {
  return VenueContextNotifier(ref.watch(venueGatewayProvider));
});

// ═══════════════════════════════════════════════════════════
// MENU DATA PROVIDERS
// ═══════════════════════════════════════════════════════════

/// Fetches menu categories for the active venue.
final menuCategoriesProvider =
    FutureProvider.autoDispose<List<MenuCategoryModel>>((ref) async {
  final context = ref.watch(venueContextProvider);
  if (!context.hasVenue) return const [];
  final gateway = ref.watch(venueGatewayProvider);
  return gateway.getMenuCategories(context.venueId!);
});

/// Fetches menu items for the active venue.
final menuItemsProvider =
    FutureProvider.autoDispose<List<MenuItemModel>>((ref) async {
  final context = ref.watch(venueContextProvider);
  if (!context.hasVenue) return const [];
  final gateway = ref.watch(venueGatewayProvider);
  return gateway.getMenuItems(context.venueId!);
});

/// Menu items grouped by category — ready for tab display.
final groupedMenuProvider = FutureProvider.autoDispose<
    Map<MenuCategoryModel, List<MenuItemModel>>>((ref) async {
  final context = ref.watch(venueContextProvider);
  if (!context.hasVenue) return const {};
  final gateway = ref.watch(venueGatewayProvider);
  return gateway.getFullMenu(context.venueId!);
});

/// Venue tables for the active venue (venue dashboard use).
final venueTablesProvider =
    FutureProvider.autoDispose<List<VenueTableModel>>((ref) async {
  final context = ref.watch(venueContextProvider);
  if (!context.hasVenue) return const [];
  final gateway = ref.watch(venueGatewayProvider);
  return gateway.getVenueTables(context.venueId!);
});

/// Riverpod provider for active venue context.
///
/// Set when a user selects a venue from discovery or opens a venue link.
/// All ordering operations read from this provider to determine the target
/// venue.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/hospitality/menu_category_model.dart';
import '../../../models/hospitality/menu_item_model.dart';
import '../../../models/hospitality/venue_model.dart';
import '../data/venue_gateway.dart';
import '../../../core/di/gateway_providers.dart';

// ═══════════════════════════════════════════════════════════
// VENUE CONTEXT STATE
// ═══════════════════════════════════════════════════════════

/// Holds the active venue context for the current ordering session.
class VenueContext {
  const VenueContext({this.venue});

  final VenueModel? venue;

  bool get hasVenue => venue != null;

  String? get venueId => venue?.id;
  String get currencyCode => venue?.currencyCode ?? 'EUR';

  VenueContext copyWith({VenueModel? venue}) {
    return VenueContext(venue: venue ?? this.venue);
  }

  static const empty = VenueContext();
}

/// Manages the active venue context for ordering.
class VenueContextNotifier extends StateNotifier<VenueContext> {
  VenueContextNotifier(this._gateway) : super(VenueContext.empty);

  final VenueGateway _gateway;

  /// Set venue by slug.
  Future<bool> setVenueBySlug(String slug) async {
    final venue = await _gateway.getVenueBySlug(slug);
    if (venue == null) return false;

    state = VenueContext(venue: venue);
    return true;
  }

  /// Set venue by ID (e.g., from venue list selection).
  Future<bool> setVenueById(String venueId) async {
    final venue = await _gateway.getVenueById(venueId);
    if (venue == null) return false;

    state = VenueContext(venue: venue);
    return true;
  }

  /// Directly set venue.
  void setContext(VenueModel venue) {
    state = VenueContext(venue: venue);
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
final menuItemsProvider = FutureProvider.autoDispose<List<MenuItemModel>>((
  ref,
) async {
  final context = ref.watch(venueContextProvider);
  if (!context.hasVenue) return const [];
  final gateway = ref.watch(venueGatewayProvider);
  return gateway.getMenuItems(context.venueId!);
});

/// Menu items grouped by category — ready for tab display.
final groupedMenuProvider =
    FutureProvider.autoDispose<Map<MenuCategoryModel, List<MenuItemModel>>>((
      ref,
    ) async {
      final context = ref.watch(venueContextProvider);
      if (!context.hasVenue) return const {};
      final gateway = ref.watch(venueGatewayProvider);
      return gateway.getFullMenu(context.venueId!);
    });

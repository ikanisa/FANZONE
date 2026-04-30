/// Riverpod provider for local cart state.
///
/// The cart is purely client-side until the user places an order.
/// Cart items reference menu items by ID and snapshot the name/price
/// at the time of adding (preventing price-change confusion).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/hospitality/menu_item_model.dart';
import '../data/order_gateway.dart';

// ═══════════════════════════════════════════════════════════
// CART ITEM MODEL
// ═══════════════════════════════════════════════════════════

/// A single item in the cart with quantity and price snapshot.
class CartItem {
  const CartItem({
    required this.menuItemId,
    required this.name,
    this.description,
    required this.unitPrice,
    required this.currencyCode,
    this.quantity = 1,
    this.addOns = const [],
    this.specialInstructions,
  });

  final String menuItemId;
  final String name;
  final String? description;
  final double unitPrice;
  final String currencyCode;
  final int quantity;
  final List<Map<String, dynamic>> addOns;
  final String? specialInstructions;

  double get lineTotal => unitPrice * quantity;

  /// Formatted line total for display.
  String get lineTotalDisplay {
    if (currencyCode == 'EUR') {
      return '€${lineTotal.toStringAsFixed(2)}';
    } else if (currencyCode == 'RWF') {
      return 'RWF ${lineTotal.toStringAsFixed(0)}';
    }
    return '$currencyCode ${lineTotal.toStringAsFixed(2)}';
  }

  CartItem copyWith({
    int? quantity,
    List<Map<String, dynamic>>? addOns,
    String? specialInstructions,
  }) {
    return CartItem(
      menuItemId: menuItemId,
      name: name,
      description: description,
      unitPrice: unitPrice,
      currencyCode: currencyCode,
      quantity: quantity ?? this.quantity,
      addOns: addOns ?? this.addOns,
      specialInstructions: specialInstructions ?? this.specialInstructions,
    );
  }

  /// Convert to DTO for order placement.
  CreateOrderItemDto toOrderItemDto() {
    return CreateOrderItemDto(
      menuItemId: menuItemId,
      itemNameSnapshot: name,
      itemDescriptionSnapshot: description,
      quantity: quantity,
      unitPrice: unitPrice,
      currencyCode: currencyCode,
      addOns: addOns,
      specialInstructions: specialInstructions,
    );
  }

  /// Create a CartItem from a MenuItemModel.
  factory CartItem.fromMenuItem(MenuItemModel item) {
    return CartItem(
      menuItemId: item.id,
      name: item.name,
      description: item.description,
      unitPrice: item.price,
      currencyCode: item.currencyCode,
    );
  }
}

// ═══════════════════════════════════════════════════════════
// CART STATE
// ═══════════════════════════════════════════════════════════

/// Immutable cart state.
class CartState {
  const CartState({
    this.items = const [],
    this.tipAmount = 0,
    this.appliedFet = 0,
    this.fetConversionRate = 100, // 100 FET = 1 unit of currency
    this.specialInstructions,
  });

  final List<CartItem> items;
  final double tipAmount;
  final int appliedFet;
  final int fetConversionRate;
  final String? specialInstructions;

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  int get totalItemCount =>
      items.fold<int>(0, (sum, item) => sum + item.quantity);

  double get subtotal =>
      items.fold<double>(0, (sum, item) => sum + item.lineTotal);

  /// The discount amount in currency units derived from applied FET.
  double get discountFromFet => appliedFet / fetConversionRate;

  double get total => subtotal + tipAmount - discountFromFet;

  /// Formatted total for display.
  String get totalDisplay {
    if (items.isEmpty) return '';
    final currency = items.first.currencyCode;
    final displayTotal = total < 0 ? 0.0 : total;
    if (currency == 'EUR') {
      return '€${displayTotal.toStringAsFixed(2)}';
    } else if (currency == 'RWF') {
      return 'RWF ${displayTotal.toStringAsFixed(0)}';
    }
    return '$currency ${displayTotal.toStringAsFixed(2)}';
  }

  /// Estimated FET earnings (100 FET per 1 EUR).
  int get estimatedFet {
    if (items.isEmpty) return 0;
    final currency = items.first.currencyCode;
    // We only earn FET on the remaining cash balance
    final cashAmount = total < 0 ? 0.0 : total;
    if (currency == 'EUR') return (cashAmount * 100).floor();
    if (currency == 'RWF') return ((cashAmount / 1500) * 100).floor();
    return 0;
  }

  static const empty = CartState();

  CartState copyWith({
    List<CartItem>? items,
    double? tipAmount,
    int? appliedFet,
    int? fetConversionRate,
    String? specialInstructions,
  }) {
    return CartState(
      items: items ?? this.items,
      tipAmount: tipAmount ?? this.tipAmount,
      appliedFet: appliedFet ?? this.appliedFet,
      fetConversionRate: fetConversionRate ?? this.fetConversionRate,
      specialInstructions: specialInstructions ?? this.specialInstructions,
    );
  }
}

// ═══════════════════════════════════════════════════════════
// CART NOTIFIER
// ═══════════════════════════════════════════════════════════

/// Manages local cart state with add/remove/update operations.
class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(CartState.empty);

  /// Add a menu item to the cart (or increment quantity if already present).
  void addItem(MenuItemModel menuItem) {
    final existing = state.items.indexWhere(
      (item) => item.menuItemId == menuItem.id,
    );

    if (existing >= 0) {
      // Increment quantity
      final updated = List<CartItem>.from(state.items);
      updated[existing] = updated[existing].copyWith(
        quantity: updated[existing].quantity + 1,
      );
      state = state.copyWith(items: updated);
    } else {
      // Add new item
      state = state.copyWith(items: [...state.items, CartItem.fromMenuItem(menuItem)]);
    }
  }

  /// Remove one quantity of an item, or remove entirely if quantity is 1.
  void removeItem(String menuItemId) {
    final existing = state.items.indexWhere(
      (item) => item.menuItemId == menuItemId,
    );
    if (existing < 0) return;

    final updated = List<CartItem>.from(state.items);
    if (updated[existing].quantity > 1) {
      updated[existing] = updated[existing].copyWith(
        quantity: updated[existing].quantity - 1,
      );
    } else {
      updated.removeAt(existing);
    }

    state = state.copyWith(items: updated);
  }

  /// Set exact quantity for an item. Removes if quantity <= 0.
  void setQuantity(String menuItemId, int quantity) {
    if (quantity <= 0) {
      deleteItem(menuItemId);
      return;
    }

    final updated = state.items.map((item) {
      if (item.menuItemId == menuItemId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updated);
  }

  /// Delete an item entirely regardless of quantity.
  void deleteItem(String menuItemId) {
    state = state.copyWith(
      items: state.items
          .where((item) => item.menuItemId != menuItemId)
          .toList(),
    );
  }

  /// Set tip amount.
  void setTip(double tip) {
    state = state.copyWith(tipAmount: tip);
  }

  /// Apply FET tokens to the order.
  void applyFet(int amount) {
    state = state.copyWith(appliedFet: amount);
  }

  /// Set special instructions for the whole order.
  void setSpecialInstructions(String? instructions) {
    state = state.copyWith(specialInstructions: instructions);
  }

  /// Get the quantity of a specific item in the cart.
  int getQuantity(String menuItemId) {
    final item = state.items.cast<CartItem?>().firstWhere(
          (item) => item!.menuItemId == menuItemId,
          orElse: () => null,
        );
    return item?.quantity ?? 0;
  }

  /// Clear the entire cart.
  void clear() {
    state = CartState.empty;
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});

/// Convenience: number of items in cart (for badge display on cart pill).
final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).totalItemCount;
});

/// Convenience: whether the cart is empty.
final cartIsEmptyProvider = Provider<bool>((ref) {
  return ref.watch(cartProvider).isEmpty;
});

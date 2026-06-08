import 'package:flutter_test/flutter_test.dart';

import 'package:fanzone/features/ordering/providers/cart_provider.dart';
import 'package:fanzone/features/ordering/widgets/menu_item_detail_sheet.dart';
import 'package:fanzone/models/hospitality/menu_item_model.dart';

void main() {
  group('menu item detail and cart customization', () {
    test('configured cart items preserve add-ons and prep notes', () {
      const item = MenuItemModel(
        id: 'burger_1',
        venueId: 'venue_1',
        categoryId: 'mains',
        name: 'House Burger',
        description: 'Beef burger',
        price: 12,
        currencyCode: 'EUR',
      );
      final notifier = CartNotifier();

      notifier.addConfiguredItem(
        item,
        quantity: 2,
        addOns: const [
          {'id': 'cheese', 'name': 'Cheese', 'price': 1.5},
        ],
        specialInstructions: '  sauce   on side ',
      );

      final cartItem = notifier.state.items.single;
      expect(cartItem.quantity, 2);
      expect(cartItem.unitPrice, 13.5);
      expect(cartItem.lineTotal, 27);
      expect(cartItem.addOns.single['id'], 'cheese');
      expect(cartItem.specialInstructions, 'sauce on side');
      expect(cartItem.toOrderItemDto().addOns.single['name'], 'Cheese');
      expect(cartItem.toOrderItemDto().specialInstructions, 'sauce on side');
    });

    test(
      'same customization increments quantity while different notes split',
      () {
        const item = MenuItemModel(
          id: 'fries_1',
          venueId: 'venue_1',
          categoryId: 'sides',
          name: 'Fries',
          price: 5,
          currencyCode: 'EUR',
        );
        final notifier = CartNotifier();

        notifier.addConfiguredItem(item, specialInstructions: 'crispy');
        notifier.addConfiguredItem(item, specialInstructions: 'crispy');
        notifier.addConfiguredItem(item, specialInstructions: 'no salt');

        expect(notifier.state.items, hasLength(2));
        expect(notifier.state.items.first.quantity, 2);
        expect(notifier.getQuantity(item.id), 3);
      },
    );

    test('allergens and age restrictions require confirmation', () {
      const allergenItem = MenuItemModel(
        id: 'nuts_1',
        venueId: 'venue_1',
        categoryId: 'snacks',
        name: 'Peanut bowl',
        price: 4,
        currencyCode: 'EUR',
        allergens: ['Peanuts'],
      );
      const restrictedItem = MenuItemModel(
        id: 'beer_1',
        venueId: 'venue_1',
        categoryId: 'drinks',
        name: 'Local beer',
        price: 6,
        currencyCode: 'EUR',
        metadata: {'age_restricted': true},
      );

      expect(menuItemNeedsConfirmation(allergenItem), isTrue);
      expect(menuItemNeedsConfirmation(restrictedItem), isTrue);
      expect(menuItemIsAgeRestricted(restrictedItem), isTrue);
      expect(menuAddOnName(const {'label': 'Extra sauce'}), 'Extra sauce');
      expect(menuAddOnPrice(const {'amount': '2.25'}), 2.25);
    });
  });
}

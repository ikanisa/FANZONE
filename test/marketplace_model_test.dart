import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/models/marketplace_model.dart';

void main() {
  group('MarketplaceOffer', () {
    final row = {
      'id': 'offer-1',
      'partner_id': 'partner-malta-cafe',
      'partner': {
        'name': 'Malta Café',
        'logo_url': 'https://example.com/logo.png',
      },
      'title': 'Free Cappuccino',
      'description': 'Redeem for a free cappuccino at any Malta Café location',
      'category': 'food_drink',
      'cost_fet': 500,
      'delivery_type': 'voucher',
      'is_active': true,
      'image_url': 'https://example.com/cappuccino.jpg',
      'original_value': '€3.50',
      'stock': 100,
      'terms': 'Valid for 7 days after redemption',
      'valid_until': '2026-12-31T23:59:59.000Z',
    };

    test('fromRow parses all fields including nested partner', () {
      final offer = MarketplaceOffer.fromRow(row);
      expect(offer.id, 'offer-1');
      expect(offer.partnerId, 'partner-malta-cafe');
      expect(offer.partnerName, 'Malta Café');
      expect(offer.title, 'Free Cappuccino');
      expect(offer.costFet, 500);
      expect(offer.deliveryType, 'voucher');
      expect(offer.isActive, true);
      expect(offer.partnerLogoUrl, contains('logo.png'));
      expect(offer.originalValue, '€3.50');
      expect(offer.stock, 100);
      expect(offer.terms, contains('7 days'));
      expect(offer.validUntil, isNotNull);
    });

    test('isLimitedStock returns true when stock is set', () {
      final offer = MarketplaceOffer.fromRow(row);
      expect(offer.isLimitedStock, true);
    });

    test('isLimitedStock returns false when stock is null', () {
      final noStock = Map<String, dynamic>.from(row);
      noStock.remove('stock');
      final offer = MarketplaceOffer.fromRow(noStock);
      expect(offer.isLimitedStock, false);
    });

    test('fromRow handles missing partner gracefully', () {
      final noPartner = Map<String, dynamic>.from(row);
      noPartner.remove('partner');
      final offer = MarketplaceOffer.fromRow(noPartner);
      expect(offer.partnerName, 'Partner');
      expect(offer.partnerLogoUrl, isNull);
    });

    test('fromRow handles empty/null fields', () {
      final minimal = {
        'id': null,
        'partner_id': null,
        'partner': null,
        'title': null,
        'category': null,
        'cost_fet': null,
        'delivery_type': null,
        'is_active': null,
      };
      final offer = MarketplaceOffer.fromRow(minimal);
      expect(offer.id, '');
      expect(offer.partnerName, 'Partner');
      expect(offer.costFet, 0);
      expect(offer.deliveryType, 'voucher');
    });
  });

  group('MarketplaceRedemption', () {
    final row = {
      'id': 'redeem-1',
      'offer_id': 'offer-1',
      'cost_fet': 500,
      'delivery_type': 'voucher',
      'status': 'fulfilled',
      'redeemed_at': '2026-04-18T10:00:00.000Z',
      'delivery_value': 'VOUCHER-ABC123',
      'expires_at': '2026-04-25T10:00:00.000Z',
      'offer': {
        'title': 'Free Cappuccino',
        'image_url': 'https://example.com/cap.jpg',
        'partner': {'name': 'Malta Café'},
      },
    };

    test('fromRow parses nested offer and partner', () {
      final redemption = MarketplaceRedemption.fromRow(row);
      expect(redemption.id, 'redeem-1');
      expect(redemption.title, 'Free Cappuccino');
      expect(redemption.partnerName, 'Malta Café');
      expect(redemption.costFet, 500);
      expect(redemption.status, 'fulfilled');
      expect(redemption.deliveryValue, 'VOUCHER-ABC123');
      expect(redemption.expiresAt, isNotNull);
      expect(redemption.imageUrl, contains('cap.jpg'));
    });

    test('fromRow handles missing nested data', () {
      final minimal = {
        'id': 'r2',
        'offer_id': 'o2',
        'cost_fet': 100,
        'delivery_type': 'in_app',
        'status': 'pending',
        'redeemed_at': '2026-04-18T10:00:00.000Z',
        'offer': {},
      };
      final redemption = MarketplaceRedemption.fromRow(minimal);
      expect(redemption.title, 'Reward');
      expect(redemption.partnerName, 'Partner');
      expect(redemption.imageUrl, isNull);
    });
  });

  group('MarketplaceRedeemResult', () {
    test('fromJson parses all fields', () {
      final json = {
        'status': 'fulfilled',
        'redemption_id': 'redeem-1',
        'delivery_type': 'voucher',
        'balance_after': 1500,
        'delivery_value': 'CODE-XYZ',
      };
      final result = MarketplaceRedeemResult.fromJson(json);
      expect(result.status, 'fulfilled');
      expect(result.redemptionId, 'redeem-1');
      expect(result.balanceAfter, 1500);
      expect(result.deliveryValue, 'CODE-XYZ');
    });

    test('fromJson with null delivery value', () {
      final json = {
        'status': 'pending',
        'redemption_id': 'r2',
        'delivery_type': 'in_app',
        'balance_after': 800,
      };
      final result = MarketplaceRedeemResult.fromJson(json);
      expect(result.deliveryValue, isNull);
    });

    test('fromJson with missing fields uses defaults', () {
      final result = MarketplaceRedeemResult.fromJson({});
      expect(result.status, 'pending');
      expect(result.redemptionId, '');
      expect(result.deliveryType, 'voucher');
      expect(result.balanceAfter, 0);
    });
  });
}

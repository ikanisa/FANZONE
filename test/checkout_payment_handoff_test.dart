import 'package:flutter_test/flutter_test.dart';

import 'package:fanzone/features/ordering/data/order_gateway.dart';
import 'package:fanzone/features/ordering/screens/checkout_screen.dart';
import 'package:fanzone/models/hospitality/order_model.dart';
import 'package:fanzone/models/hospitality/venue_model.dart';

void main() {
  group('checkout payment handoff', () {
    test('enables MoMo only for configured Rwanda venues', () {
      const rwandaVenue = VenueModel(
        id: 'venue-rw',
        name: 'Kigali Sports Bar',
        countryCode: CountryCode.rw,
        venueType: VenueType.bar,
        currencyCode: 'RWF',
        momoCode: '*182*8*1#',
      );
      const maltaVenue = VenueModel(
        id: 'venue-mt',
        name: 'Valletta Sports Bar',
        countryCode: CountryCode.mt,
        venueType: VenueType.bar,
        currencyCode: 'EUR',
        momoCode: '*182*8*1#',
      );
      const unconfiguredVenue = VenueModel(
        id: 'venue-rw-empty',
        name: 'No Handoff Bar',
        countryCode: CountryCode.rw,
        venueType: VenueType.bar,
        currencyCode: 'RWF',
      );

      expect(venueSupportsPaymentMethod(rwandaVenue, PaymentMethod.momo), true);
      expect(venueSupportsPaymentMethod(maltaVenue, PaymentMethod.momo), false);
      expect(
        venueSupportsPaymentMethod(unconfiguredVenue, PaymentMethod.momo),
        false,
      );
    });

    test('enables Revolut only for configured Malta venues', () {
      const maltaVenue = VenueModel(
        id: 'venue-mt',
        name: 'Valletta Sports Bar',
        countryCode: CountryCode.mt,
        venueType: VenueType.bar,
        currencyCode: 'EUR',
        revolutLink: 'https://revolut.me/fanzone',
      );
      const rwandaVenue = VenueModel(
        id: 'venue-rw',
        name: 'Kigali Sports Bar',
        countryCode: CountryCode.rw,
        venueType: VenueType.bar,
        currencyCode: 'RWF',
        revolutLink: 'https://revolut.me/fanzone',
      );

      expect(
        venueSupportsPaymentMethod(maltaVenue, PaymentMethod.revolut),
        true,
      );
      expect(
        venueSupportsPaymentMethod(rwandaVenue, PaymentMethod.revolut),
        false,
      );
    });

    test('falls back unsupported checkout payment methods to cash', () {
      const venue = VenueModel(
        id: 'venue-1',
        name: 'Cash Bar',
        countryCode: CountryCode.mt,
        venueType: VenueType.bar,
        currencyCode: 'EUR',
      );

      expect(
        preferredCheckoutPaymentMethod(
          current: PaymentMethod.revolut,
          venue: venue,
        ),
        PaymentMethod.cash,
      );
      expect(
        preferredCheckoutPaymentMethod(
          current: PaymentMethod.card,
          venue: venue,
        ),
        PaymentMethod.cash,
      );
      expect(
        preferredCheckoutPaymentMethod(
          current: PaymentMethod.cash,
          venue: venue,
        ),
        PaymentMethod.cash,
      );
    });

    test('builds launch URI for MoMo USSD and Revolut links', () {
      const momo = PaymentHandoff(
        method: PaymentMethod.momo,
        amount: '12000',
        currency: 'RWF',
        instructions: ['Dial the USSD code and confirm payment.'],
        requiresStaffConfirmation: true,
        ussdString: '*182*8*1#',
      );
      const revolut = PaymentHandoff(
        method: PaymentMethod.revolut,
        amount: '12.00',
        currency: 'EUR',
        instructions: ['Open Revolut and send payment.'],
        requiresStaffConfirmation: true,
        paymentUrl: 'https://revolut.me/fanzone',
      );

      final momoUri = paymentHandoffLaunchUri(momo);
      final revolutUri = paymentHandoffLaunchUri(revolut);

      expect(momoUri?.scheme, 'tel');
      expect(momoUri.toString(), contains('%23'));
      expect(revolutUri?.scheme, 'https');
      expect(revolutUri.toString(), 'https://revolut.me/fanzone');
    });

    test(
      'returns no launch URI for missing or unsupported handoff methods',
      () {
        const missingMomo = PaymentHandoff(
          method: PaymentMethod.momo,
          amount: '12000',
          currency: 'RWF',
          instructions: [],
          requiresStaffConfirmation: true,
        );
        const cash = PaymentHandoff(
          method: PaymentMethod.cash,
          amount: '12.00',
          currency: 'EUR',
          instructions: [],
          requiresStaffConfirmation: true,
        );
        const invalidRevolut = PaymentHandoff(
          method: PaymentMethod.revolut,
          amount: '12.00',
          currency: 'EUR',
          instructions: [],
          requiresStaffConfirmation: true,
          paymentUrl: 'not-a-url',
        );

        expect(paymentHandoffLaunchUri(missingMomo), isNull);
        expect(paymentHandoffLaunchUri(cash), isNull);
        expect(paymentHandoffLaunchUri(invalidRevolut), isNull);
      },
    );
  });
}

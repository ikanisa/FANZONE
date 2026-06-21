import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/core/di/gateway_providers.dart';
import 'package:fanzone/features/ordering/data/venue_support_gateway.dart';
import 'package:fanzone/features/ordering/providers/venue_discovery_provider.dart';
import 'package:fanzone/features/ordering/screens/venue_detail_screen.dart';
import 'package:fanzone/models/hospitality/venue_model.dart';
import 'package:fanzone/models/hospitality/venue_support_request_model.dart';
import 'package:fanzone/providers/auth_provider.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('venue detail submits verified venue support request', (
    tester,
  ) async {
    final gateway = _FakeVenueSupportGateway();
    const venue = VenueModel(
      id: 'venue_1',
      name: 'Test Sports Bar',
      countryCode: CountryCode.rw,
      venueType: VenueType.bar,
      currencyCode: 'RWF',
      city: 'Kigali',
      isOpen: true,
      onboardingStatus: OnboardingStatus.live,
    );

    await pumpAppScreen(
      tester,
      const VenueDetailScreen(venueId: 'venue_1'),
      overrides: [
        isFullyAuthenticatedProvider.overrideWith((ref) => true),
        venueDetailByIdProvider('venue_1').overrideWith((ref) async => venue),
        venueSupportGatewayProvider.overrideWithValue(gateway),
      ],
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Contact venue'),
      find.byType(ListView),
      const Offset(0, -220),
    );
    await tester.tap(find.text('Contact venue'));
    await tester.pumpAndSettle();

    expect(find.text('Contact Test Sports Bar'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('venue_support_message')),
      'Need accessible seating near the screen.',
    );
    await tester.enterText(
      find.byKey(const ValueKey('venue_support_table')),
      'VIP 2',
    );
    await tester.tap(find.byKey(const ValueKey('venue_support_submit')));
    await tester.pumpAndSettle();

    expect(gateway.calls, hasLength(1));
    expect(gateway.calls.single.venueId, 'venue_1');
    expect(gateway.calls.single.topic, 'general');
    expect(
      gateway.calls.single.message,
      'Need accessible seating near the screen.',
    );
    expect(gateway.calls.single.tableNumber, 'VIP 2');
    expect(find.text('Venue support request sent.'), findsOneWidget);
  });
}

class _VenueSupportCall {
  const _VenueSupportCall({
    required this.venueId,
    required this.topic,
    required this.message,
    this.orderId,
    this.tableNumber,
  });

  final String venueId;
  final String topic;
  final String message;
  final String? orderId;
  final String? tableNumber;
}

class _FakeVenueSupportGateway implements VenueSupportGateway {
  final calls = <_VenueSupportCall>[];

  @override
  Future<VenueSupportRequestModel> createVenueSupportRequest({
    required String venueId,
    required String topic,
    required String message,
    String? orderId,
    String? tableNumber,
  }) async {
    calls.add(
      _VenueSupportCall(
        venueId: venueId,
        topic: topic,
        message: message,
        orderId: orderId,
        tableNumber: tableNumber,
      ),
    );

    return VenueSupportRequestModel(
      id: 'support_1',
      venueId: venueId,
      userId: 'user_1',
      topic: topic,
      message: message,
      status: 'open',
      createdAt: DateTime(2026, 6, 8, 12),
      orderId: orderId,
      tableNumber: tableNumber,
    );
  }
}

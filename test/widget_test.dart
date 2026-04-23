import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fanzone/core/config/bootstrap_config.dart';
import 'package:fanzone/core/di/gateway_providers.dart';
import 'package:fanzone/features/auth/screens/whatsapp_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Phone login screen renders branding', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          bootstrapConfigProvider.overrideWithValue(_testBootstrapConfig),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: PhoneLoginScreen(),
        ),
      ),
    );
    await tester.pump();
    tester.takeException();

    expect(find.text('ENTER WHATSAPP NUMBER'), findsOneWidget);
    expect(find.text('SEND CODE VIA WHATSAPP'), findsOneWidget);
    expect(find.text('Test Country • +111 • e.g. 99XX XXXX'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '79123456');
    await tester.pump();

    expect(
      find.text('Ready to send your WhatsApp OTP to Test Country.'),
      findsOneWidget,
    );
    expect(
      tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'SEND CODE VIA WHATSAPP'),
              )
              .onPressed !=
          null,
      isTrue,
    );
  });
}

final _testBootstrapConfig = BootstrapConfig(
  regions: const {
    'AA': RegionInfo(
      countryCode: 'AA',
      region: 'europe',
      countryName: 'Test Country',
      flagEmoji: '🏳️',
    ),
  },
  phonePresets: const {
    'AA': PhonePresetInfo(dialCode: '+111', hint: '99XX XXXX', minDigits: 8),
  },
  currencyDisplay: const {},
  countryCurrencies: const {'AA': 'EUR'},
  featureFlags: const {},
  appConfig: const {
    'default_phone_country_code': 'AA',
    'priority_phone_country_codes': ['AA'],
  },
  launchMoments: const [],
);

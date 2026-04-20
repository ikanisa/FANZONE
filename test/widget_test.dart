import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            CountryLocalizations.delegate,
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
    expect(find.text('Malta • +356 • e.g. 79XX XXXX'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '79123456');
    await tester.pump();

    expect(
      find.text('Ready to send your WhatsApp code to Malta.'),
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

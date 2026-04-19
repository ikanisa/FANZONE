import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fanzone/features/auth/screens/whatsapp_login_screen.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Phone login screen renders branding',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
          child: MaterialApp(home: PhoneLoginScreen())),
    );

    expect(find.text('FANZONE'), findsOneWidget);
    expect(find.text('VERIFY VIA WHATSAPP'), findsOneWidget);
    expect(find.text('SEND CODE VIA WHATSAPP'), findsOneWidget);
  });
}

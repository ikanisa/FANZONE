import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fanzone/features/onboarding/widgets/country_code_picker.dart';
import 'package:fanzone/features/onboarding/widgets/onboarding_phone_verification_steps.dart';

void main() {
  testWidgets('onboarding phone step uses WhatsApp copy', (tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnboardingPhoneStep(
            textColor: Colors.white,
            muted: Colors.grey,
            isDark: true,
            phoneController: controller,
            onChanged: (_) {},
            canContinue: false,
            onBack: () {},
            onNext: () {},
            selectedCountry: const CountryEntry(
              code: 'RW',
              dialCode: '+250',
              name: 'Rwanda',
              flag: '🇷🇼',
              hint: '7XX XXX XXX',
              minDigits: 9,
            ),
            buttonLabel: 'SEND OTP TO WHATSAPP',
          ),
        ),
      ),
    );

    expect(find.text('WHATSAPP LOGIN'), findsOneWidget);
    expect(
      find.text(
        'We\'ll send you an OTP via WhatsApp. No names or emails required.',
      ),
      findsOneWidget,
    );
    expect(find.text('SEND OTP TO WHATSAPP'), findsOneWidget);
  });

  testWidgets('onboarding phone step uses the locked +250 country slot', (
    tester,
  ) async {
    final controller = TextEditingController(text: '7718 6193');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnboardingPhoneStep(
            textColor: Colors.white,
            muted: Colors.grey,
            isDark: true,
            phoneController: controller,
            onChanged: (_) {},
            canContinue: true,
            onBack: () {},
            onNext: () {},
            selectedCountry: const CountryEntry(
              code: 'RW',
              dialCode: '+250',
              name: 'Rwanda',
              flag: '🇷🇼',
              hint: '7XX XXX XXX',
              minDigits: 9,
            ),
            buttonLabel: 'SEND OTP TO WHATSAPP',
          ),
        ),
      ),
    );

    expect(find.text('+250'), findsOneWidget);
  });
}

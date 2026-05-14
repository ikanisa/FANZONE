import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fanzone/core/constants/phone_presets.dart';
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
            onCountryChanged: (_) {},
            phoneHelpText: 'Test Country: +111 9XX XXX XXX',
            phoneHelpIsError: false,
            selectedCountry: const CountryEntry(
              countryCode: 'AA',
              countryName: 'Test Country',
              flagEmoji: '🏳️',
              preset: PhonePreset(
                dialCode: '+111',
                hint: '9XX XXX XXX',
                minDigits: 9,
              ),
            ),
            buttonLabel: 'SEND OTP TO WHATSAPP',
          ),
        ),
      ),
    );

    expect(find.text('WHATSAPP'), findsOneWidget);
    expect(
      find.text('Select your country code and enter a valid WhatsApp number.'),
      findsOneWidget,
    );
    expect(find.text('SEND OTP TO WHATSAPP'), findsOneWidget);
  });

  testWidgets('onboarding phone step shows the selected country dial code', (
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
            onCountryChanged: (_) {},
            phoneHelpText: 'Ready: +111 7718 6193',
            phoneHelpIsError: false,
            selectedCountry: const CountryEntry(
              countryCode: 'AA',
              countryName: 'Test Country',
              flagEmoji: '🏳️',
              preset: PhonePreset(
                dialCode: '+111',
                hint: '9XX XXX XXX',
                minDigits: 9,
              ),
            ),
            buttonLabel: 'SEND OTP TO WHATSAPP',
          ),
        ),
      ),
    );

    expect(find.text('+111'), findsOneWidget);
    expect(find.text('AA'), findsNothing);
  });
}

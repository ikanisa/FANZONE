import 'package:fanzone/features/auth/data/dev_whatsapp_otp_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('default fixture is inert without explicit dart defines', () {
    const fixture = DevWhatsAppOtpFixture();

    expect(fixture.isConfigured, isFalse);
    expect(fixture.matchesPhone('+3567718613'), isFalse);
  });

  test('matches only the configured development WhatsApp number', () {
    const fixture = DevWhatsAppOtpFixture(
      phoneNumber: '+3567718613',
      otp: '123456',
    );

    expect(fixture.matchesPhone('+3567718613'), isTrue);
    expect(fixture.matchesPhone('+356 7718 613'), isTrue);
    expect(fixture.matchesPhone('+3567718614'), isFalse);
  });

  test('supports multiple configured development WhatsApp numbers', () {
    const fixture = DevWhatsAppOtpFixture(
      phoneNumber: '+3567718613,+35699711145;+250788767816',
      otp: '123456',
    );

    expect(fixture.matchesPhone('+3567718613'), isTrue);
    expect(fixture.matchesPhone('+35699711145'), isTrue);
    expect(fixture.matchesPhone('+250 788 767 816'), isTrue);
    expect(fixture.matchesPhone('+3567718614'), isFalse);
  });

  test('accepts only the configured development OTP', () {
    const fixture = DevWhatsAppOtpFixture(
      phoneNumber: '+3567718613',
      otp: '123456',
    );

    expect(fixture.matchesOtp('123456'), isTrue);
    expect(fixture.matchesOtp(' 123456 '), isTrue);
    expect(fixture.matchesOtp('000000'), isFalse);
  });

  test('builds a Supabase-compatible local review session', () {
    const fixture = DevWhatsAppOtpFixture(
      phoneNumber: '+3567718613',
      otp: '123456',
    );
    final payload = fixture.sessionPayload(
      '+3567718613',
      now: DateTime.utc(2026, 6, 3, 12),
    );

    final session = Session.fromJson(payload);

    expect(session, isNotNull);
    expect(session!.user.phone, '+3567718613');
    expect(session.user.appMetadata['dev_otp_fixture'], isTrue);
    expect(session.expiresAt, greaterThan(0));
  });
}

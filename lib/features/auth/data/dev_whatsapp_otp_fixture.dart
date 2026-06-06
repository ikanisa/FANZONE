import 'dart:convert';

/// Local WhatsApp OTP fixture for review builds and debug development only.
///
/// The production login path remains the `whatsapp-otp` Edge Function.
class DevWhatsAppOtpFixture {
  const DevWhatsAppOtpFixture({
    this.phoneNumber = _configuredPhoneNumber,
    this.otp = _configuredOtp,
  });

  static const _configuredPhoneNumber = String.fromEnvironment(
    'DEV_WHATSAPP_OTP_PHONE',
  );
  static const _configuredOtp = String.fromEnvironment('DEV_WHATSAPP_OTP_CODE');
  static const _userId = '00000000-0000-4000-8000-000000000356';
  static const _sessionDuration = Duration(hours: 8);

  final String phoneNumber;
  final String otp;

  bool get isConfigured =>
      _configuredPhones(phoneNumber).isNotEmpty && otp.trim().isNotEmpty;

  bool matchesPhone(String phone) {
    if (!isConfigured) return false;
    final normalizedPhone = _normalizePhone(phone);
    return _configuredPhones(
      phoneNumber,
    ).any((configuredPhone) => configuredPhone == normalizedPhone);
  }

  bool matchesOtp(String value) => value.trim() == otp;

  Map<String, dynamic> sessionPayload(String phone, {DateTime? now}) {
    final issuedAt = (now ?? DateTime.now()).toUtc();
    final expiresAt = issuedAt.add(_sessionDuration);
    final issuedAtSeconds = issuedAt.millisecondsSinceEpoch ~/ 1000;
    final expiresAtSeconds = expiresAt.millisecondsSinceEpoch ~/ 1000;
    final normalizedPhone = _normalizePhone(phone);
    final accessToken = _accessToken(
      phone: normalizedPhone,
      issuedAtSeconds: issuedAtSeconds,
      expiresAtSeconds: expiresAtSeconds,
    );

    return <String, dynamic>{
      'success': true,
      'access_token': accessToken,
      'refresh_token': 'dev-review-refresh-token-$expiresAtSeconds',
      'expires_in': _sessionDuration.inSeconds,
      'expires_at': expiresAtSeconds,
      'token_type': 'bearer',
      'user': <String, dynamic>{
        'id': _userId,
        'aud': 'authenticated',
        'role': 'authenticated',
        'phone': normalizedPhone,
        'app_metadata': <String, dynamic>{
          'provider': 'phone',
          'providers': <String>['phone'],
          'dev_otp_fixture': true,
        },
        'user_metadata': <String, dynamic>{
          'phone': normalizedPhone,
          'dev_otp_fixture': true,
        },
        'created_at': issuedAt.toIso8601String(),
        'updated_at': issuedAt.toIso8601String(),
      },
    };
  }

  static String _normalizePhone(String phone) {
    final trimmed = phone.trim();
    final buffer = StringBuffer();
    for (final codeUnit in trimmed.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      if (char == '+' && buffer.isEmpty) {
        buffer.write(char);
        continue;
      }
      if (codeUnit >= 48 && codeUnit <= 57) {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  static List<String> _configuredPhones(String value) {
    return value
        .split(RegExp(r'[,;]'))
        .map(_normalizePhone)
        .where((phone) => phone.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static String _accessToken({
    required String phone,
    required int issuedAtSeconds,
    required int expiresAtSeconds,
  }) {
    final header = _base64UrlJson(<String, Object?>{
      'alg': 'none',
      'typ': 'JWT',
    });
    final payload = _base64UrlJson(<String, Object?>{
      'sub': _userId,
      'aud': 'authenticated',
      'role': 'authenticated',
      'phone': phone,
      'iat': issuedAtSeconds,
      'exp': expiresAtSeconds,
      'dev_otp_fixture': true,
    });
    return '$header.$payload.dev-review-signature';
  }

  static String _base64UrlJson(Map<String, Object?> value) {
    return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  }
}

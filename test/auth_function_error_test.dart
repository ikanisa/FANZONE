import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fanzone/features/auth/data/auth_function_error.dart';

void main() {
  group('extractAuthFunctionErrorMessage', () {
    test('reads structured function error payloads', () {
      final message = extractAuthFunctionErrorMessage(
        const FunctionException(
          status: 400,
          details: <String, dynamic>{'error': 'Invalid code.'},
        ),
        fallbackMessage: 'fallback',
      );

      expect(message, 'Invalid code.');
    });

    test('reads json-encoded function error payloads', () {
      final message = extractAuthFunctionErrorMessage(
        const FunctionException(
          status: 429,
          details: '{"error":"Too many attempts. Please request a new code."}',
        ),
        fallbackMessage: 'fallback',
      );

      expect(message, 'Too many attempts. Please request a new code.');
    });

    test('falls back when function details are empty', () {
      final message = extractAuthFunctionErrorMessage(
        const FunctionException(status: 500),
        fallbackMessage: 'fallback',
      );

      expect(message, 'fallback');
    });
  });
}

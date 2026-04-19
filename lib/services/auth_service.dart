import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logging/app_logger.dart';

/// Authentication service wrapping Supabase Auth.
///
/// Uses Supabase native phone OTP with SMS delivery.
class AuthService {
  AuthService(this._client);

  final SupabaseClient? _client;

  static const _timeout = Duration(seconds: 20);

  /// Whether auth is available.
  bool get isAvailable => _client != null;

  /// Current user, if authenticated.
  User? get currentUser => _client?.auth.currentUser;

  /// Whether a user is currently signed in.
  bool get isAuthenticated => currentUser != null;

  /// Send an OTP to the given phone number via Supabase phone auth.
  ///
  /// [phone] must include the country code (e.g. "+35612345678").
  /// Returns `true` if the OTP was sent successfully.
  Future<bool> sendOtp(String phone) async {
    if (_client == null) {
      throw const AuthException(
        'Server not available. Please try again later.',
      );
    }

    try {
      await _client.auth.signInWithOtp(phone: phone).timeout(_timeout);
      return true;
    } on AuthException {
      rethrow;
    } catch (e) {
      AppLogger.d('sendOtp error: $e');
      rethrow;
    }
  }

  /// Verify the OTP and sign in the user.
  ///
  /// [phone] must include the country code.
  /// [otp] is the 6-digit code the user received.
  Future<void> verifyOtp(String phone, String otp) async {
    if (_client == null) {
      throw const AuthException(
        'Server not available. Please try again later.',
      );
    }

    try {
      final response = await _client.auth
          .verifyOTP(type: OtpType.sms, phone: phone, token: otp)
          .timeout(_timeout);

      if (response.session == null) {
        throw const AuthException('Invalid OTP. Please try again.');
      }
    } on AuthException {
      rethrow;
    } catch (e) {
      AppLogger.d('verifyOtp error: $e');
      rethrow;
    }
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    if (_client == null) return;
    try {
      await _client.auth.signOut();
    } catch (e) {
      AppLogger.d('Sign out error: $e');
    }
  }

  /// Auth state change stream.
  Stream<AuthState>? get onAuthStateChange => _client?.auth.onAuthStateChange;
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';

abstract class AuthGateway {
  bool get isInitialized;

  bool get isAuthenticated;

  bool get isAnonymousUser;

  User? get currentUser;

  Session? get currentSession;

  Stream<AuthState> get onAuthStateChange;

  Future<bool> sendOtp(String phone);

  Future<void> verifyOtp(String phone, String otp);

  Future<AuthResponse> signInAnonymously();

  Future<void> signOut();

  Future<bool> isOnboardingCompletedForCurrentUser();

  Future<void> mergeAnonymousToAuthenticated(String anonId, String authId);
}

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._connection);

  final SupabaseConnection _connection;

  static const _timeout = Duration(seconds: 20);
  static const _otpChannel = OtpChannel.whatsapp;

  @override
  bool get isInitialized => _connection.isInitialized;

  @override
  bool get isAuthenticated => _connection.isAuthenticated;

  @override
  bool get isAnonymousUser {
    final user = _connection.currentUser;
    if (user == null) return false;
    return user.isAnonymous;
  }

  @override
  User? get currentUser => _connection.currentUser;

  @override
  Session? get currentSession => _connection.currentSession;

  @override
  Stream<AuthState> get onAuthStateChange => _connection.authStateChanges;

  @override
  Future<bool> sendOtp(String phone) async {
    final client = _requireClient();
    await client.auth
        .signInWithOtp(phone: phone, channel: _otpChannel)
        .timeout(_timeout);
    return true;
  }

  @override
  Future<void> verifyOtp(String phone, String otp) async {
    final client = _requireClient();
    final response = await client.auth
        // Supabase uses the phone OTP verifier type `sms` for phone codes,
        // even when the delivery channel is WhatsApp.
        .verifyOTP(type: OtpType.sms, phone: phone, token: otp)
        .timeout(_timeout);

    if (response.session == null) {
      throw const AuthException('Invalid OTP. Please try again.');
    }
  }

  @override
  Future<AuthResponse> signInAnonymously() async {
    final client = _requireClient();
    final response =
        await client.auth.signInAnonymously().timeout(_timeout);

    if (response.session == null) {
      throw const AuthException(
        'Could not create guest session. Please try again.',
      );
    }

    return response;
  }

  @override
  Future<void> signOut() async {
    final client = _connection.client;
    if (client == null) return;

    try {
      await client.auth.signOut();
    } catch (error) {
      AppLogger.d('Sign out error: $error');
    }
  }

  @override
  Future<bool> isOnboardingCompletedForCurrentUser() async {
    final session = currentSession;
    if (session == null) return false;

    final client = _requireClient();
    final profile = await client
        .from('profiles')
        .select('onboarding_completed')
        .eq('id', session.user.id)
        .maybeSingle()
        .timeout(_timeout);

    return profile?['onboarding_completed'] == true;
  }

  @override
  Future<void> mergeAnonymousToAuthenticated(
    String anonId,
    String authId,
  ) async {
    final client = _requireClient();
    await client
        .rpc('merge_anonymous_to_authenticated', params: {
          'p_anon_id': anonId,
          'p_auth_id': authId,
        })
        .timeout(const Duration(seconds: 30));
  }

  SupabaseClient _requireClient() {
    final client = _connection.client;
    if (client == null) {
      throw const AuthException(
        'Server not available. Please try again later.',
      );
    }
    return client;
  }
}

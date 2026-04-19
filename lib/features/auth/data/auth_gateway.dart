import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';

abstract class AuthGateway {
  bool get isInitialized;

  bool get isAuthenticated;

  User? get currentUser;

  Session? get currentSession;

  Stream<AuthState> get onAuthStateChange;

  Future<bool> sendOtp(String phone);

  Future<void> verifyOtp(String phone, String otp);

  Future<void> signOut();

  Future<bool> isOnboardingCompletedForCurrentUser();
}

@LazySingleton(as: AuthGateway)
class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._connection);

  final SupabaseConnection _connection;

  static const _timeout = Duration(seconds: 20);

  @override
  bool get isInitialized => _connection.isInitialized;

  @override
  bool get isAuthenticated => _connection.isAuthenticated;

  @override
  User? get currentUser => _connection.currentUser;

  @override
  Session? get currentSession => _connection.currentSession;

  @override
  Stream<AuthState> get onAuthStateChange => _connection.authStateChanges;

  @override
  Future<bool> sendOtp(String phone) async {
    final client = _requireClient();
    await client.auth.signInWithOtp(phone: phone).timeout(_timeout);
    return true;
  }

  @override
  Future<void> verifyOtp(String phone, String otp) async {
    final client = _requireClient();
    final response = await client.auth
        .verifyOTP(type: OtpType.sms, phone: phone, token: otp)
        .timeout(_timeout);

    if (response.session == null) {
      throw const AuthException('Invalid OTP. Please try again.');
    }
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

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';

/// Authentication gateway using WhatsApp Cloud API for OTP delivery.
///
/// OTP send/verify is handled by the `whatsapp-otp` Edge Function,
/// which sends OTPs via the WhatsApp Business Cloud API (template: gikundiro)
/// and creates Supabase Auth sessions on successful verification.
abstract class AuthGateway {
  bool get isInitialized;

  bool get isAuthenticated;

  bool get isAnonymousUser;

  User? get currentUser;

  Session? get currentSession;

  Stream<AuthState> get onAuthStateChange;

  /// Send a 6-digit OTP to [phone] via WhatsApp Cloud API.
  Future<bool> sendOtp(String phone);

  /// Verify the OTP and create a Supabase session.
  /// Returns the session data on success.
  Future<void> verifyOtp(String phone, String otp);

  /// Sign in as an anonymous/guest user.
  Future<AuthResponse> signInAnonymously();

  /// Creates a short-lived claim proving control of the current anonymous user.
  Future<String?> issueAnonymousUpgradeClaim();

  Future<void> signOut();

  Future<bool> isOnboardingCompletedForCurrentUser();

  /// Merge anonymous user data into the authenticated user profile.
  Future<void> mergeAnonymousToAuthenticated(String anonId, String claimToken);
}

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._connection);

  final SupabaseConnection _connection;

  static const _timeout = Duration(seconds: 20);

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

    final response = await client.functions
        .invoke('whatsapp-otp', body: {'action': 'send', 'phone': phone})
        .timeout(_timeout);

    final data = response.data as Map<String, dynamic>? ?? {};

    if (data['success'] == true) {
      return true;
    }

    final errorMsg =
        data['error'] as String? ?? 'Failed to send OTP. Please try again.';
    throw AuthException(errorMsg);
  }

  @override
  Future<void> verifyOtp(String phone, String otp) async {
    final client = _requireClient();

    final response = await client.functions
        .invoke(
          'whatsapp-otp',
          body: {'action': 'verify', 'phone': phone, 'otp': otp},
        )
        .timeout(const Duration(seconds: 30));

    final data = response.data as Map<String, dynamic>? ?? {};

    if (data['success'] != true) {
      final errorMsg =
          data['error'] as String? ?? 'Verification failed. Please try again.';
      throw AuthException(errorMsg);
    }

    final accessToken = data['access_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;

    if (accessToken == null) {
      throw const AuthException(
        'Server did not return a valid session. Please try again.',
      );
    }

    try {
      final sessionSeed = refreshToken != null && refreshToken.isNotEmpty
          ? refreshToken
          : accessToken;

      // The custom WhatsApp auth flow issues an access token directly. The
      // Supabase Flutter client still expects a non-empty refresh token when
      // restoring local session state, so we reuse the access token as a
      // compatibility seed until the short-lived session expires.
      await client.auth.setSession(sessionSeed, accessToken: accessToken);
    } catch (error) {
      AppLogger.d(
        'Failed to recover session from WhatsApp OTP response: $error',
      );
      throw const AuthException(
        'Server returned an invalid session. Please try again.',
      );
    }
  }

  @override
  Future<AuthResponse> signInAnonymously() async {
    final client = _requireClient();
    final response = await client.auth.signInAnonymously().timeout(_timeout);

    if (response.session == null) {
      throw const AuthException(
        'Could not create guest session. Please try again.',
      );
    }

    return response;
  }

  @override
  Future<String?> issueAnonymousUpgradeClaim() async {
    final client = _requireClient();
    final result = await client
        .rpc('issue_anonymous_upgrade_claim')
        .timeout(_timeout);
    if (result is String && result.isNotEmpty) return result;
    return null;
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
    String claimToken,
  ) async {
    final client = _requireClient();
    await client
        .rpc(
          'merge_anonymous_to_authenticated_secure',
          params: {'p_anon_id': anonId, 'p_claim_token': claimToken},
        )
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

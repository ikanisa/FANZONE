import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logging/app_logger.dart';
import '../features/auth/data/auth_gateway.dart';

/// Authentication service wrapping the feature gateway.
class AuthService {
  AuthService(this._gateway);

  final AuthGateway _gateway;

  bool get isAvailable => _gateway.isInitialized;

  User? get currentUser => _gateway.currentUser;

  Session? get currentSession => _gateway.currentSession;

  bool get isAuthenticated => _gateway.isAuthenticated;

  /// Whether the current user is an anonymous/guest user.
  bool get isAnonymousUser => _gateway.isAnonymousUser;

  /// Whether the current user is fully authenticated (non-anonymous).
  bool get isFullyAuthenticated =>
      _gateway.isAuthenticated && !_gateway.isAnonymousUser;

  Future<bool> sendOtp(String phone) async {
    try {
      return await _gateway.sendOtp(phone);
    } on AuthException {
      rethrow;
    } catch (error) {
      AppLogger.d('sendOtp error: $error');
      rethrow;
    }
  }

  Future<void> verifyOtp(String phone, String otp) async {
    try {
      await _gateway.verifyOtp(phone, otp);
    } on AuthException {
      rethrow;
    } catch (error) {
      AppLogger.d('verifyOtp error: $error');
      rethrow;
    }
  }

  /// Sign in as an anonymous/guest user via Supabase anonymous auth.
  Future<AuthResponse> signInAnonymously() async {
    try {
      return await _gateway.signInAnonymously();
    } on AuthException {
      rethrow;
    } catch (error) {
      AppLogger.d('signInAnonymously error: $error');
      rethrow;
    }
  }

  Future<String?> issueAnonymousUpgradeClaim() async {
    try {
      return await _gateway.issueAnonymousUpgradeClaim();
    } on AuthException {
      rethrow;
    } catch (error) {
      AppLogger.d('issueAnonymousUpgradeClaim error: $error');
      rethrow;
    }
  }

  Future<bool> refreshSession() async {
    try {
      return await _gateway.refreshSession();
    } on AuthException {
      rethrow;
    } catch (error) {
      AppLogger.d('refreshSession error: $error');
      return false;
    }
  }

  /// Merge anonymous user data into authenticated user after OTP upgrade.
  Future<void> mergeAnonymousToAuthenticated(
    String anonId,
    String claimToken,
  ) async {
    try {
      await _gateway.mergeAnonymousToAuthenticated(anonId, claimToken);
    } catch (error) {
      AppLogger.d('mergeAnonymousToAuthenticated error: $error');
      // Don't rethrow — merge failure should not block the upgrade
    }
  }

  Future<void> signOut() => _gateway.signOut();

  Stream<AuthState> get onAuthStateChange => _gateway.onAuthStateChange;
}

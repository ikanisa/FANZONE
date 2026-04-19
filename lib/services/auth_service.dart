import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logging/app_logger.dart';
import '../features/auth/data/auth_gateway.dart';

/// Authentication service wrapping the feature gateway.
class AuthService {
  AuthService(this._gateway);

  final AuthGateway _gateway;

  bool get isAvailable => _gateway.isInitialized;

  User? get currentUser => _gateway.currentUser;

  bool get isAuthenticated => _gateway.isAuthenticated;

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

  Future<void> signOut() => _gateway.signOut();

  Stream<AuthState> get onAuthStateChange => _gateway.onAuthStateChange;
}

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../main.dart' show supabaseInitialized;

/// Auth service provider.
final authServiceProvider = Provider<AuthService>((ref) {
  final client = supabaseInitialized ? Supabase.instance.client : null;
  return AuthService(client);
});

/// Stream of auth state changes (login, logout, token refresh).
final authStateProvider = StreamProvider<AuthState?>((ref) {
  final service = ref.watch(authServiceProvider);
  final stream = service.onAuthStateChange;
  if (stream == null) return const Stream.empty();
  return stream;
});

/// Current authenticated user (null if not signed in).
final currentUserProvider = Provider<User?>((ref) {
  // Watch the auth state stream to reactively update
  ref.watch(authStateProvider);
  final service = ref.read(authServiceProvider);
  return service.currentUser;
});

/// Simple boolean — is the user authenticated?
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

/// Detects session expiry — true when user was previously authenticated
/// but lost their session (e.g. JWT expired and refresh failed).
final sessionExpiredProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(
        data: (state) {
          if (state == null) return false;
          // If we get a SIGNED_OUT event but the app thinks user was logged in
          // that typically means the session expired.
          return state.event == AuthChangeEvent.signedOut;
        },
      ) ??
      false;
});

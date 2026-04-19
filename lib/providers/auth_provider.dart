import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/di/gateway_providers.dart';
import '../services/auth_service.dart';

enum AuthExitIntent { none, manualSignOut }

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(authGatewayProvider));
});

final authExitIntentProvider = StateProvider<AuthExitIntent>((ref) {
  return AuthExitIntent.none;
});

final authStateProvider = StreamProvider<AuthState?>((ref) {
  final stream = ref.watch(authServiceProvider).onAuthStateChange;
  return stream.map((state) {
    final event = state.event;
    if (event == AuthChangeEvent.initialSession ||
        event == AuthChangeEvent.signedIn ||
        event == AuthChangeEvent.tokenRefreshed ||
        event == AuthChangeEvent.userUpdated) {
      ref.read(authExitIntentProvider.notifier).state = AuthExitIntent.none;
    }
    return state;
  });
});

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return ref.read(authServiceProvider).currentUser;
});

/// True when any session exists (anonymous or phone-verified).
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

/// True when the current user is an anonymous/guest user.
final isGuestProvider = Provider<bool>((ref) {
  ref.watch(authStateProvider);
  return ref.read(authServiceProvider).isAnonymousUser;
});

/// True only when the user is fully authenticated (non-anonymous).
final isFullyAuthenticatedProvider = Provider<bool>((ref) {
  final isAuth = ref.watch(isAuthenticatedProvider);
  final isGuest = ref.watch(isGuestProvider);
  return isAuth && !isGuest;
});

final sessionExpiredProvider = Provider<bool>((ref) {
  final exitIntent = ref.watch(authExitIntentProvider);
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(
        data: (state) =>
            state?.event == AuthChangeEvent.signedOut &&
            exitIntent != AuthExitIntent.manualSignOut,
      ) ??
      false;
});

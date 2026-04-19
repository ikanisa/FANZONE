import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/di/injection.dart';
import '../features/auth/data/auth_gateway.dart';
import '../services/auth_service.dart';

enum AuthExitIntent { none, manualSignOut }

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(getIt<AuthGateway>());
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

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
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

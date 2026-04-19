import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/di/injection.dart';
import '../features/auth/data/auth_gateway.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(getIt<AuthGateway>());
});

final authStateProvider = StreamProvider<AuthState?>((ref) {
  final stream = ref.watch(authServiceProvider).onAuthStateChange;
  return stream;
});

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return ref.read(authServiceProvider).currentUser;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

final sessionExpiredProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(
        data: (state) => state?.event == AuthChangeEvent.signedOut,
      ) ??
      false;
});

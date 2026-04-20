import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/runtime_auth_session_manager.dart';
import '../runtime/app_runtime_state.dart';

abstract class SupabaseConnection {
  bool get isInitialized;

  SupabaseClient? get client;

  User? get currentUser;

  Session? get currentSession;

  bool get isAuthenticated;

  Stream<AuthState> get authStateChanges;
}

class SupabaseConnectionImpl implements SupabaseConnection {
  @override
  bool get isInitialized => appRuntime.supabaseInitialized;

  @override
  SupabaseClient? get client {
    if (!appRuntime.supabaseInitialized) {
      return null;
    }

    final manager = RuntimeAuthSessionManager.instance;
    final customSession = manager.customSession;
    if (customSession != null && customSession.isExpired) {
      return null;
    }

    return manager.activeClient;
  }

  @override
  User? get currentUser {
    final session = currentSession;
    if (session == null || session.isExpired) {
      return null;
    }
    return RuntimeAuthSessionManager.instance.currentUser;
  }

  @override
  Session? get currentSession => RuntimeAuthSessionManager.instance.currentSession;

  @override
  bool get isAuthenticated {
    final session = currentSession;
    return session != null && !session.isExpired;
  }

  @override
  Stream<AuthState> get authStateChanges =>
      appRuntime.supabaseInitialized
          ? RuntimeAuthSessionManager.instance.authStateChanges
          : const Stream<AuthState>.empty();
}

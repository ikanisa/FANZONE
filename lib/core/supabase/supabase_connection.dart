import 'package:supabase_flutter/supabase_flutter.dart';

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
  SupabaseClient? get client =>
      appRuntime.supabaseInitialized ? Supabase.instance.client : null;

  @override
  User? get currentUser => client?.auth.currentUser;

  @override
  Session? get currentSession => client?.auth.currentSession;

  @override
  bool get isAuthenticated {
    final session = currentSession;
    return session != null && !session.isExpired;
  }

  @override
  Stream<AuthState> get authStateChanges =>
      client?.auth.onAuthStateChange ?? const Stream<AuthState>.empty();
}

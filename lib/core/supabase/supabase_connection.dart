import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart' show supabaseInitialized;

abstract class SupabaseConnection {
  bool get isInitialized;

  SupabaseClient? get client;

  User? get currentUser;

  Session? get currentSession;

  bool get isAuthenticated;

  Stream<AuthState> get authStateChanges;
}

@LazySingleton(as: SupabaseConnection)
class SupabaseConnectionImpl implements SupabaseConnection {
  @override
  bool get isInitialized => supabaseInitialized;

  @override
  SupabaseClient? get client =>
      supabaseInitialized ? Supabase.instance.client : null;

  @override
  User? get currentUser => client?.auth.currentUser;

  @override
  Session? get currentSession => client?.auth.currentSession;

  @override
  bool get isAuthenticated => currentSession != null;

  @override
  Stream<AuthState> get authStateChanges =>
      client?.auth.onAuthStateChange ?? const Stream<AuthState>.empty();
}

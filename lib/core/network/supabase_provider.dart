import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/injection.dart';
import '../supabase/supabase_connection.dart';

/// Provides the Supabase client (or null if not yet initialised).
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  return getIt<SupabaseConnection>().client;
});

/// Convenience getter for the current authenticated user ID.
String? currentUserId(SupabaseClient? client) => client?.auth.currentUser?.id;

/// Whether the user is authenticated.
bool isAuthenticated(SupabaseClient? client) =>
    client?.auth.currentSession != null;

/// Standard request timeout for all Supabase queries.
const supabaseTimeout = Duration(seconds: 15);

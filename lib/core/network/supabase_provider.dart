import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/gateway_providers.dart';
import '../supabase/supabase_connection.dart';

/// Provides the Supabase client (or null if not yet initialised).
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  return ref.read(supabaseConnectionProvider).client;
});

/// Convenience getter for the current authenticated user ID.
String? currentUserId(SupabaseClient? client) =>
    SupabaseConnectionImpl().currentUser?.id;

/// Whether the user is authenticated.
bool isAuthenticated(SupabaseClient? client) =>
    SupabaseConnectionImpl().isAuthenticated;

/// Standard request timeout for all Supabase queries.
const supabaseTimeout = Duration(seconds: 15);

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'config/app_config.dart';
import 'core/logging/app_logger.dart';
import 'firebase_options.dart';
import 'services/app_telemetry.dart';

/// Whether Supabase was successfully initialized.
/// Checked by services to avoid accessing an uninitialized client.
bool supabaseInitialized = false;

/// Human-readable initialization error, if any.
String? supabaseInitError;

/// Router refresh token that reacts to login, logout, and token refresh events.
final ValueNotifier<int> authStateVersion = ValueNotifier<int>(0);

/// Completes when Supabase init finishes (success or failure).
/// Splash screen awaits this instead of a fixed timer.
Completer<void> supabaseInitCompleter = Completer<void>();
StreamSubscription<AuthState>? _authStateSubscription;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock portrait mode for mobile-first UX
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await AppTelemetry.init(
    bootstrap: _initializeServices,
    runApp: () => runApp(const ProviderScope(child: FanzoneApp())),
  );
}

Future<void> _initializeServices() async {
  supabaseInitError = null;

  // Initialize Firebase (FCM, Analytics) — always, regardless of Supabase config.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppLogger.d('Firebase initialized');
  } catch (e) {
    AppLogger.d('Firebase init failed: $e');
  }

  if (!AppConfig.hasSupabaseConfig) {
    supabaseInitError =
        'Supabase credentials are missing. Pass SUPABASE_URL and SUPABASE_ANON_KEY with --dart-define or --dart-define-from-file.';
    AppLogger.d('Missing build-time Supabase configuration');
    _completeSupabaseInit();
    return;
  }

  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
    supabaseInitialized = true;
    authStateVersion.value++;
    await _authStateSubscription?.cancel();
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange
        .listen((_) => authStateVersion.value++);
  } catch (error, stackTrace) {
    supabaseInitError = 'Could not connect to server.';
    await AppTelemetry.captureException(
      error,
      stackTrace,
      reason: 'supabase_initialize_failed',
    );
  } finally {
    // Always complete — splash screen is waiting
    _completeSupabaseInit();
  }
}

Future<void> retrySupabaseInitialization() async {
  if (supabaseInitialized) return;
  if (supabaseInitCompleter.isCompleted) {
    supabaseInitCompleter = Completer<void>();
  }
  await _initializeServices();
}

void _completeSupabaseInit() {
  if (!supabaseInitCompleter.isCompleted) {
    supabaseInitCompleter.complete();
  }
}

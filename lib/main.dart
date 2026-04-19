import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'core/di/injection.dart';
import 'core/logging/app_logger.dart';
import 'core/performance/app_startup.dart';
import 'core/storage/structured_cache_store.dart';
import 'firebase_options.dart';
import 'features/auth/data/auth_gateway.dart';
import 'services/app_telemetry.dart';
import 'services/product_analytics_service.dart';

/// Whether Supabase was successfully initialized.
/// Checked by services to avoid accessing an uninitialized client.
bool supabaseInitialized = false;
bool firebaseInitialized = false;

/// Human-readable initialization error, if any.
String? supabaseInitError;

/// Router refresh token that reacts to login, logout, and token refresh events.
final ValueNotifier<int> authStateVersion = ValueNotifier<int>(0);

/// Completes when Supabase init finishes (success or failure).
/// Splash screen awaits this instead of a fixed timer.
Completer<void> supabaseInitCompleter = Completer<void>();
Completer<void> firebaseInitCompleter = Completer<void>();
StreamSubscription<AuthState>? _authStateSubscription;
final appStartupProfiler = AppStartupProfiler();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  appStartupProfiler.mark('bindings_ready');
  appStartupProfiler.attachFrameHooks(WidgetsBinding.instance);

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  appStartupProfiler.mark('orientation_locked');

  final startup = AppStartupCoordinator(
    profiler: appStartupProfiler,
    beforeRunApp: () async {
      await Future.wait<void>([
        StructuredCacheStore.init(),
        configureDependencies(),
      ]);
      appStartupProfiler.mark('structured_cache_ready');
      appStartupProfiler.mark('dependencies_ready');
    },
    critical: _initializeCriticalServices,
    deferred: _initializeDeferredServices,
  );

  await startup.prepare();
  runApp(const ProviderScope(child: FanzoneApp()));
  startup.start();
}

Future<void> _initializeCriticalServices() async {
  await _initializeSupabase();
}

Future<void> _initializeDeferredServices() async {
  await Future.wait<void>([_initializeFirebase(), AppTelemetry.start()]);
  if (supabaseInitialized) {
    ProductAnalytics.initialize();
  }
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseInitialized = true;
    appStartupProfiler.mark('firebase_ready');
    AppLogger.d('Firebase initialized');
  } catch (e) {
    AppLogger.d('Firebase init failed: $e');
  } finally {
    _completeFirebaseInit();
  }
}

Future<void> _initializeSupabase() async {
  supabaseInitError = null;

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
    appStartupProfiler.mark('supabase_ready');
    authStateVersion.value++;
    await _authStateSubscription?.cancel();
    _authStateSubscription = getIt<AuthGateway>().onAuthStateChange.listen(
      (_) => authStateVersion.value++,
    );
  } catch (error, stackTrace) {
    supabaseInitError = 'Could not connect to server.';
    await AppTelemetry.captureException(
      error,
      stackTrace,
      reason: 'supabase_initialize_failed',
    );
  } finally {
    _completeSupabaseInit();
  }
}

Future<void> retrySupabaseInitialization() async {
  if (supabaseInitialized) return;
  if (supabaseInitCompleter.isCompleted) {
    supabaseInitCompleter = Completer<void>();
  }
  await _initializeSupabase();
}

void _completeSupabaseInit() {
  if (!supabaseInitCompleter.isCompleted) {
    supabaseInitCompleter.complete();
  }
}

void _completeFirebaseInit() {
  if (!firebaseInitCompleter.isCompleted) {
    firebaseInitCompleter.complete();
  }
}

void markAppInteractive() {
  appStartupProfiler.mark('app_interactive');
  AppLogger.d('Startup summary: ${appStartupProfiler.summary()}');
}

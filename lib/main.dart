import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'core/di/gateway_providers.dart';
import 'core/logging/app_logger.dart';
import 'core/performance/app_startup.dart';
import 'core/runtime/app_runtime_state.dart';
import 'core/storage/structured_cache_store.dart';
import 'firebase_options.dart';
import 'services/app_telemetry.dart';
import 'services/product_analytics_service.dart';

StreamSubscription<AuthState>? _authStateSubscription;
List<Override> _providerOverrides = const [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    AppTelemetry.captureException(
      error,
      stackTrace,
      reason: 'platform_dispatcher_error',
    );
    return false;
  };
  appStartupProfiler.mark('bindings_ready');
  appStartupProfiler.attachFrameHooks(WidgetsBinding.instance);

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  appStartupProfiler.mark('orientation_locked');

  final startup = AppStartupCoordinator(
    profiler: appStartupProfiler,
    beforeRunApp: () async {
      await Future.wait<void>([
        StructuredCacheStore.init(),
        resolveAsyncOverrides().then((o) => _providerOverrides = o),
      ]);
      appRuntime.retrySupabaseInitialization = retrySupabaseInitialization;
      appStartupProfiler.mark('structured_cache_ready');
      appStartupProfiler.mark('dependencies_ready');
    },
    critical: _initializeCriticalServices,
    deferred: _initializeDeferredServices,
  );

  await startup.prepare();
  runApp(ProviderScope(overrides: _providerOverrides, child: const FanzoneApp()));
  startup.start();
}

Future<void> _initializeCriticalServices() async {
  await _initializeSupabase();
}

Future<void> _initializeDeferredServices() async {
  await Future.wait<void>([_initializeFirebase(), AppTelemetry.start()]);
  if (appRuntime.supabaseInitialized) {
    ProductAnalytics.initialize();
  }
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    appRuntime.firebaseInitialized = true;
    appStartupProfiler.mark('firebase_ready');
    AppLogger.d('Firebase initialized');
  } catch (e) {
    AppLogger.d('Firebase init failed: $e');
  } finally {
    appRuntime.completeFirebaseReady();
  }
}

Future<void> _initializeSupabase() async {
  appRuntime.supabaseInitError = null;

  if (!AppConfig.hasSupabaseConfig) {
    appRuntime.supabaseInitError =
        'Supabase credentials are missing. Pass SUPABASE_URL and SUPABASE_ANON_KEY with --dart-define or --dart-define-from-file.';
    AppLogger.d('Missing build-time Supabase configuration');
    appRuntime.completeSupabaseReady();
    return;
  }

  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
    appRuntime.supabaseInitialized = true;
    appStartupProfiler.mark('supabase_ready');
    appRuntime.notifyAuthStateChanged();
    await _authStateSubscription?.cancel();
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      appRuntime.notifyAuthStateChanged();
      unawaited(ProductAnalytics.flush());
      unawaited(AppTelemetry.flush());
    });
  } catch (error, stackTrace) {
    appRuntime.supabaseInitError = 'Could not connect to server.';
    await AppTelemetry.captureException(
      error,
      stackTrace,
      reason: 'supabase_initialize_failed',
    );
  } finally {
    appRuntime.completeSupabaseReady();
  }
}

Future<void> retrySupabaseInitialization() async {
  if (appRuntime.supabaseInitialized) return;
  appRuntime.resetSupabaseReady();
  await _initializeSupabase();
}

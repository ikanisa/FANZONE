import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'app_router.dart';
import 'config/app_config.dart';
import 'core/auth/runtime_auth_session_manager.dart';
import 'core/di/gateway_providers.dart';
import 'core/logging/app_logger.dart';
import 'core/runtime/app_runtime_state.dart';
import 'core/storage/structured_cache_store.dart';
import 'services/app_telemetry.dart';
import 'shells/web_review_shell.dart';
import 'theme/colors.dart';

StreamSubscription<AuthState>? _authStateSubscription;

Future<void> main() async {
  AppConfig.runtimeModeOverride = AppRuntimeMode.webReview;
  WidgetsFlutterBinding.ensureInitialized();
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    AppTelemetry.captureException(
      error,
      stackTrace,
      reason: 'review_platform_dispatcher_error',
    );
    return false;
  };

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: FzColors.darkBg,
      systemNavigationBarDividerColor: FzColors.darkBg,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await StructuredCacheStore.init();
  final providerOverrides = await resolveAsyncOverrides();
  appRuntime.retrySupabaseInitialization = _initializeSupabase;
  await _initializeSupabase();
  appRuntime.completeFirebaseReady();

  initializeRouter(initialRoute: '/splash');

  runApp(
    ProviderScope(
      overrides: providerOverrides,
      child: FanzoneApp(
        shellBuilder: (context, child) => WebReviewShell(child: child),
      ),
    ),
  );
}

Future<void> _initializeSupabase() async {
  appRuntime.supabaseInitError = null;

  if (!AppConfig.hasSupabaseConfig) {
    appRuntime.supabaseInitError =
        'Supabase credentials are missing. Review comments will use local fallback storage.';
    AppLogger.d('Review mode started without Supabase configuration');
    appRuntime.completeSupabaseReady();
    return;
  }

  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    ).timeout(const Duration(seconds: 15));
    appRuntime.supabaseInitialized = true;
    await RuntimeAuthSessionManager.instance.initialize();
    appRuntime.notifyAuthStateChanged();
    await _authStateSubscription?.cancel();
    _authStateSubscription = RuntimeAuthSessionManager.instance.authStateChanges
        .listen((_) {
          appRuntime.notifyAuthStateChanged();
          unawaited(refreshRuntimeBootstrapData());
        });
    await refreshRuntimeBootstrapData();
  } catch (error, stackTrace) {
    appRuntime.supabaseInitError = 'Could not connect to review backend.';
    await AppTelemetry.captureException(
      error,
      stackTrace,
      reason: 'review_supabase_initialize_failed',
    );
  } finally {
    appRuntime.completeSupabaseReady();
  }
}

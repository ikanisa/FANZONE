import 'dart:async';

import 'package:flutter/material.dart';

import '../logging/app_logger.dart';
import '../performance/app_startup.dart';

class AppRuntimeState {
  bool supabaseInitialized = false;
  bool firebaseInitialized = false;
  String? supabaseInitError;
  bool isAppInteractive = false;

  final ValueNotifier<bool> isOffline = ValueNotifier<bool>(false);
  final ValueNotifier<int> authStateVersion = ValueNotifier<int>(0);
  final ValueNotifier<String?> pendingAppRoute = ValueNotifier<String?>(null);

  Completer<void> _supabaseInitCompleter = Completer<void>();
  final Completer<void> _firebaseInitCompleter = Completer<void>();

  Future<void> Function()? retrySupabaseInitialization;

  Future<void> get supabaseReady => _supabaseInitCompleter.future;
  Future<void> get firebaseReady => _firebaseInitCompleter.future;

  void notifyAuthStateChanged() {
    authStateVersion.value++;
  }

  void resetSupabaseReady() {
    if (_supabaseInitCompleter.isCompleted) {
      _supabaseInitCompleter = Completer<void>();
    }
  }

  void completeSupabaseReady() {
    if (!_supabaseInitCompleter.isCompleted) {
      _supabaseInitCompleter.complete();
    }
  }

  void completeFirebaseReady() {
    if (!_firebaseInitCompleter.isCompleted) {
      _firebaseInitCompleter.complete();
    }
  }

  void queuePendingAppRoute(String route) {
    pendingAppRoute.value = route;
  }

  String? consumePendingAppRoute() {
    final nextRoute = pendingAppRoute.value;
    pendingAppRoute.value = null;
    return nextRoute;
  }
}

final appRuntime = AppRuntimeState();
final appStartupProfiler = AppStartupProfiler();

void markAppInteractive() {
  appRuntime.isAppInteractive = true;
  appStartupProfiler.mark('app_interactive');
  AppLogger.d('Startup summary: ${appStartupProfiler.summary()}');
}

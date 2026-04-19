import 'dart:async';

import 'package:flutter/material.dart';

import '../logging/app_logger.dart';
import '../performance/app_startup.dart';

class AppRuntimeState {
  bool supabaseInitialized = false;
  bool firebaseInitialized = false;
  String? supabaseInitError;

  final ValueNotifier<int> authStateVersion = ValueNotifier<int>(0);

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
}

final appRuntime = AppRuntimeState();
final appStartupProfiler = AppStartupProfiler();

void markAppInteractive() {
  appStartupProfiler.mark('app_interactive');
  AppLogger.d('Startup summary: ${appStartupProfiler.summary()}');
}

import 'package:flutter/foundation.dart';

/// Centralized logging utility.
///
/// All log calls are suppressed in release builds via [kDebugMode].
/// Replaces scattered `debugPrint` calls to ensure nothing leaks in production.
abstract final class AppLogger {
  /// Debug-level log — development only.
  static void d(String message) {
    if (kDebugMode) debugPrint('[FANZONE] $message');
  }

  /// Warning-level log — development only.
  static void w(String message) {
    if (kDebugMode) debugPrint('[FANZONE ⚠] $message');
  }

  /// Error-level log — development only.
  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[FANZONE ✗] $message');
      if (error != null) debugPrint('  Error: $error');
      if (stackTrace != null) debugPrint('  $stackTrace');
    }
  }
}

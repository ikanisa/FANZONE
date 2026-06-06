import 'package:flutter/foundation.dart';

/// Centralized logging utility.
///
/// All log calls are suppressed in release builds via [kDebugMode].
/// Replaces scattered `debugPrint` calls to ensure nothing leaks in production.
abstract final class AppLogger {
  static final List<RegExp> _secretPatterns = [
    RegExp(r'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}'),
    RegExp(r'sbp_[A-Za-z0-9_-]{20,}'),
    RegExp(r'postgresql:\/\/[^:\s]+:[^@\s]+@[^\s]+'),
    RegExp(
      r'(Authorization\s*[:=]\s*Bearer\s+)[A-Za-z0-9._~+/=-]+',
      caseSensitive: false,
    ),
    RegExp(
      r'((password|secret|service[_-]?role|token)\s*[:=]\s*)[^\s,;)}]+',
      caseSensitive: false,
    ),
  ];

  static final List<RegExp> _backendPayloadPatterns = [
    RegExp(r'PostgrestException\([^)]*\)', caseSensitive: false),
  ];

  static String sanitizeForLog(Object? value) {
    if (value == null) return '';
    var output = value.toString();
    for (final pattern in _backendPayloadPatterns) {
      output = output.replaceAll(pattern, '[backend-error]');
    }
    for (final pattern in _secretPatterns) {
      output = output.replaceAllMapped(pattern, (match) {
        final prefix = match.groupCount >= 1 ? match.group(1) : null;
        return prefix == null ? '[redacted]' : '$prefix[redacted]';
      });
    }
    return output;
  }

  /// Debug-level log — development only.
  static void d(String message) {
    if (kDebugMode) debugPrint('[FANZONE] ${sanitizeForLog(message)}');
  }

  /// Warning-level log — development only.
  static void w(String message) {
    if (kDebugMode) debugPrint('[FANZONE ⚠] ${sanitizeForLog(message)}');
  }

  /// Error-level log — development only.
  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[FANZONE ✗] ${sanitizeForLog(message)}');
      if (error != null) debugPrint('  Error: ${sanitizeForLog(error)}');
      if (stackTrace != null) {
        debugPrint('  ${sanitizeForLog(stackTrace)}');
      }
    }
  }
}

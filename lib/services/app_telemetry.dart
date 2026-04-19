import '../core/logging/app_logger.dart';

/// Centralized error capture — logs errors locally.
/// No external crash reporting service is used.
class AppTelemetry {
  static Future<void> start() async {
    // No-op: no external crash reporting service.
  }

  static Future<void> captureException(
    Object error,
    StackTrace stackTrace, {
    String? reason,
  }) async {
    AppLogger.d('${reason ?? 'Captured error'}: $error');
  }
}

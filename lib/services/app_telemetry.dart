import 'package:sentry_flutter/sentry_flutter.dart';
import '../core/logging/app_logger.dart';
import '../config/app_config.dart';

/// Centralized crash reporting bootstrap.
class AppTelemetry {
  static bool _initialized = false;
  static final List<({Object error, StackTrace stackTrace, String? reason})>
  _pending = [];

  static Future<void> init({
    required Future<void> Function() bootstrap,
    required void Function() runApp,
  }) async {
    await bootstrap();

    if (!AppConfig.hasSentry) {
      runApp();
      return;
    }

    await SentryFlutter.init((options) {
      options.dsn = AppConfig.sentryDsn;
      options.environment = AppConfig.environmentName;
      options.enableAutoSessionTracking = true;
      options.attachViewHierarchy = true;
      options.tracesSampleRate = AppConfig.isProduction ? 0.1 : 1.0;
    }, appRunner: runApp);

    _initialized = true;
    for (final pending in _pending) {
      await _sendToSentry(
        pending.error,
        pending.stackTrace,
        reason: pending.reason,
      );
    }
    _pending.clear();
  }

  static Future<void> captureException(
    Object error,
    StackTrace stackTrace, {
    String? reason,
  }) async {
    AppLogger.d('${reason ?? 'Captured error'}: $error');

    if (!AppConfig.hasSentry) {
      return;
    }

    if (!_initialized) {
      _pending.add((error: error, stackTrace: stackTrace, reason: reason));
      return;
    }

    await _sendToSentry(error, stackTrace, reason: reason);
  }

  static Future<void> _sendToSentry(
    Object error,
    StackTrace stackTrace, {
    String? reason,
  }) async {
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        if (reason != null) {
          scope.setTag('reason', reason);
        }
        scope.setTag('environment', AppConfig.environmentName);
      },
    );
  }
}

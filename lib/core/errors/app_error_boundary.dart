import 'package:flutter/material.dart';

import '../../services/app_telemetry.dart';
import '../../theme/colors.dart';
import '../../widgets/common/fz_brand_logo.dart';

class AppErrorBoundary extends StatefulWidget {
  const AppErrorBoundary({super.key, required this.child});

  final Widget child;

  @override
  State<AppErrorBoundary> createState() => _AppErrorBoundaryState();
}

class _AppErrorBoundaryState extends State<AppErrorBoundary> {
  void Function(FlutterErrorDetails details)? _previousOnError;
  ErrorWidgetBuilder? _previousErrorBuilder;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _previousOnError = FlutterError.onError;
    _previousErrorBuilder = ErrorWidget.builder;

    FlutterError.onError = (details) {
      AppTelemetry.captureException(
        details.exception,
        details.stack ?? StackTrace.current,
        reason: 'flutter_framework_error',
      );
      _previousOnError?.call(details);
    };

    ErrorWidget.builder = (details) {
      return _AppBuildFailureView(details: details, onRetry: _resetSubtree);
    };
  }

  @override
  void dispose() {
    FlutterError.onError = _previousOnError;
    if (_previousErrorBuilder != null) {
      ErrorWidget.builder = _previousErrorBuilder!;
    }
    super.dispose();
  }

  void _resetSubtree() {
    if (!mounted) return;
    setState(() => _generation++);
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: ValueKey(_generation), child: widget.child);
  }
}

class _AppBuildFailureView extends StatelessWidget {
  const _AppBuildFailureView({required this.details, required this.onRetry});

  final FlutterErrorDetails details;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? FzColors.darkBg : FzColors.lightBg;
    final surface = isDark ? FzColors.darkSurface : FzColors.lightSurface;
    final text = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Material(
      color: bg,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: FzColors.error.withValues(alpha: 0.22),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FzBrandLogo(width: 52, height: 52, preferCdn: true),
                    const SizedBox(height: 18),
                    Text(
                      'Something broke',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'FANZONE hit an unexpected render error. Retry the screen to continue.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: muted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: FzColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        details.exceptionAsString(),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: muted,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onRetry,
                        style: FilledButton.styleFrom(
                          backgroundColor: FzColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry screen'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

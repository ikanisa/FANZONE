import 'package:flutter/material.dart';

import '../../design_system/components/app_button.dart';
import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_radii.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../design_system/typography/app_typography.dart';
import '../../services/app_telemetry.dart';
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
    return Material(
      color: AppColors.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadii.cardRadius,
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.22),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FzBrandLogo(width: 52, height: 52, preferCdn: true),
                    const SizedBox(height: AppSpacing.xl),
                    const Text(
                      'Something broke',
                      style: AppTypography.cardTitle,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'FANZONE hit an unexpected render error. Retry the screen to continue.',
                      textAlign: TextAlign.center,
                      style: AppTypography.secondary.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: AppRadii.inputRadius,
                      ),
                      child: Text(
                        details.exceptionAsString(),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.secondary.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        label: 'Retry screen',
                        onPressed: onRetry,
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

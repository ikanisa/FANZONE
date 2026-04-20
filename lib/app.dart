import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'core/errors/app_error_boundary.dart';
import 'core/lifecycle/app_lifecycle_observer.dart';
import 'theme/app_theme.dart';
import 'theme/colors.dart';
import 'app_router.dart';
import 'config/app_config.dart';
import 'core/config/feature_flags.dart';
import 'providers/auth_provider.dart';
import 'services/push_notification_service.dart';

/// Root FANZONE application widget.
class FanzoneApp extends ConsumerWidget {
  const FanzoneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(featureFlagsProvider).notifications) {
      ref.watch(pushNotificationInitProvider);
    }

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: FzTheme.dark(),
      darkTheme: FzTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: router,

      // ── i18n ──
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      locale: const Locale('en'), // Default until user can pick

      builder: (context, child) {
        return AppErrorBoundary(
          child: AppLifecycleObserverWidget(
            child: _SessionExpiryGuard(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}

/// Watches [sessionExpiredProvider] and shows a dialog when the session
/// expires, redirecting the user to the login screen.
class _SessionExpiryGuard extends ConsumerStatefulWidget {
  const _SessionExpiryGuard({required this.child});
  final Widget child;

  @override
  ConsumerState<_SessionExpiryGuard> createState() =>
      _SessionExpiryGuardState();
}

class _SessionExpiryGuardState extends ConsumerState<_SessionExpiryGuard> {
  bool _dialogShowing = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(sessionExpiredProvider, (previous, next) {
      if (next && !_dialogShowing && (previous == false || previous == null)) {
        _showSessionExpiredDialog();
      }
    });

    return widget.child;
  }

  void _showSessionExpiredDialog() {
    _dialogShowing = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Session expired'),
        content: const Text(
          'Your session has ended. Please sign in again to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _dialogShowing = false;
              router.go('/login');
            },
            child: const Text(
              'Sign in',
              style: TextStyle(
                color: FzColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ).then((_) => _dialogShowing = false);
  }
}

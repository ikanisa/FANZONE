import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
            onForeground: () => _handleForegroundResume(ref),
            child: _SessionExpiryGuard(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}

void _handleForegroundResume(WidgetRef ref) {
  ref.invalidate(matchRefreshTriggerProvider);

  final session = ref.read(currentSessionProvider);
  if (session != null) return;

  final authService = ref.read(authServiceProvider);
  final currentSession = authService.currentSession;
  if (currentSession == null || !currentSession.isExpired) {
    return;
  }

  ref.read(authExitIntentProvider.notifier).state = AuthExitIntent.none;
  unawaited(authService.signOut());
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
  Timer? _customSessionExpiryTimer;

  @override
  void initState() {
    super.initState();
    _syncCustomSessionExpiryTimer(ref.read(authServiceProvider).currentSession);
  }

  @override
  void dispose() {
    _customSessionExpiryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(sessionExpiredProvider, (previous, next) {
      if (next && !_dialogShowing && (previous == false || previous == null)) {
        _showSessionExpiredDialog();
      }
    });

    ref.listen<Session?>(currentSessionProvider, (previous, next) {
      _syncCustomSessionExpiryTimer(next);
    });

    return widget.child;
  }

  void _syncCustomSessionExpiryTimer(Session? session) {
    _customSessionExpiryTimer?.cancel();
    if (session == null) {
      return;
    }

    final refreshToken = session.refreshToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      return;
    }

    final expiresAt = session.expiresAt;
    if (expiresAt == null) {
      return;
    }

    final remainingMs = expiresAt * 1000 - DateTime.now().millisecondsSinceEpoch;
    final timeoutMs = (remainingMs <= 0 ? 0 : remainingMs + 1000).clamp(
      0,
      2147483647,
    );

    _customSessionExpiryTimer = Timer(Duration(milliseconds: timeoutMs), () {
      if (!mounted || _dialogShowing) {
        return;
      }

      ref.read(authExitIntentProvider.notifier).state = AuthExitIntent.none;
      unawaited(ref.read(authServiceProvider).signOut());
      _showSessionExpiredDialog();
    });
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

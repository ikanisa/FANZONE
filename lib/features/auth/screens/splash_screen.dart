import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/runtime_auth_session_manager.dart';
import '../../../core/cache/shared_preferences_cache_service.dart';
import '../../../core/runtime/app_runtime_state.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_wordmark.dart';

/// Splash screen — logo animation → wait for init → route local-first.
///
/// Onboarding is local-first and no longer blocked behind authentication.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.returnTo, this.venueId, this.venueSlug});

  final String? returnTo;
  final String? venueId;
  final String? venueSlug;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.forward();

    // Wait for real init completion — not a fixed timer
    _waitForInitAndNavigate();
  }

  Future<void> _waitForInitAndNavigate() async {
    await Future.wait<void>([
      Future<void>.delayed(const Duration(milliseconds: 1500)),
      appRuntime.supabaseReady,
    ]);

    if (!mounted) return;
    await _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    final onboardingDone = await _resolveOnboardingState();

    if (!mounted) return;
    final nextRoute = onboardingDone
        ? (_venueRoute() ??
              widget.returnTo ??
              appRuntime.consumePendingAppRoute() ??
              '/home')
        : '/onboarding';
    context.go(nextRoute);
    markAppInteractive();
  }

  String? _venueRoute() {
    final venueSlug = widget.venueSlug?.trim();
    if (venueSlug != null && venueSlug.isNotEmpty) {
      return '/v/$venueSlug';
    }

    final venueId = widget.venueId?.trim();
    if (venueId != null && venueId.isNotEmpty) {
      return '/bar?v=${Uri.encodeQueryComponent(venueId)}';
    }

    return null;
  }

  Future<bool> _resolveOnboardingState() async {
    final cache = SharedPreferencesCacheService.global;
    final cached = await cache.getBool('onboarding_complete') ?? false;

    if (!appRuntime.supabaseInitialized) {
      return cached;
    }

    final session = RuntimeAuthSessionManager.instance.currentSession;
    final user = RuntimeAuthSessionManager.instance.currentUser;
    if (session == null || user == null || session.isExpired) {
      return cached;
    }

    try {
      final client = RuntimeAuthSessionManager.instance.activeClient;
      if (client == null) {
        return cached;
      }

      final profile = await client
          .from('profiles')
          .select('onboarding_completed')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));
      final remote = profile?['onboarding_completed'] == true;
      if (remote != cached) {
        await cache.setBool('onboarding_complete', remote);
      }
      return remote;
    } catch (_) {
      return cached;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? FzColors.darkBg : FzColors.lightBg,
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: MediaQuery.sizeOf(context).width * 1.2,
              height: MediaQuery.sizeOf(context).width * 1.2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FzColors.primary.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(
                    color: FzColors.primary.withValues(alpha: 0.08),
                    blurRadius: 120,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
            FadeTransition(
              opacity: _fadeIn,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FzWordmark(
                      style: FzTypography.display(
                        size: 58,
                        color: isDark ? FzColors.darkText : FzColors.lightText,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'PLAY . CHEERS . ENJOY',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 12,
                        color: FzColors.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

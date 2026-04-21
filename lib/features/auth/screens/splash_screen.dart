import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/runtime_auth_session_manager.dart';
import '../../../core/cache/shared_preferences_cache_service.dart';
import '../../../core/runtime/app_runtime_state.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_wordmark.dart';

/// Splash screen — logo animation → wait for init → route guest-first.
///
/// Onboarding is local-first and no longer blocked behind authentication.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

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
    context.go(onboardingDone ? '/' : '/onboarding');
    markAppInteractive();
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
                        letterSpacing: 11.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: FzColors.darkSurface2,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: FzColors.darkBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _PulseDot(color: FzColors.primary),
                          const SizedBox(width: 10),
                          Text(
                            'MALTA\'S FOOTBALL FAN NETWORK',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              color: FzColors.darkMuted,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ],
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

/// Pulsing dot matching the reference's `animate-pulse` CSS effect.
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});
  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Opacity(
        opacity: 0.4 + (_ctrl.value * 0.6),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.5 * _ctrl.value),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

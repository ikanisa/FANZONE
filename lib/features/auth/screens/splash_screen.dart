import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/cache/cache_service.dart';
import '../../../core/di/injection.dart';
import '../../../main.dart' show markAppInteractive, supabaseInitCompleter;
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_brand_logo.dart';

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
    // Wait for Supabase init to actually finish
    await supabaseInitCompleter.future;

    // Ensure animation has had at minimum 1.2s to play
    if (_controller.isAnimating) {
      await _controller.forward().orCancel.catchError((_) {});
    }

    if (!mounted) return;
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    final cache = getIt<CacheService>();
    final onboardingDone = await cache.getBool('onboarding_complete') ?? false;

    if (!mounted) return;
    context.go(onboardingDone ? '/' : '/onboarding');
    markAppInteractive();
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
        child: FadeTransition(
          opacity: _fadeIn,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo mark
                const FzBrandLogo(width: 96, height: 96),
                const SizedBox(height: 20),
                Text(
                  'FANZONE',
                  style: FzTypography.score(
                    size: 28,
                    weight: FontWeight.w700,
                    color: isDark ? FzColors.darkText : FzColors.lightText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Football · Predict · Earn',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? FzColors.darkMuted : FzColors.lightMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

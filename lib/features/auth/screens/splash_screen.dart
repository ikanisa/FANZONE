import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../main.dart'
    show supabaseInitialized, supabaseInitCompleter;
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';

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
      duration: const Duration(milliseconds: 1200),
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
    final prefs = await SharedPreferences.getInstance();
    var onboardingDone = prefs.getBool('onboarding_complete') ?? false;

    if (supabaseInitialized) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        try {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('onboarding_completed')
              .eq('id', session.user.id)
              .maybeSingle();

          final remoteCompleted = profile?['onboarding_completed'] == true;
          if (remoteCompleted && !onboardingDone) {
            await prefs.setBool('onboarding_complete', true);
            onboardingDone = true;
          }
        } catch (_) {
          // Keep local onboarding state if the profile lookup fails.
        }
      }
    }

    if (!mounted) return;
    context.go(onboardingDone ? '/' : '/onboarding');
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
                Image.asset(
                  'assets/images/logo.png',
                  width: 96,
                  height: 96,
                ),
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

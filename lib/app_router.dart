import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'config/app_config.dart';
import 'core/auth/runtime_auth_session_manager.dart';
import 'core/accessibility/motion.dart';
import 'core/config/runtime_bootstrap.dart';
import 'core/navigation/analytics_route_observer.dart';
import 'core/runtime/app_runtime_state.dart';
import 'widgets/navigation/app_shell.dart';

import 'features/auth/screens/guest_upgrade_screen.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/whatsapp_login_screen.dart';
import 'features/fixtures/screens/fixtures_screen.dart';
import 'features/home/screens/home_feed_screen.dart';
import 'features/home/screens/league_hub_screen.dart';
import 'features/home/screens/match_detail_screen.dart';
import 'features/leaderboard/screens/leaderboard_screen.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/predict/screens/predict_screen.dart';
import 'features/profile/screens/notifications_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/settings/screens/feature_unavailable_screen.dart';
import 'features/settings/screens/privacy_settings_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/teams/screens/team_profile_canonical_screen.dart';
import 'features/wallet/screens/wallet_screen.dart';

bool _platformFeatureVisible(String key) {
  final feature = runtimeBootstrapStore.config.platformFeature(key);
  if (feature != null) {
    return feature.resolvedState.isOperational &&
        feature.resolvedState.isVisible;
  }
  return runtimeBootstrapStore.config.isFeatureEnabled(
    key,
    defaultValue: false,
  );
}

/// True when any session exists (anonymous or phone-verified).
bool _isAuthenticated() {
  final session = RuntimeAuthSessionManager.instance.currentSession;
  return session != null && !session.isExpired;
}

/// Set by main.dart before runApp() — determined while native splash is visible.
String _initialRoute = '/';

/// Called from main.dart to set the resolved initial route.
void setInitialRoute(String route) {
  _initialRoute = route;
}

final router = GoRouter(
  initialLocation: _initialRoute,
  refreshListenable: Listenable.merge([
    appRuntime.authStateVersion,
    runtimeBootstrapStore,
  ]),
  observers: [AnalyticsRouteObserver()],
  redirect: (context, state) {
    final path = state.uri.path;

    if (path == '/login') {
      if (!_isAuthenticated()) return null;
      final redirectTo = state.uri.queryParameters['from'];
      if (redirectTo != null && redirectTo.startsWith('/')) {
        return redirectTo;
      }
      return '/';
    }

    return null;
  },
  routes: [
    GoRoute(
      name: 'splash',
      path: '/splash',
      pageBuilder: (context, state) =>
          _fadeTransition(state, const SplashScreen()),
    ),
    GoRoute(
      name: 'login',
      path: '/login',
      pageBuilder: (context, state) =>
          _fadeSlideTransition(state, const PhoneLoginScreen()),
    ),
    GoRoute(
      name: 'onboarding',
      path: '/onboarding',
      pageBuilder: (context, state) =>
          _fadeTransition(state, const OnboardingScreen()),
    ),
    GoRoute(
      name: 'upgrade',
      path: '/upgrade',
      pageBuilder: (context, state) => _fadeSlideTransition(
        state,
        GuestUpgradeScreen(
          returnTo: state.uri.queryParameters['from'] != null
              ? Uri.decodeComponent(state.uri.queryParameters['from']!)
              : null,
        ),
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AppShell(
        navigationShell: navigationShell,
        currentLocation: state.uri.path,
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              name: 'home_feed',
              path: '/',
              builder: (context, state) => const HomeFeedScreen(),
              routes: [
                GoRoute(
                  name: 'match_detail',
                  path: 'match/:matchId',
                  pageBuilder: (context, state) => _fadeSlideTransition(
                    state,
                    MatchDetailScreen(
                      matchId: state.pathParameters['matchId']!,
                    ),
                  ),
                ),
                GoRoute(
                  name: 'league_hub',
                  path: 'league/:leagueId',
                  pageBuilder: (context, state) => _fadeSlideTransition(
                    state,
                    LeagueHubScreen(
                      leagueId: state.pathParameters['leagueId']!,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              name: 'fixtures',
              path: '/fixtures',
              builder: (context, state) => const FixturesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              name: 'predict',
              path: '/predict',
              builder: (context, state) =>
                  _platformFeatureVisible('predictions')
                  ? const PredictScreen()
                  : const FeatureUnavailableScreen(featureName: 'Predict'),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              name: 'wallet',
              path: '/wallet',
              builder: (context, state) => _platformFeatureVisible('wallet')
                  ? const WalletScreen()
                  : const FeatureUnavailableScreen(featureName: 'Wallet'),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              name: 'profile',
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
            GoRoute(
              name: 'leaderboard',
              path: '/leaderboard',
              pageBuilder: (context, state) => _fadeSlideTransition(
                state,
                _platformFeatureVisible('leaderboard')
                    ? const LeaderboardScreen()
                    : const FeatureUnavailableScreen(
                        featureName: 'Leaderboard',
                      ),
              ),
            ),
            GoRoute(
              name: 'settings',
              path: '/settings',
              pageBuilder: (context, state) =>
                  _fadeSlideTransition(state, const SettingsScreen()),
            ),
            GoRoute(
              name: 'privacy',
              path: '/privacy',
              pageBuilder: (context, state) =>
                  _fadeSlideTransition(state, const PrivacySettingsScreen()),
            ),
            GoRoute(
              name: 'notifications',
              path: '/notifications',
              pageBuilder: (context, state) => _fadeSlideTransition(
                state,
                _platformFeatureVisible('notifications')
                    ? const NotificationsScreen()
                    : const FeatureUnavailableScreen(
                        featureName: 'Notifications',
                      ),
              ),
            ),
            GoRoute(
              name: 'team_profile',
              path: '/team/:teamId',
              pageBuilder: (context, state) => _fadeSlideTransition(
                state,
                TeamProfileScreen(teamId: state.pathParameters['teamId']!),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);

CustomTransitionPage<void> _fadeSlideTransition(
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (prefersReducedMotion(context)) {
        return child;
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

CustomTransitionPage<void> _fadeTransition(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 400),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (prefersReducedMotion(context)) {
        return child;
      }
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

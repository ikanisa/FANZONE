import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'config/app_config.dart';
import 'core/auth/runtime_auth_session_manager.dart';
import 'core/accessibility/motion.dart';
import 'core/navigation/analytics_route_observer.dart';
import 'core/runtime/app_runtime_state.dart';
import 'widgets/navigation/app_shell.dart';

import 'features/auth/screens/guest_upgrade_screen.dart';
import 'features/auth/screens/whatsapp_login_screen.dart';
import 'features/community/screens/membership_hub_screen.dart';
import 'features/fixtures/screens/fixtures_screen.dart';
import 'features/home/screens/home_feed_screen.dart';
import 'features/home/screens/league_hub_screen.dart';
import 'features/home/screens/match_detail_screen.dart';
import 'features/identity/screens/fan_id_screen.dart';
import 'features/leaderboard/screens/leaderboard_screen.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/pools/screens/pool_detail_screen.dart';
import 'features/predict/screens/jackpot_challenge_screen.dart';
import 'features/predict/screens/predict_screen.dart';
import 'features/profile/screens/notifications_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/rewards/screens/rewards_screen.dart';
import 'features/settings/screens/feature_unavailable_screen.dart';
import 'features/settings/screens/privacy_settings_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/social/screens/social_hub_screen.dart';
import 'features/teams/screens/team_profile_canonical_screen.dart';
import 'features/wallet/screens/wallet_screen.dart';

/// True when any session exists (anonymous or phone-verified).
bool _isAuthenticated() {
  final session = RuntimeAuthSessionManager.instance.currentSession;
  return session != null && !session.isExpired;
}

/// True only when the user is fully authenticated (non-anonymous).
bool _isFullyAuthenticated() {
  final session = RuntimeAuthSessionManager.instance.currentSession;
  if (session == null || session.isExpired) {
    return false;
  }
  final user = RuntimeAuthSessionManager.instance.currentUser;
  return user != null && !user.isAnonymous;
}

/// Set by main.dart before runApp() — determined while native splash is visible.
String _initialRoute = '/';

/// Called from main.dart to set the resolved initial route.
void setInitialRoute(String route) {
  _initialRoute = route;
}

final router = GoRouter(
  initialLocation: _initialRoute,
  refreshListenable: appRuntime.authStateVersion,
  observers: [AnalyticsRouteObserver()],
  redirect: (context, state) {
    final path = state.uri.path;
    final requestedLocation = state.uri.toString();

    if (path == '/login') {
      if (!_isAuthenticated()) return null;
      final redirectTo = state.uri.queryParameters['from'];
      if (redirectTo != null && redirectTo.startsWith('/')) {
        return redirectTo;
      }
      return '/';
    }

    // Routes that require full authentication (not guest)
    if (_requiresFullAuthPath(path) && !_isFullyAuthenticated()) {
      if (_isAuthenticated()) {
        // Guest user → redirect to upgrade screen
        final redirectTo = Uri.encodeComponent(requestedLocation);
        return '/upgrade?from=$redirectTo';
      }
      // Not authenticated at all → login
      final redirectTo = Uri.encodeComponent(requestedLocation);
      return '/login?from=$redirectTo';
    }

    return null;
  },
  routes: [
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
    GoRoute(path: '/matches', redirect: (context, state) => '/fixtures'),
    GoRoute(path: '/predict', redirect: (context, state) => '/pools'),
    GoRoute(
      path: '/predict/create',
      redirect: (context, state) => '/pools/create',
    ),
    GoRoute(
      path: '/predict/pool/:poolId',
      redirect: (context, state) => '/pool/${state.pathParameters['poolId']}',
    ),
    GoRoute(path: '/predict/jackpot', redirect: (context, state) => '/jackpot'),
    GoRoute(path: '/clubs', redirect: (context, state) => '/memberships'),
    GoRoute(
      path: '/clubs/membership',
      redirect: (context, state) => '/memberships',
    ),
    GoRoute(path: '/clubs/social', redirect: (context, state) => '/social'),
    GoRoute(path: '/clubs/fan-id', redirect: (context, state) => '/fan-id'),
    GoRoute(path: '/clubs/teams', redirect: (context, state) => '/memberships'),
    GoRoute(
      path: '/clubs/team/:teamId',
      redirect: (context, state) => '/team/${state.pathParameters['teamId']}',
    ),
    GoRoute(
      path: '/profile/leaderboard',
      redirect: (context, state) => '/leaderboard',
    ),
    GoRoute(
      path: '/profile/notifications',
      redirect: (context, state) => '/notifications',
    ),
    GoRoute(
      path: '/profile/settings',
      redirect: (context, state) => '/settings',
    ),
    GoRoute(
      path: '/profile/settings/privacy',
      redirect: (context, state) => '/privacy',
    ),
    GoRoute(path: '/profile/fan-id', redirect: (context, state) => '/fan-id'),
    GoRoute(path: '/profile/rewards', redirect: (context, state) => '/rewards'),
    GoRoute(
      path: '/profile/daily-challenge',
      redirect: (context, state) => '/profile',
    ),
    GoRoute(
      path: '/profile/prediction-history',
      redirect: (context, state) => '/profile',
    ),
    GoRoute(
      path: '/profile/seasonal-leaderboard',
      redirect: (context, state) => '/leaderboard',
    ),
    GoRoute(
      path: '/profile/contests',
      redirect: (context, state) => '/profile',
    ),
    GoRoute(path: '/profile/wallet', redirect: (context, state) => '/wallet'),
    GoRoute(path: '/wallet/rewards', redirect: (context, state) => '/rewards'),
    GoRoute(path: '/registry', redirect: (context, state) => '/fan-id'),
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
              name: 'predict_pools',
              path: '/pools',
              builder: (context, state) => AppConfig.enablePredictions
                  ? const PredictScreen()
                  : const FeatureUnavailableScreen(featureName: 'Predict'),
              routes: [
                GoRoute(
                  name: 'predict_create',
                  path: 'create',
                  pageBuilder: (context, state) =>
                      _fadeSlideTransition(state, const CreatePoolScreen()),
                ),
              ],
            ),
            GoRoute(
              name: 'pool_detail',
              path: '/pool/:poolId',
              pageBuilder: (context, state) => _fadeSlideTransition(
                state,
                PoolDetailScreen(poolId: state.pathParameters['poolId']!),
              ),
            ),
            GoRoute(
              name: 'jackpot_challenge',
              path: '/jackpot',
              pageBuilder: (context, state) => _fadeSlideTransition(
                state,
                AppConfig.enableGlobalChallenges
                    ? const JackpotChallengeScreen()
                    : const FeatureUnavailableScreen(
                        featureName: 'Jackpot Challenge',
                        message:
                            'Weekly jackpot entry stays disabled until the production challenge backend is live.',
                      ),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              name: 'wallet',
              path: '/wallet',
              builder: (context, state) => AppConfig.enableWallet
                  ? const WalletScreen()
                  : const FeatureUnavailableScreen(featureName: 'Wallet'),
            ),
            GoRoute(
              name: 'rewards',
              path: '/rewards',
              pageBuilder: (context, state) => _fadeSlideTransition(
                state,
                AppConfig.enableRewards || AppConfig.enableMarketplace
                    ? const RewardsScreen()
                    : const FeatureUnavailableScreen(featureName: 'Rewards'),
              ),
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
                AppConfig.enableLeaderboard
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
              pageBuilder: (context, state) =>
                  _fadeSlideTransition(state, const NotificationsScreen()),
            ),
            GoRoute(
              name: 'memberships',
              path: '/memberships',
              pageBuilder: (context, state) =>
                  _fadeSlideTransition(state, const MembershipHubScreen()),
            ),
            GoRoute(
              name: 'social_hub',
              path: '/social',
              pageBuilder: (context, state) =>
                  _fadeSlideTransition(state, const SocialHubScreen()),
            ),
            GoRoute(
              name: 'fan_id',
              path: '/fan-id',
              pageBuilder: (context, state) =>
                  _fadeSlideTransition(state, const FanIdScreen()),
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

/// Paths that require full (non-anonymous) authentication.
/// Guest users browsing public content are allowed through.
bool _requiresFullAuthPath(String path) {
  const exactPaths = {
    '/wallet/rewards',
    // Identity & memberships
    '/fan-id',
    '/memberships',
    '/social',
    '/rewards',
    // Notifications (settings require full auth)
    '/notifications',
    '/privacy',
    // Legacy redirects
    '/profile/leaderboard',
    '/profile/notifications',
    '/profile/fan-id',
    '/clubs/membership',
    '/clubs/social',
    '/clubs/fan-id',
  };

  if (exactPaths.contains(path)) {
    return true;
  }

  return path.startsWith('/settings') || path.startsWith('/profile/settings');
}

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

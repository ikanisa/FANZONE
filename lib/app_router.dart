import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/accessibility/motion.dart';
import 'core/auth/runtime_auth_session_manager.dart';
import 'core/config/platform_feature_access.dart';
import 'features/auth/screens/guest_upgrade_screen.dart';
import 'features/auth/screens/whatsapp_login_screen.dart';
import 'features/fixtures/screens/fixtures_screen.dart';
import 'features/home/screens/home_feed_screen.dart';
import 'features/home/screens/league_hub_screen.dart';
import 'features/home/screens/match_detail_screen.dart';
import 'features/leaderboard/screens/leaderboard_screen.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/ordering/screens/checkout_screen.dart';
import 'features/ordering/screens/order_success_screen.dart';
import 'features/ordering/screens/order_tracking_screen.dart';
import 'features/ordering/widgets/venue_entry_wrapper.dart';
import 'features/predict/screens/predict_screen.dart';
import 'features/profile/screens/notifications_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/settings/screens/feature_unavailable_screen.dart';
import 'features/settings/screens/privacy_settings_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/teams/screens/team_profile_canonical_screen.dart';
import 'features/venue_dashboard/screens/create_stake_screen.dart';
import 'features/venue_dashboard/screens/venue_dashboard_screen.dart';
import 'features/venue_dashboard/screens/venue_gamification_screen.dart';
import 'features/wallet/screens/wallet_screen.dart';
import 'widgets/navigation/app_shell.dart';

String governedAppRouteForPath(String targetPath, {String? fallback}) {
  var path = targetPath.trim();
  if (path.isEmpty) return fallback ?? '/';

  // Normalize hosted deep links into relative in-app routes
  const hostedPrefix = 'https://fanzone.ikanisa.com';
  if (path.startsWith(hostedPrefix)) {
    path = path.substring(hostedPrefix.length);
    if (path.isEmpty) return fallback ?? '/';
  }

  final access = runtimePlatformFeatureAccess();
  final routeKey = access.routeKeyForPath(path);
  if (routeKey == null) return path;

  if (access.isVisible(routeKey, surface: PlatformSurface.route)) {
    return path;
  }

  return fallback ?? '/feature-unavailable?f=$routeKey';
}

final GoRouter router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    ),
    GoRoute(
      path: '/feature-unavailable',
      builder: (context, state) => FeatureUnavailableScreen(
        featureName: state.uri.queryParameters['f'] ?? 'unknown',
      ),
    ),
    GoRoute(
      name: 'onboarding',
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      name: 'login',
      path: '/login',
      builder: (context, state) => const PhoneLoginScreen(),
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
    GoRoute(
      name: 'venue_entry',
      path: '/v/:venueSlug',
      builder: (context, state) => VenueEntryWrapper(
        venueSlug: state.pathParameters['venueSlug']!,
        tableNumber: state.uri.queryParameters['t'],
      ),
    ),
    GoRoute(
      name: 'checkout',
      path: '/checkout',
      pageBuilder: (context, state) => _fadeSlideTransition(
        state,
        const CheckoutScreen(),
      ),
    ),
    GoRoute(
      name: 'order_success',
      path: '/order-success/:orderId',
      pageBuilder: (context, state) => _fadeSlideTransition(
        state,
        OrderSuccessScreen(orderId: state.pathParameters['orderId']!),
      ),
    ),
    GoRoute(
      name: 'order_tracking',
      path: '/order-tracking/:orderId',
      pageBuilder: (context, state) => _fadeSlideTransition(
        state,
        OrderTrackingScreen(orderId: state.pathParameters['orderId']!),
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
              name: 'home',
              path: '/',
              pageBuilder: (context, state) => _fadeSlideTransition(
                state,
                const HomeFeedScreen(),
              ),
              routes: [
                GoRoute(
                  name: 'match_detail',
                  path: 'match/:id',
                  pageBuilder: (context, state) => _fadeSlideTransition(
                    state,
                    MatchDetailScreen(matchId: state.pathParameters['id']!),
                  ),
                ),
                GoRoute(
                  name: 'league_hub',
                  path: 'league/:id',
                  pageBuilder: (context, state) => _fadeSlideTransition(
                    state,
                    LeagueHubScreen(leagueId: state.pathParameters['id']!),
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              name: 'predict',
              path: '/predict',
              pageBuilder: (context, state) => _fadeSlideTransition(
                state,
                const PredictScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              name: 'fixtures',
              path: '/fixtures',
              pageBuilder: (context, state) => _fadeSlideTransition(
                state,
                const FixturesScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              name: 'profile',
              path: '/profile',
              pageBuilder: (context, state) => _fadeSlideTransition(
                state,
                const ProfileScreen(),
              ),
              routes: [
                GoRoute(
                  name: 'notifications',
                  path: 'notifications',
                  pageBuilder: (context, state) => _fadeSlideTransition(
                    state,
                    const NotificationsScreen(),
                  ),
                ),
                GoRoute(
                  name: 'wallet',
                  path: 'wallet',
                  pageBuilder: (context, state) => _fadeSlideTransition(
                    state,
                    const WalletScreen(),
                  ),
                ),
                GoRoute(
                  name: 'leaderboard',
                  path: 'leaderboard',
                  pageBuilder: (context, state) => _fadeSlideTransition(
                    state,
                    const LeaderboardScreen(),
                  ),
                ),
                GoRoute(
                  name: 'settings',
                  path: 'settings',
                  pageBuilder: (context, state) => _fadeSlideTransition(
                    state,
                    const SettingsScreen(),
                  ),
                  routes: [
                    GoRoute(
                      name: 'privacy',
                      path: 'privacy',
                      pageBuilder: (context, state) => _fadeSlideTransition(
                        state,
                        const PrivacySettingsScreen(),
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  name: 'team_profile',
                  path: 'team/:teamId',
                  pageBuilder: (context, state) => _fadeSlideTransition(
                    state,
                    TeamProfileScreen(teamId: state.pathParameters['teamId']!),
                  ),
                ),
                GoRoute(
                  name: 'venue_dashboard',
                  path: 'venue-dashboard',
                  pageBuilder: (context, state) => _fadeSlideTransition(
                    state,
                    const VenueDashboardScreen(),
                  ),
                  routes: [
                    GoRoute(
                      name: 'venue_gamification',
                      path: 'stakes',
                      pageBuilder: (context, state) => _fadeSlideTransition(
                        state,
                        const VenueGamificationScreen(),
                      ),
                      routes: [
                        GoRoute(
                          name: 'create_stake',
                          path: 'create',
                          pageBuilder: (context, state) => _fadeSlideTransition(
                            state,
                            const CreateStakeScreen(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
  redirect: (context, state) async {
    final session = RuntimeAuthSessionManager.instance.currentSession;
    final isLoggingIn = state.uri.path == '/login';
    final isOnboarding = state.uri.path == '/onboarding';
    final isSplash = state.uri.path == '/splash';

    if (isSplash) return null;

    if (session == null) {
      if (isLoggingIn || isOnboarding) return null;
      return '/login';
    }

    if (isLoggingIn) return '/';

    return null;
  },
);

CustomTransitionPage<void> _fadeSlideTransition(
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
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

void initializeRouter({String initialRoute = '/'}) {
  // Router is now a top-level final variable
}

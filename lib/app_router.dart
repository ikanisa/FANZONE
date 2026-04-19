import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'config/app_config.dart';
import 'core/accessibility/motion.dart';
import 'core/di/injection.dart';
import 'core/navigation/analytics_route_observer.dart';
import 'features/auth/data/auth_gateway.dart';
import 'main.dart' show authStateVersion;
import 'widgets/navigation/app_shell.dart';

import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/whatsapp_login_screen.dart';
import 'features/community/screens/clubs_hub_screen.dart';
import 'features/community/screens/community_contests_screen.dart';
import 'features/community/screens/membership_hub_screen.dart';
import 'features/fixtures/screens/fixtures_screen.dart';
import 'features/home/screens/all_leagues_screen.dart';
import 'features/home/screens/event_hub_screen.dart';
import 'features/home/screens/following_screen.dart';
import 'features/home/screens/home_feed_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/home/screens/league_hub_screen.dart';
import 'features/home/screens/leagues_discovery_screen.dart';
import 'features/home/screens/match_detail_screen.dart';
import 'features/identity/screens/fan_id_screen.dart';
import 'features/leaderboard/screens/leaderboard_screen.dart';
import 'features/leaderboard/screens/seasonal_leaderboard_screen.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/pools/screens/pool_detail_screen.dart';
import 'features/predict/screens/jackpot_challenge_screen.dart';
import 'features/predict/screens/predict_screen.dart';
import 'features/profile/screens/daily_challenge_screen.dart';
import 'features/profile/screens/notifications_screen.dart';
import 'features/profile/screens/prediction_history_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/rewards/screens/rewards_screen.dart';
import 'features/search/screens/search_screen.dart';
import 'features/settings/screens/account_deletion_screen.dart';
import 'features/settings/screens/favorite_teams_screen.dart';
import 'features/settings/screens/feature_unavailable_screen.dart';
import 'features/settings/screens/market_preferences_screen.dart';
import 'features/settings/screens/privacy_settings_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/social/screens/social_hub_screen.dart';
import 'features/teams/screens/team_news_detail_screen.dart';
import 'features/teams/screens/team_profile_screen.dart';
import 'features/teams/screens/teams_discovery_screen.dart';
import 'features/wallet/screens/fet_exchange_screen.dart';
import 'features/wallet/screens/wallet_screen.dart';

bool _isAuthenticated() => getIt<AuthGateway>().isAuthenticated;

final router = GoRouter(
  initialLocation: '/splash',
  refreshListenable: authStateVersion,
  observers: [AnalyticsRouteObserver()],
  redirect: (context, state) {
    final path = state.uri.path;
    final requestedLocation = state.uri.toString();

    if (path == '/splash') return null;

    if (path == '/login') {
      if (!_isAuthenticated()) return null;
      final redirectTo = state.uri.queryParameters['from'];
      if (redirectTo != null && redirectTo.startsWith('/')) {
        return redirectTo;
      }
      return '/';
    }

    const authRequired = [
      '/profile/leaderboard',
      '/profile/seasonal-leaderboard',
      '/profile/contests',
      '/profile/notifications',
      '/profile/notification-settings',
      '/profile/settings/account-deletion',
      '/profile/daily-challenge',
      '/profile/prediction-history',
      '/profile/fan-id',
      '/wallet/rewards',
      '/wallet/exchange',
      '/clubs/membership',
      '/clubs/social',
    ];

    if (authRequired.contains(path) && !_isAuthenticated()) {
      final redirectTo = Uri.encodeComponent(requestedLocation);
      return '/login?from=$redirectTo';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      pageBuilder: (context, state) =>
          _fadeTransition(state, const SplashScreen()),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) =>
          _fadeSlideTransition(state, const PhoneLoginScreen()),
    ),
    GoRoute(
      path: '/onboarding',
      pageBuilder: (context, state) =>
          _fadeTransition(state, const OnboardingScreen()),
    ),
    GoRoute(path: '/teams', redirect: (context, state) => '/clubs/teams'),
    GoRoute(path: '/matches', redirect: (context, state) => '/fixtures'),
    GoRoute(path: '/pools', redirect: (context, state) => '/predict'),
    GoRoute(path: '/jackpot', redirect: (context, state) => '/predict/jackpot'),
    GoRoute(
      path: '/leaderboard',
      redirect: (context, state) => '/profile/leaderboard',
    ),
    GoRoute(
      path: '/notifications',
      redirect: (context, state) => '/profile/notifications',
    ),
    GoRoute(
      path: '/settings',
      redirect: (context, state) => '/profile/settings',
    ),
    GoRoute(path: '/social', redirect: (context, state) => '/clubs/social'),
    GoRoute(
      path: '/memberships',
      redirect: (context, state) => '/clubs/membership',
    ),
    GoRoute(path: '/registry', redirect: (context, state) => '/clubs/fan-id'),
    GoRoute(path: '/fan-id', redirect: (context, state) => '/clubs/fan-id'),
    GoRoute(path: '/rewards', redirect: (context, state) => '/wallet/rewards'),
    GoRoute(
      path: '/team/:teamId/news/:newsId',
      redirect: (context, state) =>
          '/clubs/team/${state.pathParameters['teamId']}/news/${state.pathParameters['newsId']}',
    ),
    GoRoute(
      path: '/team/:teamId',
      redirect: (context, state) =>
          '/clubs/team/${state.pathParameters['teamId']}',
    ),
    GoRoute(path: '/profile/wallet', redirect: (context, state) => '/wallet'),
    GoRoute(
      path: '/profile/fan-id',
      redirect: (context, state) => '/clubs/fan-id',
    ),
    GoRoute(
      path: '/profile/rewards',
      redirect: (context, state) => '/wallet/rewards',
    ),
    GoRoute(
      path: '/pool/:poolId',
      redirect: (context, state) =>
          '/predict/pool/${state.pathParameters['poolId']}',
    ),
    if (AppConfig.enableFeaturedEvents)
      GoRoute(
        path: '/event/:eventTag',
        builder: (context, state) =>
            EventHubScreen(eventTag: state.pathParameters['eventTag']!),
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
              path: '/',
              builder: (context, state) => const HomeFeedScreen(),
              routes: [
                GoRoute(
                  path: 'scores',
                  pageBuilder: (context, state) =>
                      _fadeSlideTransition(state, const HomeScreen()),
                ),
                GoRoute(
                  path: 'following',
                  pageBuilder: (context, state) =>
                      _fadeSlideTransition(state, const FollowingScreen()),
                ),
                GoRoute(
                  path: 'match/:matchId',
                  pageBuilder: (context, state) => _fadeSlideTransition(
                    state,
                    MatchDetailScreen(
                      matchId: state.pathParameters['matchId']!,
                    ),
                  ),
                ),
                GoRoute(
                  path: 'league/:leagueId',
                  pageBuilder: (context, state) => _fadeSlideTransition(
                    state,
                    LeagueHubScreen(
                      leagueId: state.pathParameters['leagueId']!,
                    ),
                  ),
                ),
                GoRoute(
                  path: 'leagues',
                  pageBuilder: (context, state) => _fadeSlideTransition(
                    state,
                    const LeaguesDiscoveryScreen(),
                  ),
                  routes: [
                    GoRoute(
                      path: 'all',
                      pageBuilder: (context, state) =>
                          _fadeSlideTransition(state, const AllLeaguesScreen()),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'search',
                  pageBuilder: (context, state) =>
                      _fadeSlideTransition(state, const SearchScreen()),
                ),
                GoRoute(
                  path: 'fixtures',
                  pageBuilder: (context, state) =>
                      _fadeSlideTransition(state, const FixturesScreen()),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/predict',
              builder: (context, state) => AppConfig.enablePredictions
                  ? const PredictScreen()
                  : const FeatureUnavailableScreen(featureName: 'Predict'),
              routes: [
                GoRoute(
                  path: 'pool/:poolId',
                  pageBuilder: (context, state) => _fadeSlideTransition(
                    state,
                    PoolDetailScreen(poolId: state.pathParameters['poolId']!),
                  ),
                ),
                GoRoute(
                  path: 'jackpot',
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
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/clubs',
              builder: (context, state) => const ClubsHubScreen(),
              routes: [
                GoRoute(
                  path: 'membership',
                  pageBuilder: (context, state) =>
                      _fadeSlideTransition(state, const MembershipHubScreen()),
                ),
                GoRoute(
                  path: 'social',
                  pageBuilder: (context, state) =>
                      _fadeSlideTransition(state, const SocialHubScreen()),
                ),
                GoRoute(
                  path: 'fan-id',
                  pageBuilder: (context, state) =>
                      _fadeSlideTransition(state, const FanIdScreen()),
                ),
                GoRoute(
                  path: 'teams',
                  pageBuilder: (context, state) =>
                      _fadeSlideTransition(state, const TeamsDiscoveryScreen()),
                ),
                GoRoute(
                  path: 'team/:teamId',
                  pageBuilder: (context, state) => _fadeSlideTransition(
                    state,
                    TeamProfileScreen(teamId: state.pathParameters['teamId']!),
                  ),
                  routes: [
                    GoRoute(
                      path: 'news/:newsId',
                      pageBuilder: (context, state) => _fadeSlideTransition(
                        state,
                        TeamNewsDetailScreen(
                          teamId: state.pathParameters['teamId']!,
                          newsId: state.pathParameters['newsId']!,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/wallet',
              builder: (context, state) => AppConfig.enableWallet
                  ? const WalletScreen()
                  : const FeatureUnavailableScreen(featureName: 'Wallet'),
              routes: [
                GoRoute(
                  path: 'rewards',
                  pageBuilder: (context, state) => _fadeSlideTransition(
                    state,
                    AppConfig.enableRewards || AppConfig.enableMarketplace
                        ? const RewardsScreen()
                        : const FeatureUnavailableScreen(
                            featureName: 'Rewards',
                          ),
                  ),
                ),
                GoRoute(
                  path: 'exchange',
                  pageBuilder: (context, state) =>
                      _fadeSlideTransition(state, const FetExchangeScreen()),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'leaderboard',
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
                  path: 'settings',
                  pageBuilder: (context, state) =>
                      _fadeSlideTransition(state, const SettingsScreen()),
                  routes: [
                    GoRoute(
                      path: 'favorite-teams',
                      pageBuilder: (context, state) => _fadeSlideTransition(
                        state,
                        const FavoriteTeamsScreen(),
                      ),
                    ),
                    GoRoute(
                      path: 'market-preferences',
                      pageBuilder: (context, state) => _fadeSlideTransition(
                        state,
                        const MarketPreferencesScreen(),
                      ),
                    ),
                    GoRoute(
                      path: 'privacy',
                      pageBuilder: (context, state) => _fadeSlideTransition(
                        state,
                        const PrivacySettingsScreen(),
                      ),
                    ),
                    GoRoute(
                      path: 'account-deletion',
                      pageBuilder: (context, state) => _fadeSlideTransition(
                        state,
                        const AccountDeletionScreen(),
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'notifications',
                  pageBuilder: (context, state) =>
                      _fadeSlideTransition(state, const NotificationsScreen()),
                ),
                GoRoute(
                  path: 'notification-settings',
                  pageBuilder: (context, state) => _fadeSlideTransition(
                    state,
                    const NotificationSettingsScreen(),
                  ),
                ),
                GoRoute(
                  path: 'daily-challenge',
                  pageBuilder: (context, state) =>
                      _fadeSlideTransition(state, const DailyChallengeScreen()),
                ),
                GoRoute(
                  path: 'prediction-history',
                  pageBuilder: (context, state) => _fadeSlideTransition(
                    state,
                    const PredictionHistoryScreen(),
                  ),
                ),
                GoRoute(
                  path: 'seasonal-leaderboard',
                  pageBuilder: (context, state) => _fadeSlideTransition(
                    state,
                    AppConfig.enableSeasonalLeaderboards
                        ? const SeasonalLeaderboardScreen()
                        : const FeatureUnavailableScreen(
                            featureName: 'Seasonal Leaderboards',
                          ),
                  ),
                ),
                GoRoute(
                  path: 'contests',
                  pageBuilder: (context, state) => _fadeSlideTransition(
                    state,
                    AppConfig.enableCommunityContests
                        ? const CommunityContestsScreen()
                        : const FeatureUnavailableScreen(
                            featureName: 'Fan Contests',
                          ),
                  ),
                ),
              ],
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

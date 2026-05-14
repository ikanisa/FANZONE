import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/accessibility/motion.dart';
import 'core/auth/runtime_auth_session_manager.dart';
import 'core/config/platform_feature_access.dart';
import 'core/runtime/app_runtime_state.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/whatsapp_login_screen.dart';
import 'features/games/screens/game_detail_screen.dart';
import 'features/games/screens/games_screen.dart';
import 'features/home/screens/global_search_screen.dart';
import 'features/home/screens/home_feed_screen.dart';
import 'features/home/screens/match_detail_screen.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/ordering/screens/browse_venues_screen.dart';
import 'features/ordering/screens/checkout_screen.dart';
import 'features/ordering/screens/location_access_screen.dart';
import 'features/ordering/screens/order_receipt_screen.dart';
import 'features/ordering/screens/order_success_screen.dart';
import 'features/ordering/screens/order_tracking_screen.dart';
import 'features/ordering/screens/orders_screen.dart';
import 'features/ordering/screens/venue_detail_screen.dart';
import 'features/ordering/screens/venue_menu_screen.dart';
import 'features/ordering/widgets/venue_entry_wrapper.dart';
import 'features/pools/screens/create_pool_screen.dart';
import 'features/pools/screens/join_pool_screen.dart';
import 'features/pools/screens/pool_detail_screen.dart';
import 'features/pools/screens/pool_share_entry_screen.dart';
import 'features/pools/screens/pools_screen.dart';
import 'features/profile/screens/notifications_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/settings/screens/feature_unavailable_screen.dart';
import 'features/settings/screens/privacy_settings_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/wallet/screens/transaction_details_screen.dart';
import 'features/wallet/screens/wallet_screen.dart';
import 'widgets/navigation/app_shell.dart';

String governedAppRouteForPath(String targetPath, {String? fallback}) {
  var path = targetPath.trim();
  if (path.isEmpty) return fallback ?? '/home';

  const hostedPrefixes = [
    'https://fanzone.guest.ikanisa.com',
    'https://fanzone.ikanisa.com',
    'https://fanzone.app',
  ];
  for (final hostedPrefix in hostedPrefixes) {
    if (path.startsWith(hostedPrefix)) {
      path = path.substring(hostedPrefix.length);
      if (path.isEmpty) return fallback ?? '/home';
      break;
    }
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
      builder: (context, state) => SplashScreen(
        returnTo: state.uri.queryParameters['from'],
        venueId:
            state.uri.queryParameters['v'] ??
            state.uri.queryParameters['venue'],
        venueSlug:
            state.uri.queryParameters['venueSlug'] ??
            state.uri.queryParameters['slug'],
        tableNumber:
            state.uri.queryParameters['table'] ??
            state.uri.queryParameters['t'],
      ),
    ),
    GoRoute(
      path: '/feature-unavailable',
      builder: (context, state) => FeatureUnavailableScreen(
        featureName: state.uri.queryParameters['f'] ?? 'unknown',
      ),
    ),
    GoRoute(path: '/', redirect: (context, state) => '/home'),
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
      redirect: (context, state) {
        final returnTo = state.uri.queryParameters['from'];
        if (returnTo == null || returnTo.isEmpty) return '/login';
        return '/login?from=${Uri.encodeComponent(Uri.decodeComponent(returnTo))}';
      },
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
      name: 'venue_table_entry',
      path: '/v/:venueSlug/table/:tableNumber',
      builder: (context, state) => VenueEntryWrapper(
        venueSlug: state.pathParameters['venueSlug']!,
        tableNumber: state.pathParameters['tableNumber'],
      ),
    ),
    GoRoute(
      name: 'venue_table_entry_legacy',
      path: '/venues/:venueSlug/table/:tableNumber',
      builder: (context, state) => VenueEntryWrapper(
        venueSlug: state.pathParameters['venueSlug']!,
        tableNumber: state.pathParameters['tableNumber'],
      ),
    ),
    GoRoute(
      name: 'bar',
      path: '/bar',
      pageBuilder: (context, state) {
        final venueId =
            state.uri.queryParameters['v'] ??
            state.uri.queryParameters['venue'];
        final venueSlug =
            state.uri.queryParameters['venueSlug'] ??
            state.uri.queryParameters['slug'];
        final tableNumber =
            state.uri.queryParameters['table'] ??
            state.uri.queryParameters['t'];
        final child = venueId == null && venueSlug == null
            ? const VenueMenuScreen()
            : VenueEntryWrapper(
                venueId: venueId,
                venueSlug: venueSlug,
                tableNumber: tableNumber,
              );
        return _fadeSlideTransition(state, child);
      },
    ),
    GoRoute(
      name: 'venue_detail',
      path: '/venue/:venueId',
      pageBuilder: (context, state) => _fadeSlideTransition(
        state,
        VenueDetailScreen(venueId: state.pathParameters['venueId']!),
      ),
    ),
    GoRoute(
      name: 'location_access',
      path: '/venues/location',
      pageBuilder: (context, state) =>
          _fadeSlideTransition(state, const LocationAccessScreen()),
    ),
    GoRoute(
      name: 'global_search',
      path: '/search',
      pageBuilder: (context, state) =>
          _fadeSlideTransition(state, const GlobalSearchScreen()),
    ),
    GoRoute(
      name: 'match_detail',
      path: '/match/:id',
      pageBuilder: (context, state) => _fadeSlideTransition(
        state,
        MatchDetailScreen(matchId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      name: 'checkout',
      path: '/checkout',
      pageBuilder: (context, state) =>
          _fadeSlideTransition(state, const CheckoutScreen()),
    ),
    GoRoute(
      name: 'order_success',
      path: '/order/:orderId/success',
      pageBuilder: (context, state) => _fadeSlideTransition(
        state,
        OrderSuccessScreen(orderId: state.pathParameters['orderId']!),
      ),
    ),
    GoRoute(
      name: 'order_receipt',
      path: '/order/:orderId/receipt',
      pageBuilder: (context, state) => _fadeSlideTransition(
        state,
        OrderReceiptScreen(orderId: state.pathParameters['orderId']!),
      ),
    ),
    GoRoute(
      name: 'order_tracking',
      path: '/order/:orderId',
      pageBuilder: (context, state) => _fadeSlideTransition(
        state,
        OrderTrackingScreen(orderId: state.pathParameters['orderId']!),
      ),
    ),
    GoRoute(
      name: 'notifications',
      path: '/notifications',
      pageBuilder: (context, state) =>
          _fadeSlideTransition(state, const NotificationsScreen()),
    ),
    GoRoute(
      name: 'profile',
      path: '/profile',
      pageBuilder: (context, state) =>
          _fadeSlideTransition(state, const ProfileScreen()),
    ),
    GoRoute(
      name: 'settings',
      path: '/settings',
      pageBuilder: (context, state) =>
          _fadeSlideTransition(state, const SettingsScreen()),
      routes: [
        GoRoute(
          name: 'privacy',
          path: 'privacy',
          pageBuilder: (context, state) =>
              _fadeSlideTransition(state, const PrivacySettingsScreen()),
        ),
      ],
    ),
    GoRoute(
      name: 'wallet_transaction',
      path: '/wallet/transaction/:transactionId',
      pageBuilder: (context, state) => _fadeSlideTransition(
        state,
        TransactionDetailsScreen(
          transactionId: state.pathParameters['transactionId']!,
        ),
      ),
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
      name: 'join_pool',
      path: '/pool/:poolId/join',
      pageBuilder: (context, state) => _fadeSlideTransition(
        state,
        JoinPoolScreen(
          poolId: state.pathParameters['poolId']!,
          initialCampId: state.uri.queryParameters['camp'],
          inviteCode: state.uri.queryParameters['invite'],
          source: state.uri.queryParameters['source'],
        ),
      ),
    ),
    GoRoute(
      name: 'create_pool',
      path: '/pools/create',
      pageBuilder: (context, state) =>
          _fadeSlideTransition(state, const CreatePoolScreen()),
    ),
    GoRoute(
      name: 'pool_share_entry',
      path: '/pools/:shareSlug',
      pageBuilder: (context, state) => _fadeSlideTransition(
        state,
        PoolShareEntryScreen(
          shareSlug: state.pathParameters['shareSlug']!,
          inviteCode: state.uri.queryParameters['invite'],
          source: state.uri.queryParameters['source'],
        ),
      ),
    ),
    GoRoute(
      name: 'game_detail',
      path: '/game/:gameId',
      pageBuilder: (context, state) => _fadeSlideTransition(
        state,
        GameDetailScreen(sessionId: state.pathParameters['gameId']!),
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
              path: '/home',
              pageBuilder: (context, state) =>
                  _fadeSlideTransition(state, const HomeFeedScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              name: 'venues',
              path: '/venues',
              pageBuilder: (context, state) =>
                  _fadeSlideTransition(state, const BrowseVenuesScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              name: 'pools',
              path: '/pools',
              pageBuilder: (context, state) =>
                  _fadeSlideTransition(state, const PoolsScreen()),
            ),
            GoRoute(
              name: 'games',
              path: '/games',
              pageBuilder: (context, state) =>
                  _fadeSlideTransition(state, const GamesScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              name: 'orders',
              path: '/orders',
              pageBuilder: (context, state) =>
                  _fadeSlideTransition(state, const OrdersScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              name: 'wallet',
              path: '/wallet',
              pageBuilder: (context, state) =>
                  _fadeSlideTransition(state, const WalletScreen()),
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
    final isUpgrade = state.uri.path == '/upgrade';
    final isFeatureUnavailable = state.uri.path == '/feature-unavailable';

    if (isSplash) return null;

    if (session == null && appRuntime.supabaseInitialized) {
      if (isLoggingIn || isOnboarding || isUpgrade || isFeatureUnavailable) {
        return null;
      }
      appRuntime.queuePendingAppRoute(state.uri.toString());
      return '/splash';
    }

    if (isLoggingIn) return '/home';

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
  // Router is now a top-level final variable.
}

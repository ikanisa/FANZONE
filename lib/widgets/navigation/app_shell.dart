import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/utils/currency_utils.dart';
import '../../providers/currency_provider.dart';
import '../../services/notification_service.dart';
import '../../services/wallet_service.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../common/fz_brand_logo.dart';
import '../common/fz_wordmark.dart';
import '../predict/prediction_slip_dock.dart';

/// FANZONE shell aligned to the primary reference UI:
/// - mobile auto-hiding top bar + glass bottom nav
/// - desktop left sidebar
/// - wallet balance in shell chrome
/// - unread badge on the profile destination
class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.currentLocation,
  });

  final StatefulNavigationShell navigationShell;
  final String currentLocation;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _barsVisible = true;

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is UserScrollNotification) {
      final direction = notification.direction;
      if (direction == ScrollDirection.reverse && _barsVisible) {
        setState(() => _barsVisible = false);
      } else if (direction == ScrollDirection.forward && !_barsVisible) {
        setState(() => _barsVisible = true);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount =
        ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
    final location = widget.currentLocation;
    final isHome = _isHomePath(location);

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1024;
          final body = isDesktop
              ? Row(
                  children: [
                    _DesktopSidebar(
                      location: location,
                      unreadCount: unreadCount,
                    ),
                    Expanded(
                      child: DecoratedBox(
                        decoration: const BoxDecoration(color: FzColors.darkBg),
                        child: widget.navigationShell,
                      ),
                    ),
                  ],
                )
              : widget.navigationShell;

          final showPredictionSlip = _showsPredictionSlip(location);

          return Scaffold(
            extendBody: !isDesktop,
            extendBodyBehindAppBar: false,
            appBar: isDesktop || !isHome
                ? null
                : _FzTopBar(
                    visible: _barsVisible,
                    onHomeTap: () => context.go('/'),
                    onWalletTap: () => context.go('/wallet'),
                  ),
            body: Stack(
              children: [
                body,
                if (showPredictionSlip)
                  Positioned(
                    left: isDesktop ? 280 : 0,
                    right: isDesktop ? 24 : 0,
                    bottom: isDesktop ? 24 : 90,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isDesktop ? 520 : double.infinity,
                        ),
                        child: const SafeArea(child: PredictionSlipDock()),
                      ),
                    ),
                  ),
              ],
            ),
            bottomNavigationBar: isDesktop
                ? null
                : _MobileBottomNav(
                    visible: _barsVisible,
                    location: location,
                    unreadCount: unreadCount,
                  ),
          );
        },
      ),
    );
  }
}

class _FzTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const _FzTopBar({
    required this.visible,
    required this.onHomeTap,
    required this.onWalletTap,
  });

  final bool visible;
  final VoidCallback onHomeTap;
  final VoidCallback onWalletTap;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(walletServiceProvider);
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';
    final topInset = MediaQuery.paddingOf(context).top;

    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, -1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: topInset + 60,
            padding: EdgeInsets.only(top: topInset, left: 24, right: 24),
            decoration: BoxDecoration(
              color: FzColors.darkSurface.withValues(alpha: 0.9),
              border: const Border(
                bottom: BorderSide(color: FzColors.darkBorder),
              ),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: onHomeTap,
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: _BrandWordmark(compact: true),
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: onWalletTap,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
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
                        const Icon(
                          LucideIcons.wallet,
                          size: 12,
                          color: FzColors.coral,
                        ),
                        const SizedBox(width: 6),
                        balanceAsync.when(
                          data: (balance) => Text(
                            formatFET(balance, currency),
                            style: FzTypography.scoreCompact(
                              color: FzColors.darkText,
                            ),
                          ),
                          loading: () => Text(
                            '...',
                            style: FzTypography.scoreCompact(
                              color: FzColors.darkMuted,
                            ),
                          ),
                          error: (_, _) => Text(
                            '—',
                            style: FzTypography.scoreCompact(
                              color: FzColors.darkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({required this.location, required this.unreadCount});

  final String location;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final items = <_DesktopNavItem>[
      const _DesktopNavItem(
        label: 'Home',
        icon: LucideIcons.home,
        route: '/',
        matcher: _isHomePath,
      ),
      const _DesktopNavItem(
        label: 'Fixtures',
        icon: LucideIcons.calendar,
        route: '/fixtures',
        matcher: _isFixturesPath,
      ),
      const _DesktopNavItem(
        label: 'Pools',
        icon: LucideIcons.swords,
        route: '/pools',
        matcher: _isPredictPath,
      ),
      const _DesktopNavItem(
        label: 'Jackpots',
        icon: LucideIcons.zap,
        route: '/jackpot',
        matcher: _isJackpotPath,
      ),
      const _DesktopNavItem(
        label: 'Leaderboard',
        icon: LucideIcons.trophy,
        route: '/leaderboard',
        matcher: _isLeaderboardPath,
      ),
      const _DesktopNavItem(
        label: 'Wallet',
        icon: LucideIcons.wallet,
        route: '/wallet',
        matcher: _isWalletPath,
      ),
      const _DesktopNavItem(
        label: 'Profile',
        icon: LucideIcons.user,
        route: '/profile',
        matcher: _isProfilePath,
      ),
    ];

    return Container(
      width: 256,
      decoration: const BoxDecoration(
        color: FzColors.darkSurface,
        border: Border(right: BorderSide(color: FzColors.darkBorder)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => context.go('/'),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: _BrandWordmark(),
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isActive = item.matcher(location);
                    return _DesktopNavButton(
                      label: item.label,
                      icon: item.icon,
                      isActive: isActive,
                      badgeCount: item.label == 'Profile' ? unreadCount : 0,
                      onTap: () => context.go(item.route),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopNavButton extends StatelessWidget {
  const _DesktopNavButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? FzColors.darkSurface2 : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isActive ? FzColors.primary : FzColors.darkMuted,
                ),
                if (badgeCount > 0)
                  const Positioned(
                    top: -2,
                    right: -4,
                    child: _NotificationDot(ringColor: FzColors.darkSurface2),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? FzColors.primary : FzColors.darkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileBottomNav extends StatelessWidget {
  const _MobileBottomNav({
    required this.visible,
    required this.location,
    required this.unreadCount,
  });

  final bool visible;
  final String location;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final activeKey = _mobileNavKey(location);
    const items = <_MobileNavItem>[
      _MobileNavItem(
        keyName: 'home',
        label: 'Home',
        icon: LucideIcons.home,
        route: '/',
      ),
      _MobileNavItem(
        keyName: 'matches',
        label: 'Matches',
        icon: LucideIcons.calendar,
        route: '/fixtures',
      ),
      _MobileNavItem(
        keyName: 'pools',
        label: 'Pools',
        icon: LucideIcons.swords,
        route: '/pools',
      ),
      _MobileNavItem(
        keyName: 'profile',
        label: 'Profile',
        icon: LucideIcons.user,
        route: '/profile',
      ),
    ];

    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom,
            ),
            decoration: BoxDecoration(
              color: FzColors.darkSurface.withValues(alpha: 0.9),
              border: const Border(top: BorderSide(color: FzColors.darkBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: items.map((item) {
                final isActive = activeKey == item.keyName;
                return Expanded(
                  child: Semantics(
                    button: true,
                    label: item.label,
                    selected: isActive,
                    child: InkWell(
                      onTap: () => context.go(item.route),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  item.icon,
                                  size: 22,
                                  color: isActive
                                      ? FzColors.primary
                                      : FzColors.darkMuted,
                                ),
                                if (item.keyName == 'profile' &&
                                    unreadCount > 0)
                                  const Positioned(
                                    top: -2,
                                    right: -4,
                                    child: _NotificationDot(
                                      ringColor: FzColors.darkSurface,
                                    ),
                                  ),
                              ],
                            ),
                            if (isActive) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.label,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: FzColors.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandWordmark extends StatelessWidget {
  const _BrandWordmark({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final boxSize = compact ? 24.0 : 32.0;
    final displaySize = compact ? 26.0 : 40.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: boxSize,
          height: boxSize,
          child: FzBrandLogo(width: boxSize, height: boxSize),
        ),
        const SizedBox(width: 10),
        FzWordmark(
          style: FzTypography.display(
            size: displaySize,
            color: FzColors.darkText,
            letterSpacing: 0.6,
          ),
          fanColor: FzColors.success,
          zoneColor: FzColors.accent3,
        ),
      ],
    );
  }
}

class _NotificationDot extends StatelessWidget {
  const _NotificationDot({required this.ringColor});

  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: FzColors.danger,
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 2),
      ),
    );
  }
}

class _DesktopNavItem {
  const _DesktopNavItem({
    required this.label,
    required this.icon,
    required this.route,
    required this.matcher,
  });

  final String label;
  final IconData icon;
  final String route;
  final bool Function(String) matcher;
}

class _MobileNavItem {
  const _MobileNavItem({
    required this.keyName,
    required this.label,
    required this.icon,
    required this.route,
  });

  final String keyName;
  final String label;
  final IconData icon;
  final String route;
}

String? _mobileNavKey(String path) {
  if (_isHomePath(path)) return 'home';
  if (_isFixturesPath(path)) return 'matches';
  if (_isPredictPath(path) || _isJackpotPath(path)) return 'pools';
  if (_isProfilePath(path)) return 'profile';
  return null;
}

bool _showsPredictionSlip(String path) =>
    _isHomePath(path) ||
    _isFixturesPath(path) ||
    _isPredictPath(path) ||
    _isJackpotPath(path);

bool _isHomePath(String path) => path == '/';

bool _isFixturesPath(String path) =>
    path == '/fixtures' ||
    path.startsWith('/match/') ||
    path.startsWith('/league/');

bool _isPredictPath(String path) =>
    (path == '/pools' ||
        path.startsWith('/pools/') ||
        path == '/predict' ||
        path.startsWith('/predict/') ||
        path.startsWith('/pool/')) &&
    !_isJackpotPath(path);

bool _isJackpotPath(String path) =>
    path == '/jackpot' || path == '/predict/jackpot';

bool _isWalletPath(String path) =>
    path == '/wallet' || path.startsWith('/wallet/');

bool _isLeaderboardPath(String path) =>
    path == '/leaderboard' ||
    path.startsWith('/profile/leaderboard') ||
    path.startsWith('/profile/seasonal-leaderboard');

bool _isProfilePath(String path) =>
    path == '/profile' ||
    path.startsWith('/profile/') ||
    path.startsWith('/notifications') ||
    path.startsWith('/settings') ||
    path.startsWith('/privacy') ||
    path.startsWith('/fan-id') ||
    path.startsWith('/memberships') ||
    path.startsWith('/social') ||
    path.startsWith('/team/');

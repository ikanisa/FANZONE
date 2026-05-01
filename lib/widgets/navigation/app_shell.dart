import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../features/ordering/widgets/live_order_status_pill.dart';
import '../../theme/colors.dart';
import '../common/fz_offline_banner.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.currentLocation,
  });

  final StatefulNavigationShell navigationShell;
  final String currentLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          const FzOfflineBanner(),
          Expanded(
            child: Stack(
              children: [
                navigationShell,
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 96,
                  child: Center(child: LiveOrderStatusPill()),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNavBar(
        navigationShell: navigationShell,
        currentLocation: currentLocation,
        isDark: isDark,
      ),
    );
  }
}

class _BottomNavBar extends ConsumerWidget {
  const _BottomNavBar({
    required this.navigationShell,
    required this.currentLocation,
    required this.isDark,
  });

  final StatefulNavigationShell navigationShell;
  final String currentLocation;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = _getNavItems(ref);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        height: 72,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: (isDark ? FzColors.darkSurface : FzColors.lightSurface)
              .withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.36),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: items.map((item) {
            final isSelected = navigationShell.currentIndex == item.branchIndex;
            return Expanded(
              child: Tooltip(
                message: item.label,
                child: InkWell(
                  onTap: () => navigationShell.goBranch(item.branchIndex),
                  borderRadius: BorderRadius.circular(22),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? FzColors.accent.withValues(alpha: 0.14)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isSelected
                            ? FzColors.accent.withValues(alpha: 0.32)
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.icon,
                          color: isSelected
                              ? FzColors.accent
                              : (isDark
                                    ? FzColors.darkMuted
                                    : FzColors.lightMuted),
                          size: 22,
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            item.label,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                              color: isSelected
                                  ? FzColors.accent
                                  : (isDark
                                        ? FzColors.darkMuted
                                        : FzColors.lightMuted),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class NavItem {
  const NavItem({
    required this.label,
    required this.icon,
    required this.route,
    required this.keyName,
    required this.branchIndex,
  });

  final String label;
  final IconData icon;
  final String route;
  final String keyName;
  final int branchIndex;
}

List<NavItem> _getNavItems(WidgetRef ref) {
  return const [
    NavItem(
      keyName: 'bar',
      label: 'Bar',
      icon: LucideIcons.utensils,
      route: '/bar',
      branchIndex: 0,
    ),
    NavItem(
      keyName: 'pools',
      label: 'Pools',
      icon: LucideIcons.trophy,
      route: '/pools',
      branchIndex: 1,
    ),
    NavItem(
      keyName: 'wallet',
      label: 'Wallet',
      icon: LucideIcons.wallet,
      route: '/wallet',
      branchIndex: 2,
    ),
    NavItem(
      keyName: 'profile',
      label: 'Profile',
      icon: LucideIcons.user,
      route: '/profile',
      branchIndex: 3,
    ),
  ];
}

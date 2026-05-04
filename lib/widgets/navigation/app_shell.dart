import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/ordering/widgets/live_order_status_pill.dart';
import '../../design_system/design_system.dart';
import '../../theme/colors.dart';
import '../../theme/radii.dart';
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
      ),
    );
  }
}

class _BottomNavBar extends ConsumerWidget {
  const _BottomNavBar({
    required this.navigationShell,
    required this.currentLocation,
  });

  final StatefulNavigationShell navigationShell;
  final String currentLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = _getNavItems(ref);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: FzColors.darkSurface,
          borderRadius: FzRadii.heroRadius,
          border: Border.all(color: FzColors.darkBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
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
                  borderRadius: AppRadii.cardRadius,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? FzColors.accent.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: AppRadii.cardRadius,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppSvgIcon(
                          item.icon,
                          color: isSelected
                              ? FzColors.accent
                              : FzColors.darkMuted,
                          size: 22,
                        ),
                        // Only show label for active item
                        if (isSelected) ...[
                          const SizedBox(height: 3),
                          Text(
                            item.label,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: FzColors.accent,
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
  final AppIconName icon;
  final String route;
  final String keyName;
  final int branchIndex;
}

List<NavItem> _getNavItems(WidgetRef ref) {
  return const [
    NavItem(
      keyName: 'home',
      label: 'Home',
      icon: AppIconName.home,
      route: '/home',
      branchIndex: 0,
    ),
    NavItem(
      keyName: 'venues',
      label: 'Bars',
      icon: AppIconName.bars,
      route: '/venues',
      branchIndex: 1,
    ),
    NavItem(
      keyName: 'arena',
      label: 'Play',
      icon: AppIconName.play,
      route: '/pools',
      branchIndex: 2,
    ),
    NavItem(
      keyName: 'orders',
      label: 'Orders',
      icon: AppIconName.orders,
      route: '/orders',
      branchIndex: 3,
    ),
    NavItem(
      keyName: 'wallet',
      label: 'Wallet',
      icon: AppIconName.wallet,
      route: '/wallet',
      branchIndex: 4,
    ),
  ];
}

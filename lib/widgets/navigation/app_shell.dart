import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/config/platform_feature_access.dart';
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
                  bottom: 80, // Above bottom nav
                  child: Center(
                    child: LiveOrderStatusPill(),
                  ),
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

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkBg : FzColors.lightBg,
        border: Border(
          top: BorderSide(
            color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items.map((item) {
            final isSelected =
                navigationShell.currentIndex == items.indexOf(item);

            return InkWell(
              onTap: () => navigationShell.goBranch(items.indexOf(item)),
              child: SizedBox(
                width: 70,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.icon,
                      color: isSelected
                          ? FzColors.accent
                          : (isDark ? FzColors.darkMuted : FzColors.lightMuted),
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            isSelected ? FontWeight.w900 : FontWeight.w500,
                        color: isSelected
                            ? FzColors.accent
                            : (isDark
                                ? FzColors.darkMuted
                                : FzColors.lightMuted),
                      ),
                    ),
                  ],
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
  });

  final String label;
  final IconData icon;
  final String route;
  final String keyName;
}

List<NavItem> _getNavItems(WidgetRef ref) {
  final access = ref.watch(platformFeatureAccessProvider);
  final visibleFeatures =
      access.visibleFeatures(surface: PlatformSurface.navigation);

  IconData iconForRoute(String route) {
    switch (route) {
      case 'home':
        return LucideIcons.home;
      case 'predict':
        return LucideIcons.target;
      case 'fixtures':
        return LucideIcons.calendar;
      case 'profile':
        return LucideIcons.user;
      default:
        return LucideIcons.helpCircle;
    }
  }

  final items = visibleFeatures.map((feature) {
    final route = feature.resolvedState.routeKey ??
        feature.defaultRouteKey ??
        feature.featureKey;
    return NavItem(
      keyName: feature.featureKey,
      label: access.labelFor(feature.featureKey),
      icon: iconForRoute(feature.featureKey),
      route: route,
    );
  }).toList(growable: false);

  return items.take(4).toList(growable: false);
}

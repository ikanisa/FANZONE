import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/design_system.dart';
import '../../features/ordering/widgets/live_order_status_pill.dart';
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
    final items = _getNavItems(ref);

    return AppAdaptiveNavigationScaffold(
      body: navigationShell,
      currentIndex: navigationShell.currentIndex,
      items: items,
      onSelect: (item, isSelected) => navigationShell.goBranch(
        item.branchIndex,
        initialLocation: isSelected,
      ),
    );
  }
}

class AppAdaptiveNavigationScaffold extends StatelessWidget {
  const AppAdaptiveNavigationScaffold({
    super.key,
    required this.body,
    required this.currentIndex,
    required this.items,
    required this.onSelect,
    this.showOfflineBanner = true,
    this.showLiveOrderPill = true,
  });

  static const double mediumBreakpoint = 600;
  static const double expandedBreakpoint = 840;

  final Widget body;
  final int currentIndex;
  final List<NavItem> items;
  final void Function(NavItem item, bool isSelected) onSelect;
  final bool showOfflineBanner;
  final bool showLiveOrderPill;

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final useRail = width >= mediumBreakpoint;
        final railExtended = width >= expandedBreakpoint;

        return Scaffold(
          extendBody: !useRail,
          bottomNavigationBar: useRail
              ? null
              : _BottomNavBar(
                  items: items,
                  currentIndex: currentIndex,
                  onSelect: onSelect,
                ),
          body: Column(
            children: [
              if (showOfflineBanner) const FzOfflineBanner(),
              Expanded(
                child: useRail
                    ? Row(
                        children: [
                          _SideNavRail(
                            items: items,
                            currentIndex: currentIndex,
                            extended: railExtended,
                            onSelect: onSelect,
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            child: _ShellBodyStack(
                              keyboardOpen: keyboardOpen,
                              showLiveOrderPill: showLiveOrderPill,
                              liveOrderBottom: AppSpacing.lg,
                              child: body,
                            ),
                          ),
                        ],
                      )
                    : _ShellBodyStack(
                        keyboardOpen: keyboardOpen,
                        showLiveOrderPill: showLiveOrderPill,
                        liveOrderBottom: 96,
                        child: body,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShellBodyStack extends StatelessWidget {
  const _ShellBodyStack({
    required this.child,
    required this.keyboardOpen,
    required this.showLiveOrderPill,
    required this.liveOrderBottom,
  });

  final Widget child;
  final bool keyboardOpen;
  final bool showLiveOrderPill;
  final double liveOrderBottom;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (showLiveOrderPill && !keyboardOpen)
          Positioned(
            left: 0,
            right: 0,
            bottom: liveOrderBottom,
            child: const Center(child: LiveOrderStatusPill()),
          ),
      ],
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.items,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<NavItem> items;
  final int currentIndex;
  final void Function(NavItem item, bool isSelected) onSelect;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? FzColors.darkSurface : FzColors.lightSurface;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

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
          color: surface,
          borderRadius: FzRadii.heroRadius,
          border: Border.all(color: border),
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
            final isSelected = currentIndex == item.branchIndex;
            return Expanded(
              child: Semantics(
                label: '${item.label} tab',
                button: true,
                selected: isSelected,
                child: Tooltip(
                  message: item.label,
                  child: InkWell(
                    key: ValueKey('bottom_nav_${item.keyName}'),
                    onTap: () => onSelect(item, isSelected),
                    borderRadius: AppRadii.cardRadius,
                    child: AnimatedContainer(
                      duration: disableAnimations
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
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
                            color: isSelected ? FzColors.accent : muted,
                            size: 22,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: isSelected ? FzColors.accent : muted,
                            ),
                          ),
                        ],
                      ),
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

class _SideNavRail extends StatelessWidget {
  const _SideNavRail({
    required this.items,
    required this.currentIndex,
    required this.extended,
    required this.onSelect,
  });

  final List<NavItem> items;
  final int currentIndex;
  final bool extended;
  final void Function(NavItem item, bool isSelected) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? FzColors.darkSurface : FzColors.lightSurface;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return SafeArea(
      right: false,
      child: NavigationRail(
        key: const ValueKey('adaptive_navigation_rail'),
        selectedIndex: currentIndex,
        extended: extended,
        minWidth: 88,
        minExtendedWidth: 180,
        backgroundColor: surface,
        indicatorColor: FzColors.accent.withValues(alpha: 0.14),
        selectedIconTheme: const IconThemeData(color: FzColors.accent),
        unselectedIconTheme: IconThemeData(color: muted),
        selectedLabelTextStyle: const TextStyle(
          color: FzColors.accent,
          fontWeight: FontWeight.w900,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: muted,
          fontWeight: FontWeight.w800,
        ),
        onDestinationSelected: (index) {
          final item = items[index];
          onSelect(item, currentIndex == item.branchIndex);
        },
        destinations: [
          for (final item in items)
            NavigationRailDestination(
              icon: Tooltip(
                message: item.label,
                child: AppSvgIcon(item.icon, color: muted, size: 22),
              ),
              selectedIcon: Tooltip(
                message: item.label,
                child: AppSvgIcon(item.icon, color: FzColors.accent, size: 22),
              ),
              label: Text(item.label),
            ),
        ],
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
      keyName: 'arena',
      label: 'Play',
      icon: AppIconName.play,
      route: '/pools',
      branchIndex: 1,
    ),
    NavItem(
      keyName: 'settings',
      label: 'Settings',
      icon: AppIconName.settings,
      route: '/settings',
      branchIndex: 2,
    ),
  ];
}

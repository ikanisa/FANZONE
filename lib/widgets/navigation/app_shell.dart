import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/utils/currency_utils.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../predict/prediction_slip_dock.dart';
import '../../providers/currency_provider.dart';
import '../../services/notification_service.dart';
import '../../services/wallet_service.dart';

/// FANZONE app shell with auto-hiding glassmorphic top bar and bottom navigation.
///
/// Top bar: Brand logo + FET balance (auto-hides on scroll down).
/// Bottom nav: Home | Predict | Clubs | Wallet | Profile
/// Uses GoRouter's StatefulShellRoute for state preservation.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// true = bars visible; false = bars hidden (scrolling down)
  bool _barsVisible = true;

  /// Called by the scroll notification from the child.
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
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        appBar: _FzTopBar(visible: _barsVisible),
        body: Stack(
          children: [
            widget.navigationShell,
            if (widget.navigationShell.currentIndex <= 1)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 90, // Clear the bottom nav bar
                child: SafeArea(child: PredictionSlipDock()),
              ),
          ],
        ),
        bottomNavigationBar: _FzBottomNav(
          visible: _barsVisible,
          currentIndex: widget.navigationShell.currentIndex,
          showProfileBadge:
              (ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0) > 0,
          onTap: (index) => widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Top Bar — Auto-hiding, glassmorphic, brand + FET balance
// ─────────────────────────────────────────────────────────────

class _FzTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const _FzTopBar({required this.visible});
  final bool visible;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final balanceAsync = ref.watch(walletServiceProvider);
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';

    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, -1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: MediaQuery.of(context).padding.top + 56,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              left: 16,
              right: 16,
            ),
            decoration: BoxDecoration(
              color: (isDark ? FzColors.darkSurface : FzColors.lightSurface)
                  .withValues(alpha: 0.85),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                // Brand mark
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [FzColors.accent, FzColors.blue],
                    ),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Center(
                    child: Text(
                      'F',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'FAN',
                        style: FzTypography.display(
                          size: 22,
                          color: FzColors.teal,
                          letterSpacing: 1,
                        ),
                      ),
                      TextSpan(
                        text: 'ZONE',
                        style: FzTypography.display(
                          size: 22,
                          color: isDark
                              ? FzColors.darkText
                              : FzColors.lightText,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // FET balance pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? FzColors.darkSurface2
                        : FzColors.lightSurface2,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? FzColors.darkBorder
                          : FzColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.wallet,
                        size: 12,
                        color: FzColors.coral,
                      ),
                      const SizedBox(width: 5),
                      balanceAsync.when(
                        data: (balance) => Text(
                          formatFET(balance, currency),
                          style: FzTypography.scoreCompact(
                            color: isDark
                                ? FzColors.darkText
                                : FzColors.lightText,
                          ),
                        ),
                        loading: () => Text(
                          '...',
                          style: FzTypography.scoreCompact(
                            color: isDark
                                ? FzColors.darkMuted
                                : FzColors.lightMuted,
                          ),
                        ),
                        error: (_, _) => Text(
                          '—',
                          style: FzTypography.scoreCompact(
                            color: isDark
                                ? FzColors.darkMuted
                                : FzColors.lightMuted,
                          ),
                        ),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────
// Bottom Nav — Auto-hiding, glassmorphic
// ─────────────────────────────────────────────────────────────

class _FzBottomNav extends StatelessWidget {
  const _FzBottomNav({
    required this.visible,
    required this.currentIndex,
    required this.onTap,
    required this.showProfileBadge,
  });

  final bool visible;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool showProfileBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    const activeColor = FzColors.accent;

    final items = <_NavItemData>[
      const _NavItemData(icon: LucideIcons.home, label: 'Home'),
      const _NavItemData(icon: LucideIcons.target, label: 'Predict'),
      const _NavItemData(icon: LucideIcons.users, label: 'Clubs'),
      const _NavItemData(icon: LucideIcons.wallet, label: 'Wallet'),
      _NavItemData(
        icon: LucideIcons.user,
        label: 'Profile',
        showBadge: showProfileBadge,
      ),
    ];

    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: (isDark ? FzColors.darkSurface : FzColors.lightSurface)
                  .withValues(alpha: 0.85),
              border: Border(
                top: BorderSide(
                  color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isActive = index == currentIndex;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(index),
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
                                color: isActive ? activeColor : muted,
                              ),
                              if (item.showBadge)
                                Positioned(
                                  right: -4,
                                  top: -2,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: FzColors.danger,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isActive ? activeColor : muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.icon,
    required this.label,
    this.showBadge = false,
  });
  final IconData icon;
  final String label;
  final bool showBadge;
}

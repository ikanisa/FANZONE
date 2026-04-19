import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/app_config.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../services/notification_service.dart';
import '../../../services/push_notification_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/fan/fan_identity_widgets.dart';
import '../../../services/wallet_service.dart';

/// User profile screen with real auth data, FET balance, quick links, and logout.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(walletServiceProvider);
    final statsAsync = ref.watch(userStatsProvider);
    final user = ref.watch(currentUserProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final fanId = ref.watch(userFanIdProvider).valueOrNull;
    final showWallet = isAuthenticated && AppConfig.enableWallet;
    const showLeaderboard = AppConfig.enableLeaderboard;
    final showPredictions = isAuthenticated && AppConfig.enablePredictions;
    const showClubs = true;
    final showRewards =
        isAuthenticated &&
        (AppConfig.enableRewards || AppConfig.enableMarketplace);

    final phone = user?.phone ?? '';
    final identityLabel = isAuthenticated
        ? (fanId != null && fanId.isNotEmpty ? 'Fan #$fanId' : 'FANZONE Member')
        : 'Guest';
    final joinedYear = user?.createdAt != null
        ? DateTime.parse(user!.createdAt).year.toString()
        : '';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 16),

            // Header title
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PROFILE',
                    style: FzTypography.display(
                      size: 32,
                      color: isDark ? FzColors.darkText : FzColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Manage your fan identity, clubs, wallet, and rewards',
                    style: TextStyle(fontSize: 13, color: muted),
                  ),
                ],
              ),
            ),

            // Profile header
            FzCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: FzColors.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isAuthenticated
                          ? Text(
                              fanId != null && fanId.isNotEmpty
                                  ? fanId[0]
                                  : 'F',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: FzColors.accent,
                              ),
                            )
                          : const Icon(
                              LucideIcons.user,
                              size: 28,
                              color: FzColors.accent,
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    identityLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isAuthenticated && phone.isNotEmpty)
                    Text(
                      joinedYear.isNotEmpty
                          ? '$phone · Joined $joinedYear'
                          : phone,
                      style: TextStyle(fontSize: 12, color: muted),
                    )
                  else
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: FzColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Verify phone to unlock predictions and transfers',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: FzColors.accent,
                          ),
                        ),
                      ),
                    ),
                  // Fan ID pill
                  if (isAuthenticated && fanId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: fanId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Fan ID copied'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: FzColors.accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: FzColors.accent.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.hash,
                                size: 12,
                                color: FzColors.accent.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Fan ID: $fanId',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: FzColors.accent,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                LucideIcons.copy,
                                size: 10,
                                color: FzColors.accent.withValues(alpha: 0.6),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Fan Identity (XP, Level, Badges)
            if (isAuthenticated) ...[
              const FanIdentityCard(),
              const SizedBox(height: 12),
            ],

            if (isAuthenticated)
              statsAsync.when(
                data: (stats) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ProfileStatCard(
                          label: 'Streak',
                          value: '${stats.predictionStreak}',
                          accent: FzColors.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ProfileStatCard(
                          label: 'Predictions',
                          value: '${stats.totalPredictions}',
                          accent: FzColors.amber,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ProfileStatCard(
                          label: 'Pools Won',
                          value: '${stats.totalPoolsWon}',
                          accent: FzColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),

            const SizedBox(height: 16),

            if (showWallet) ...[
              // FET Balance card
              FzCard(
                onTap: () => context.go('/wallet'),
                padding: const EdgeInsets.all(16),
                borderColor: FzColors.amber.withValues(alpha: 0.3),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: FzColors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        LucideIcons.wallet,
                        color: FzColors.amber,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FET Balance',
                            style: TextStyle(
                              fontSize: 11,
                              color: muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          balanceAsync.when(
                            data: (balance) {
                              final currency =
                                  ref.watch(userCurrencyProvider).valueOrNull ??
                                  'EUR';
                              return Text(
                                formatFET(balance, currency),
                                style: FzTypography.scoreLarge(
                                  color: FzColors.amber,
                                ),
                              );
                            },
                            loading: () => Text(
                              '...',
                              style: FzTypography.scoreLarge(
                                color: FzColors.amber,
                              ),
                            ),
                            error: (e, st) => Text(
                              '—',
                              style: FzTypography.scoreLarge(
                                color: FzColors.amber,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(LucideIcons.chevronRight, size: 18, color: muted),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Quick links
            FzCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (showClubs)
                    _ProfileLink(
                      icon: LucideIcons.users,
                      label: 'Clubs & Fan Zones',
                      onTap: () => context.push('/clubs'),
                    ),
                  if (showClubs) const Divider(height: 0.5, indent: 52),
                  if (showClubs)
                    _ProfileLink(
                      icon: LucideIcons.badgeCheck,
                      label: 'Membership',
                      onTap: () => context.push('/clubs/membership'),
                    ),
                  if (showClubs) const Divider(height: 0.5, indent: 52),
                  if (showClubs)
                    _ProfileLink(
                      icon: LucideIcons.hash,
                      label: 'Fan ID',
                      onTap: () => context.push('/clubs/fan-id'),
                    ),
                  if (showClubs) const Divider(height: 0.5, indent: 52),
                  if (showClubs)
                    _ProfileLink(
                      icon: LucideIcons.messagesSquare,
                      label: 'Social & Challenges',
                      onTap: () => context.push('/clubs/social'),
                    ),
                  if (showClubs && (showLeaderboard || showPredictions))
                    const Divider(height: 0.5, indent: 52),
                  if (showLeaderboard)
                    _ProfileLink(
                      icon: LucideIcons.trophy,
                      label: 'Leaderboard',
                      onTap: () => context.go('/profile/leaderboard'),
                    ),
                  if (showLeaderboard && (showPredictions || showRewards))
                    const Divider(height: 0.5, indent: 52),
                  if (showPredictions)
                    _ProfileLink(
                      icon: LucideIcons.swords,
                      label: 'My Pools',
                      onTap: () => context.go('/predict'),
                    ),
                  if (showPredictions) const Divider(height: 0.5, indent: 52),
                  if (showPredictions)
                    _ProfileLink(
                      icon: LucideIcons.barChart2,
                      label: 'Prediction History',
                      onTap: () => context.go('/profile/prediction-history'),
                    ),
                  if (showPredictions && showRewards)
                    const Divider(height: 0.5, indent: 52),
                  if (showRewards)
                    _ProfileLink(
                      icon: LucideIcons.gift,
                      label: 'Rewards Marketplace',
                      onTap: () => context.go('/wallet/rewards'),
                    ),
                  if (AppConfig.enableSeasonalLeaderboards) ...[
                    const Divider(height: 0.5, indent: 52),
                    _ProfileLink(
                      icon: LucideIcons.calendar,
                      label: 'Seasonal Leaderboards',
                      onTap: () => context.go('/profile/seasonal-leaderboard'),
                    ),
                  ],
                  if (AppConfig.enableCommunityContests) ...[
                    const Divider(height: 0.5, indent: 52),
                    _ProfileLink(
                      icon: LucideIcons.swords,
                      label: 'Fan Club Contests',
                      onTap: () => context.go('/profile/contests'),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Daily challenge quick card
            if (isAuthenticated)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FzCard(
                  onTap: () => context.go('/profile/daily-challenge'),
                  padding: const EdgeInsets.all(16),
                  borderColor: FzColors.accent.withValues(alpha: 0.3),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: FzColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          LucideIcons.calendar,
                          color: FzColors.accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Daily Challenge',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Free daily prediction — earn FET!',
                              style: TextStyle(fontSize: 11, color: muted),
                            ),
                          ],
                        ),
                      ),
                      Icon(LucideIcons.chevronRight, size: 18, color: muted),
                    ],
                  ),
                ),
              ),

            // Account section
            FzCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _ProfileLink(
                    icon: LucideIcons.bell,
                    label: 'Notification Settings',
                    onTap: () => context.go('/profile/notification-settings'),
                  ),
                  const Divider(height: 0.5, indent: 52),
                  _ProfileLink(
                    icon: LucideIcons.settings,
                    label: 'Settings',
                    onTap: () => context.go('/profile/settings'),
                  ),
                  const Divider(height: 0.5, indent: 52),
                  _ProfileLink(
                    icon: LucideIcons.helpCircle,
                    label: 'Help & FAQ',
                    onTap: () => _launchUrl(context, 'https://fanzone.mt/help'),
                  ),
                ],
              ),
            ),

            // Sign out button (only if authenticated)
            if (isAuthenticated) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final authService = ref.read(authServiceProvider);
                    final pushService = ref.read(
                      pushNotificationServiceProvider,
                    );
                    await pushService.unregisterCurrentToken();
                    await authService.signOut();
                    if (context.mounted) {
                      context.go('/');
                    }
                  },
                  icon: const Icon(LucideIcons.logOut, size: 16),
                  label: const Text('Sign Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FzColors.error,
                    side: BorderSide(
                      color: FzColors.error.withValues(alpha: 0.3),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  static Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _ProfileLink extends StatelessWidget {
  const _ProfileLink({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: muted),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(LucideIcons.chevronRight, size: 16, color: muted),
          ],
        ),
      ),
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  const _ProfileStatCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return FzCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      borderColor: accent.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(value, style: FzTypography.scoreLarge(color: accent)),
        ],
      ),
    );
  }
}

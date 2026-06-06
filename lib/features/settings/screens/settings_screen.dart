import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/config/platform_feature_access.dart';
import '../../../models/platform/notification_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/notification_service.dart';
import '../../../services/push_notification_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_glass_loader.dart';
import '../../auth/widgets/sign_in_required_sheet.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final isVerified = ref.watch(isFullyAuthenticatedProvider);
    final prefsAsync = ref.watch(notificationServiceProvider);
    final profileRoute = ref
        .watch(platformFeatureAccessProvider)
        .routeFor('profile');

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          children: [
            _SettingsHero(
              isVerified: isVerified,
              textColor: textColor,
              muted: muted,
              onProfile: () => context.go(profileRoute),
              onVerify: () => showSignInRequiredSheet(
                context,
                title: 'Verify WhatsApp',
                message:
                    'Verify your number to manage notifications, join challenges, and protect rewards.',
                from: '/settings',
              ),
            ),
            const SizedBox(height: 24),
            const _SectionHeader(title: 'Account'),
            const SizedBox(height: 8),
            FzCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsLink(
                    icon: LucideIcons.userRound,
                    label: 'Profile',
                    muted: muted,
                    textColor: textColor,
                    onTap: () => context.go(profileRoute),
                  ),
                  const _Divider(),
                  _SettingsLink(
                    icon: LucideIcons.receiptText,
                    label: 'Orders',
                    muted: muted,
                    textColor: textColor,
                    onTap: () => context.push('/orders'),
                  ),
                  const _Divider(),
                  _SettingsLink(
                    icon: LucideIcons.badgePercent,
                    label: 'Rewards',
                    muted: muted,
                    textColor: textColor,
                    onTap: () => context.push('/wallet'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _SectionHeader(title: 'Notifications'),
            const SizedBox(height: 8),
            if (!isVerified)
              FzCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verify your WhatsApp number to manage notification preferences and match alerts across devices.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: () => showSignInRequiredSheet(
                        context,
                        title: 'Verify WhatsApp',
                        message:
                            'Verify your number to manage notifications, join challenges, and protect rewards.',
                        from: '/settings',
                      ),
                      child: const Text('Verify now'),
                    ),
                  ],
                ),
              )
            else
              prefsAsync.when(
                data: (prefs) => FzCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _SettingsToggle(
                        icon: LucideIcons.bell,
                        label: 'Match Alerts',
                        value: prefs.goalAlerts,
                        muted: muted,
                        textColor: textColor,
                        onChanged: (value) => _updatePrefs(
                          prefs.copyWith(goalAlerts: value),
                          requestPushPermission: value && !prefs.goalAlerts,
                        ),
                      ),
                      const _Divider(),
                      _SettingsToggle(
                        icon: LucideIcons.shield,
                        label: 'Pool Updates',
                        value: prefs.poolUpdates,
                        muted: muted,
                        textColor: textColor,
                        onChanged: (value) => _updatePrefs(
                          prefs.copyWith(poolUpdates: value),
                          requestPushPermission: value && !prefs.poolUpdates,
                        ),
                      ),
                      const _Divider(),
                      _SettingsToggle(
                        icon: LucideIcons.trophy,
                        label: 'Reward Updates',
                        value: prefs.rewardUpdates,
                        muted: muted,
                        textColor: textColor,
                        onChanged: (value) => _updatePrefs(
                          prefs.copyWith(rewardUpdates: value),
                          requestPushPermission: value && !prefs.rewardUpdates,
                        ),
                      ),
                      const _Divider(),
                      _SettingsToggle(
                        icon: LucideIcons.megaphone,
                        label: 'Marketing',
                        value: prefs.marketing,
                        muted: muted,
                        textColor: textColor,
                        onChanged: (value) => _updatePrefs(
                          prefs.copyWith(marketing: value),
                          requestPushPermission: value && !prefs.marketing,
                        ),
                      ),
                    ],
                  ),
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: FzGlassLoader(message: 'Syncing...'),
                ),
                error: (_, _) => FzCard(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Notification preferences are unavailable right now.',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            const _SectionHeader(title: 'Support'),
            const SizedBox(height: 8),
            FzCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsLink(
                    icon: LucideIcons.helpCircle,
                    label: 'Help & FAQ',
                    muted: muted,
                    textColor: textColor,
                    onTap: () => context.push('/settings/help'),
                  ),
                  const _Divider(),
                  _SettingsLink(
                    icon: LucideIcons.shieldAlert,
                    label: 'Privacy Policy',
                    muted: muted,
                    textColor: textColor,
                    onTap: () => context.push('/settings/privacy-policy'),
                  ),
                  const _Divider(),
                  _SettingsLink(
                    icon: LucideIcons.fileText,
                    label: 'Terms of Service',
                    muted: muted,
                    textColor: textColor,
                    onTap: () => context.push('/settings/terms'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updatePrefs(
    NotificationPreferences prefs, {
    bool requestPushPermission = false,
  }) async {
    try {
      if (requestPushPermission) {
        final enabled = await ref
            .read(pushNotificationServiceProvider)
            .requestUserPermissionAndRegister();
        if (!enabled && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Notifications are off in system settings. Your FANZONE alert choices were saved.',
              ),
            ),
          );
        }
      }

      await ref
          .read(notificationServiceProvider.notifier)
          .updatePreferences(prefs);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save notification preferences right now.'),
        ),
      );
    }
  }
}

class _SettingsHero extends StatelessWidget {
  const _SettingsHero({
    required this.isVerified,
    required this.textColor,
    required this.muted,
    required this.onProfile,
    required this.onVerify,
  });

  final bool isVerified;
  final Color textColor;
  final Color muted;
  final VoidCallback onProfile;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: FzColors.darkSurface,
        borderRadius: FzRadii.heroRadius,
        border: Border.all(color: FzColors.darkBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: FzColors.cyan.withValues(alpha: 0.14),
                  borderRadius: FzRadii.buttonRadius,
                ),
                child: const Icon(
                  LucideIcons.settings2,
                  color: FzColors.cyan,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SETTINGS',
                      style: FzTypography.sportsTitle(
                        size: 34,
                        color: textColor,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isVerified
                          ? 'Profile, alerts, rewards, and support.'
                          : 'Verify WhatsApp to unlock all controls.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onProfile,
                  icon: const Icon(LucideIcons.userRound, size: 16),
                  label: const Text('Profile'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: isVerified ? onProfile : onVerify,
                  icon: Icon(
                    isVerified
                        ? LucideIcons.badgeCheck
                        : LucideIcons.messageCircle,
                    size: 16,
                  ),
                  label: Text(isVerified ? 'Verified' : 'Verify'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  const _SettingsToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.muted,
    required this.textColor,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final Color muted;
  final Color textColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _LeadingIcon(icon: icon, color: muted),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeThumbColor: FzColors.primary,
        activeTrackColor: FzColors.primary.withValues(alpha: 0.35),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}

class _SettingsLink extends StatelessWidget {
  const _SettingsLink({
    required this.icon,
    required this.label,
    required this.muted,
    required this.textColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color muted;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: _LeadingIcon(icon: icon, color: muted),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
      trailing: Icon(LucideIcons.chevronRight, size: 18, color: muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 16, color: color),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 0,
      thickness: 0.6,
      indent: 60,
      endIndent: 16,
      color: Theme.of(context).brightness == Brightness.dark
          ? FzColors.darkBorder
          : FzColors.lightBorder,
    );
  }
}

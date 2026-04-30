import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/platform_feature_access.dart';
import '../../../models/platform/notification_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/notification_service.dart';
import '../../../theme/colors.dart';
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
            Row(
              children: [
                InkWell(
                  onTap: () => context.go(profileRoute),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: FzColors.darkSurface2,
                      shape: BoxShape.circle,
                      border: Border.all(color: FzColors.darkBorder),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      LucideIcons.chevronLeft,
                      size: 18,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Settings',
                  style: FzTypography.display(size: 32, color: textColor),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionHeader(title: 'Appearance'),
            const SizedBox(height: 8),
            const FzCard(
              padding: EdgeInsets.zero,
              child: _SettingsStaticTile(
                icon: LucideIcons.moon,
                label: 'Theme',
                value: 'Dark only',
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
                            'Verify your number to manage notifications, save predictions, and send FET.',
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
                        onChanged: (value) =>
                            _updatePrefs(prefs.copyWith(goalAlerts: value)),
                      ),
                      const _Divider(),
                      _SettingsToggle(
                        icon: LucideIcons.shield,
                        label: 'Prediction Updates',
                        value: prefs.predictionUpdates,
                        muted: muted,
                        textColor: textColor,
                        onChanged: (value) => _updatePrefs(
                          prefs.copyWith(predictionUpdates: value),
                        ),
                      ),
                      const _Divider(),
                      _SettingsToggle(
                        icon: LucideIcons.trophy,
                        label: 'Reward Updates',
                        value: prefs.rewardUpdates,
                        muted: muted,
                        textColor: textColor,
                        onChanged: (value) =>
                            _updatePrefs(prefs.copyWith(rewardUpdates: value)),
                      ),
                      const _Divider(),
                      _SettingsToggle(
                        icon: LucideIcons.megaphone,
                        label: 'Marketing',
                        value: prefs.marketing,
                        muted: muted,
                        textColor: textColor,
                        onChanged: (value) =>
                            _updatePrefs(prefs.copyWith(marketing: value)),
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
                    onTap: () =>
                        _launchUrl(context, 'https://fanzone.ikanisa.com/help'),
                  ),
                  const _Divider(),
                  _SettingsLink(
                    icon: LucideIcons.shieldAlert,
                    label: 'Privacy Policy',
                    muted: muted,
                    textColor: textColor,
                    onTap: () => _launchUrl(
                      context,
                      'https://fanzone.ikanisa.com/privacy',
                    ),
                  ),
                  const _Divider(),
                  _SettingsLink(
                    icon: LucideIcons.fileText,
                    label: 'Terms of Service',
                    muted: muted,
                    textColor: textColor,
                    onTap: () => _launchUrl(
                      context,
                      'https://fanzone.ikanisa.com/terms',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updatePrefs(NotificationPreferences prefs) async {
    try {
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

  static Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open that link right now.')),
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

class _SettingsStaticTile extends StatelessWidget {
  const _SettingsStaticTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

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
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: muted,
        ),
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

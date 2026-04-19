import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_config.dart';
import '../../../models/notification_model.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/notification_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';

enum _OddsFormat { decimal, fractional, american }

/// Release-facing settings screen aligned to the source reference.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  _OddsFormat _oddsFormat = _OddsFormat.decimal;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final prefsAsync = ref.watch(notificationServiceProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () => context.go('/profile'),
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
            const _SectionHeader(title: 'Preferences'),
            const SizedBox(height: 8),
            FzCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsToggle(
                    icon: LucideIcons.moon,
                    label: 'Dark Mode',
                    value: true,
                    muted: muted,
                    textColor: textColor,
                    onChanged: (_) {
                      ref.read(themeModeProvider.notifier).setMode(
                            ThemeMode.dark,
                          );
                    },
                  ),
                  const _Divider(),
                  _SettingsSelect(
                    icon: LucideIcons.globe2,
                    label: 'Odds Format',
                    muted: muted,
                    textColor: textColor,
                    value: _oddsFormat,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _oddsFormat = value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _SectionHeader(title: 'Notifications'),
            const SizedBox(height: 8),
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
                      ),
                    ),
                    const _Divider(),
                    _SettingsToggle(
                      icon: LucideIcons.shield,
                      label: 'Pool Settlement',
                      value: prefs.poolUpdates,
                      muted: muted,
                      textColor: textColor,
                      onChanged: (value) => _updatePrefs(
                        prefs.copyWith(poolUpdates: value),
                      ),
                    ),
                    const _Divider(),
                    _SettingsToggle(
                      icon: LucideIcons.users,
                      label: 'Friend Pools',
                      value: prefs.communityNews,
                      muted: muted,
                      textColor: textColor,
                      onChanged: (value) => _updatePrefs(
                        prefs.copyWith(communityNews: value),
                      ),
                    ),
                  ],
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
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
            const _SectionHeader(title: 'Developer'),
            const SizedBox(height: 8),
            FzCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsLink(
                    icon: LucideIcons.bug,
                    label: 'Test: Pool Received',
                    muted: muted,
                    textColor: textColor,
                    onTap: () => _showDeveloperStub(
                      context,
                      'Developer test notifications should be triggered from the backend notification pipeline.',
                    ),
                  ),
                  const _Divider(),
                  _SettingsLink(
                    icon: LucideIcons.bug,
                    label: 'Test: Pool Settled',
                    muted: muted,
                    textColor: textColor,
                    onTap: () => _showDeveloperStub(
                      context,
                      'Use the live notification log or seeded backend events to validate the settled flow.',
                    ),
                  ),
                ],
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
                    onTap: () => _launchUrl(context, 'https://fanzone.mt/help'),
                  ),
                  const _Divider(),
                  _SettingsLink(
                    icon: LucideIcons.shieldAlert,
                    label: 'Privacy Policy',
                    muted: muted,
                    textColor: textColor,
                    onTap: () =>
                        _launchUrl(context, 'https://fanzone.mt/privacy'),
                  ),
                  const _Divider(),
                  _SettingsLink(
                    icon: LucideIcons.fileText,
                    label: 'Terms of Service',
                    muted: muted,
                    textColor: textColor,
                    onTap: () => _launchUrl(context, 'https://fanzone.mt/terms'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: Text(
                'FANZONE v${AppConfig.appVersion}',
                style: TextStyle(
                  fontSize: 10,
                  color: muted,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updatePrefs(NotificationPreferences prefs) async {
    await ref.read(notificationServiceProvider.notifier).updatePreferences(prefs);
  }

  void _showDeveloperStub(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
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
        activeThumbColor: FzColors.accent,
        activeTrackColor: FzColors.accent.withValues(alpha: 0.35),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}

class _SettingsSelect extends StatelessWidget {
  const _SettingsSelect({
    required this.icon,
    required this.label,
    required this.muted,
    required this.textColor,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final Color muted;
  final Color textColor;
  final _OddsFormat value;
  final ValueChanged<_OddsFormat?> onChanged;

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
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<_OddsFormat>(
          value: value,
          onChanged: onChanged,
          dropdownColor: FzColors.darkSurface2,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
          items: const [
            DropdownMenuItem(
              value: _OddsFormat.decimal,
              child: Text('Decimal (1.85)'),
            ),
            DropdownMenuItem(
              value: _OddsFormat.fractional,
              child: Text('Fractional (17/20)'),
            ),
            DropdownMenuItem(
              value: _OddsFormat.american,
              child: Text('American (-118)'),
            ),
          ],
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
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: FzColors.darkSurface3,
        shape: BoxShape.circle,
        border: Border.all(color: FzColors.darkBorder),
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
    return const Divider(
      height: 1,
      thickness: 0.5,
      indent: 16,
      endIndent: 16,
      color: FzColors.darkBorder,
    );
  }
}

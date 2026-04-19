import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/app_config.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';

/// Settings screen — Preferences, notifications, and support.
/// Matches the original design's grouped sections with Bebas Neue headers.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SETTINGS',
          style: FzTypography.display(size: 28, color: textColor),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Preferences ──
          _SectionHeader(title: 'PREFERENCES', isDark: isDark),
          const SizedBox(height: 8),
          FzCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsToggle(
                  icon: isDark ? LucideIcons.moon : LucideIcons.sun,
                  label: 'Dark Mode',
                  value: isDark,
                  muted: muted,
                  textColor: textColor,
                  onChanged: (v) {
                    ref
                        .read(themeModeProvider.notifier)
                        .setMode(v ? ThemeMode.dark : ThemeMode.light);
                  },
                ),
                _Divider(isDark: isDark),
                _SettingsLink(
                  icon: LucideIcons.trophy,
                  label: 'Favorite Teams',
                  muted: muted,
                  textColor: textColor,
                  onTap: () => context.push('/profile/settings/favorite-teams'),
                ),
                _Divider(isDark: isDark),
                _SettingsLink(
                  icon: LucideIcons.globe2,
                  label: 'Market Preferences',
                  muted: muted,
                  textColor: textColor,
                  onTap: () =>
                      context.push('/profile/settings/market-preferences'),
                ),
                _Divider(isDark: isDark),
                _SettingsLink(
                  icon: LucideIcons.shield,
                  label: 'Privacy',
                  muted: muted,
                  textColor: textColor,
                  onTap: () => context.push('/profile/settings/privacy'),
                ),
                if (!isAuthenticated) ...[
                  _Divider(isDark: isDark),
                  _SettingsLink(
                    icon: LucideIcons.badgeCheck,
                    label: 'Verify Phone',
                    muted: muted,
                    textColor: textColor,
                    onTap: () =>
                        context.go('/login?from=%2Fprofile%2Fsettings'),
                  ),
                ],
                _Divider(isDark: isDark),
                Consumer(
                  builder: (context, ref, _) {
                    final currency =
                        ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';
                    return ListTile(
                      leading: Icon(
                        LucideIcons.banknote,
                        size: 18,
                        color: muted,
                      ),
                      title: Text(
                        'Inferred Currency',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: FzColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          currency,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: FzColors.accent,
                          ),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Notifications (only if feature enabled) ──
          if (AppConfig.enableNotifications) ...[
            _SectionHeader(title: 'NOTIFICATIONS', isDark: isDark),
            const SizedBox(height: 8),
            FzCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsLink(
                    icon: LucideIcons.bell,
                    label: 'Notification Preferences',
                    muted: muted,
                    textColor: textColor,
                    onTap: () => isAuthenticated
                        ? context.push('/profile/notification-settings')
                        : context.go(
                            '/login?from=%2Fprofile%2Fnotification-settings',
                          ),
                  ),
                  _Divider(isDark: isDark),
                  _SettingsLink(
                    icon: LucideIcons.smartphone,
                    label: 'Open Device Notification Settings',
                    muted: muted,
                    textColor: textColor,
                    onTap: () => _launchUrl(context, 'app-settings:'),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── Support ──
          _SectionHeader(title: 'SUPPORT', isDark: isDark),
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
                _Divider(isDark: isDark),
                _SettingsLink(
                  icon: LucideIcons.shield,
                  label: 'Privacy Policy',
                  muted: muted,
                  textColor: textColor,
                  onTap: () =>
                      _launchUrl(context, 'https://fanzone.mt/privacy'),
                ),
                _Divider(isDark: isDark),
                _SettingsLink(
                  icon: LucideIcons.fileText,
                  label: 'Terms of Service',
                  muted: muted,
                  textColor: textColor,
                  onTap: () => _launchUrl(context, 'https://fanzone.mt/terms'),
                ),
                _Divider(isDark: isDark),
                _SettingsLink(
                  icon: LucideIcons.userX,
                  label: 'Request Account Deletion',
                  muted: muted,
                  textColor: textColor,
                  onTap: () => isAuthenticated
                      ? context.push('/profile/settings/account-deletion')
                      : context.go(
                          '/login?from=%2Fprofile%2Fsettings%2Faccount-deletion',
                        ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // App version
          Center(
            child: Text(
              'FANZONE v${AppConfig.appVersion}',
              style: TextStyle(fontSize: 11, color: muted, letterSpacing: 0.5),
            ),
          ),
          const SizedBox(height: 96),
        ],
      ),
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

// ── Sub-widgets ──

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.isDark});
  final String title;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: FzTypography.display(
        size: 20,
        color: isDark ? FzColors.darkText : FzColors.lightText,
        letterSpacing: 3,
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
      leading: Icon(icon, size: 18, color: muted),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
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
      leading: Icon(icon, size: 18, color: muted),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      trailing: Icon(LucideIcons.chevronRight, size: 18, color: muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 16,
      endIndent: 16,
      color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
    );
  }
}

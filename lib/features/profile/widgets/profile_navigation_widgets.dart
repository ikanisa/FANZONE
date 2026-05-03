import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/common/fz_card.dart';

class ProfileDetailsCard extends StatelessWidget {
  const ProfileDetailsCard({
    super.key,
    required this.countryLabel,
    required this.countryDetail,
    required this.favoriteTeamsLabel,
    required this.favoriteTeamsDetail,
    required this.linkedVenueLabel,
    required this.linkedVenueDetail,
    this.onFavoriteTeamsTap,
  });

  final String countryLabel;
  final String countryDetail;
  final String favoriteTeamsLabel;
  final String favoriteTeamsDetail;
  final String linkedVenueLabel;
  final String linkedVenueDetail;
  final VoidCallback? onFavoriteTeamsTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionTitle(title: 'Profile details'),
        const SizedBox(height: 8),
        ProfileSectionCard(
          children: [
            ProfileLinkRow(
              icon: LucideIcons.flag,
              label: countryLabel,
              subtitle: countryDetail,
            ),
            const Divider(height: 0.5, indent: 56),
            ProfileLinkRow(
              icon: LucideIcons.star,
              label: favoriteTeamsLabel,
              subtitle: favoriteTeamsDetail,
              onTap: onFavoriteTeamsTap,
            ),
            const Divider(height: 0.5, indent: 56),
            ProfileLinkRow(
              icon: LucideIcons.mapPin,
              label: linkedVenueLabel,
              subtitle: linkedVenueDetail,
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class ProfileAccountLinksCard extends StatelessWidget {
  const ProfileAccountLinksCard({
    super.key,
    required this.onHelp,
    required this.showInbox,
    required this.showSettings,
    required this.showVerifyAction,
    required this.onVerifyPhone,
    required this.showSignOut,
    required this.onSignOut,
    required this.onInboxTap,
    required this.onSettingsTap,
  });

  final VoidCallback onHelp;
  final bool showInbox;
  final bool showSettings;
  final bool showVerifyAction;
  final VoidCallback onVerifyPhone;
  final bool showSignOut;
  final VoidCallback onSignOut;
  final VoidCallback onInboxTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionTitle(title: 'Account'),
        const SizedBox(height: 8),
        ProfileSectionCard(
          children: [
            if (showVerifyAction) VerifyAccountRow(onTap: onVerifyPhone),
            if (showVerifyAction) const Divider(height: 0.5, indent: 56),
            ProfileLinkRow(
              icon: LucideIcons.lock,
              label: 'Responsible play & privacy',
              onTap: () => context.push('/settings/privacy'),
            ),
            const Divider(height: 0.5, indent: 56),
            if (showInbox)
              ProfileLinkRow(
                icon: LucideIcons.bell,
                label: 'Inbox',
                onTap: onInboxTap,
              ),
            if (showInbox) const Divider(height: 0.5, indent: 56),
            if (showSettings)
              ProfileLinkRow(
                icon: LucideIcons.settings,
                label: 'Notification preferences',
                onTap: onSettingsTap,
              ),
            if (showSettings) const Divider(height: 0.5, indent: 56),
            if (showSettings)
              ProfileLinkRow(
                icon: LucideIcons.helpCircle,
                label: 'Help',
                onTap: onHelp,
              ),
            if (showSignOut) const Divider(height: 0.5, indent: 56),
            if (showSignOut)
              ProfileLinkRow(
                icon: LucideIcons.logOut,
                label: 'Sign Out',
                onTap: onSignOut,
                danger: true,
              ),
          ],
        ),
      ],
    );
  }
}

class ProfileLinkRow extends StatelessWidget {
  const ProfileLinkRow({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap?.call();
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: danger
                    ? FzColors.error.withValues(alpha: 0.1)
                    : (isDark ? FzColors.darkSurface3 : FzColors.lightSurface2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: danger
                      ? FzColors.error.withValues(alpha: 0.22)
                      : (isDark
                            ? FzColors.darkBorder.withValues(alpha: 0.5)
                            : FzColors.lightBorder.withValues(alpha: 0.7)),
                ),
              ),
              child: Icon(
                icon,
                size: 16,
                color: danger ? FzColors.error : muted,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: danger ? FzColors.error : null,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: danger ? FzColors.error : muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(LucideIcons.chevronRight, size: 16, color: muted),
            ],
          ],
        ),
      ),
    );
  }
}

class ProfileSectionTitle extends StatelessWidget {
  const ProfileSectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class ProfileSectionCard extends StatelessWidget {
  const ProfileSectionCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FzCard(
      borderRadius: FzRadii.compact,
      padding: EdgeInsets.zero,
      color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
      child: Column(children: children),
    );
  }
}

class VerifyAccountRow extends StatelessWidget {
  const VerifyAccountRow({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            VerifyAccountIcon(),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Verify WhatsApp',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: FzColors.whatsapp,
                ),
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 16, color: FzColors.whatsapp),
          ],
        ),
      ),
    );
  }
}

class VerifyAccountIcon extends StatelessWidget {
  const VerifyAccountIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: FzColors.whatsapp.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: FzColors.whatsapp.withValues(alpha: 0.2)),
      ),
      child: const Icon(
        LucideIcons.messageCircle,
        size: 16,
        color: FzColors.whatsapp,
      ),
    );
  }
}

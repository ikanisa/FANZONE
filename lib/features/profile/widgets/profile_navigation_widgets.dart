import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/app_config.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../widgets/common/fz_card.dart';

class ProfileQuickLinksCard extends StatelessWidget {
  const ProfileQuickLinksCard({
    super.key,
    required this.showClubs,
    required this.showWallet,
    required this.showPredictions,
    required this.showRewards,
  });

  final bool showClubs;
  final bool showWallet;
  final bool showPredictions;
  final bool showRewards;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionTitle(title: 'Activity'),
        const SizedBox(height: 8),
        ProfileSectionCard(
          children: [
            if (showPredictions)
              ProfileLinkRow(
                icon: LucideIcons.target,
                label: 'Predictions',
                onTap: () => context.go('/pools'),
              ),
            if (showPredictions && showWallet)
              const Divider(height: 0.5, indent: 56),
            if (showWallet)
              ProfileLinkRow(
                icon: LucideIcons.wallet,
                label: 'Wallet',
                onTap: () => context.go('/wallet'),
              ),
            if ((showPredictions || showWallet) && AppConfig.enableRewards)
              const Divider(height: 0.5, indent: 56),
            if (AppConfig.enableRewards)
              ProfileLinkRow(
                icon: LucideIcons.award,
                label: 'Rewards',
                onTap: () => context.go('/rewards'),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (showClubs) ...[
          const ProfileSectionTitle(title: 'Clubs'),
          const SizedBox(height: 8),
          ProfileSectionCard(
            children: [
              ProfileLinkRow(
                icon: LucideIcons.shield,
                label: 'Memberships',
                onTap: () => context.push('/memberships'),
              ),
              const Divider(height: 0.5, indent: 56),
              ProfileLinkRow(
                icon: LucideIcons.fingerprint,
                label: 'Fan ID',
                onTap: () => context.push('/fan-id'),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class ProfileAccountLinksCard extends StatelessWidget {
  const ProfileAccountLinksCard({
    super.key,
    required this.onHelp,
    required this.showVerifyAction,
    required this.onVerifyPhone,
    required this.showSignOut,
    required this.onSignOut,
  });

  final VoidCallback onHelp;
  final bool showVerifyAction;
  final VoidCallback onVerifyPhone;
  final bool showSignOut;
  final VoidCallback onSignOut;

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
              label: 'Privacy',
              onTap: () => context.go('/privacy'),
            ),
            const Divider(height: 0.5, indent: 56),
            ProfileLinkRow(
              icon: LucideIcons.bell,
              label: 'Inbox',
              onTap: () => context.go('/notifications'),
            ),
            const Divider(height: 0.5, indent: 56),
            ProfileLinkRow(
              icon: LucideIcons.settings,
              label: 'Preferences',
              onTap: () => context.go('/settings'),
            ),
            const Divider(height: 0.5, indent: 56),
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
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

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
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: danger ? FzColors.error : null,
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
                  color: Color(0xFF25D366),
                ),
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 16, color: Color(0xFF25D366)),
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
        color: const Color(0xFF25D366).withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF25D366).withValues(alpha: 0.2),
        ),
      ),
      child: const Icon(
        LucideIcons.messageCircle,
        size: 16,
        color: Color(0xFF25D366),
      ),
    );
  }
}

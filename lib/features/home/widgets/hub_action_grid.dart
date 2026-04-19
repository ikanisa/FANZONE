import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../theme/colors.dart';
import '../../../widgets/common/fz_card.dart';

/// Quick-action 2×2 grid shown on the matchday hub.
class HubActionGrid extends StatelessWidget {
  const HubActionGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.45,
      children: [
        HubActionCard(
          icon: LucideIcons.target,
          title: 'Predict',
          subtitle: 'Free slips and matchday picks',
          onTap: () => context.go('/predict'),
        ),
        HubActionCard(
          icon: LucideIcons.users,
          title: 'Clubs',
          subtitle: 'Memberships, communities, fan zones',
          onTap: () => context.go('/clubs'),
        ),
        HubActionCard(
          icon: LucideIcons.wallet,
          title: 'Wallet',
          subtitle: 'FET balance, transfers, and rewards',
          onTap: () => context.go('/wallet'),
        ),
        HubActionCard(
          icon: LucideIcons.hash,
          title: 'Fan ID',
          subtitle: 'Identity, badges, and supporter registry',
          onTap: () => context.push('/clubs/fan-id'),
        ),
      ],
    );
  }
}

/// Single action card used in the hub grid.
class HubActionCard extends StatelessWidget {
  const HubActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return FzCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      borderColor: FzColors.accent.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: FzColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: FzColors.accent),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: muted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

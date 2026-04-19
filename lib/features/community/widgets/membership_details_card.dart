import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../models/team_model.dart';
import '../../../theme/colors.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/match/match_list_widgets.dart';

/// Detailed membership info showing active club, tier, and FET split.
class MembershipDetailsCard extends StatelessWidget {
  const MembershipDetailsCard({
    super.key,
    required this.activeClub,
    required this.membershipTier,
    required this.clubSplit,
    required this.levelLabel,
  });

  final TeamModel activeClub;
  final String membershipTier;
  final int clubSplit;
  final String levelLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return FzCard(
      padding: const EdgeInsets.all(20),
      borderColor: FzColors.violet.withValues(alpha: 0.24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: FzColors.violet.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                membershipTier,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: FzColors.violet,
                  letterSpacing: 0.7,
                ),
              ),
            ),
          ),
          Row(
            children: [
              TeamAvatar(
                name: activeClub.name,
                logoUrl: activeClub.logoUrl ?? activeClub.crestUrl,
                size: 56,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeClub.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activeClub.leagueName ??
                          activeClub.country ??
                          'Supporter registry',
                      style: TextStyle(fontSize: 12, color: muted),
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
                child: _MembershipMetric(
                  label: 'Supporter Tier',
                  value: levelLabel,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MembershipMetric(
                  label: 'FET to Club',
                  value: '$clubSplit%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/clubs/team/${activeClub.id}'),
                  child: const Text('View Club'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => context.push('/wallet'),
                  child: const Text('Support With FET'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MembershipMetric extends StatelessWidget {
  const _MembershipMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: muted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

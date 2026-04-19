import 'package:flutter/material.dart';

import '../../../core/market/launch_market.dart';
import '../../../models/global_challenge_model.dart';
import '../../../theme/colors.dart';
import '../../../widgets/common/fz_card.dart';

/// Card displaying a global challenge with entry/prize info.
class GlobalChallengeCard extends StatelessWidget {
  const GlobalChallengeCard({
    super.key,
    required this.challenge,
    required this.onTap,
  });

  final GlobalChallengeModel challenge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final entryLabel = challenge.entryFeeFet == 0
        ? 'Free'
        : '${challenge.entryFeeFet} FET';

    return FzCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      borderColor: FzColors.teal.withValues(alpha: 0.24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  challenge.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _RegionPill(label: launchRegionLabel(challenge.region)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            challenge.description ?? 'Open prediction challenge',
            style: TextStyle(fontSize: 12, color: muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ChallengeStat(label: 'Entry', value: entryLabel),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ChallengeStat(
                  label: 'Prize',
                  value: '${challenge.prizePoolFet} FET',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RegionPill extends StatelessWidget {
  const _RegionPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? FzColors.darkText : FzColors.lightText,
        ),
      ),
    );
  }
}

class _ChallengeStat extends StatelessWidget {
  const _ChallengeStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
        borderRadius: BorderRadius.circular(12),
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
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

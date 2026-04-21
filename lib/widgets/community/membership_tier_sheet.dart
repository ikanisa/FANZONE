import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/typography.dart';

/// Membership tier comparison bottom sheet.
///
/// Matches the reference `MembershipTierModal.tsx` — shows 4 tiers
/// (Supporter/Member/Ultra/Legend) in a scrollable grid with pricing,
/// perks, and FET share percentages.
class MembershipTierSheet extends StatelessWidget {
  const MembershipTierSheet({
    super.key,
    required this.onSelectTier,
  });

  final void Function(String tier) onSelectTier;

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FzColors.darkSurface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(FzRadii.card)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => MembershipTierSheet(
          onSelectTier: (tier) => Navigator.pop(context, tier),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 48,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: FzColors.darkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MEMBERSHIP TIERS',
                    style: FzTypography.display(size: 24),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select a tier to contribute to your club\'s FET pool.',
                    style: FzTypography.metaLabel(size: 10),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: FzColors.darkSurface3,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.x,
                    size: 16,
                    color: FzColors.darkMuted,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Tier Grid
          Expanded(
            child: ListView(
              children: [
                _TierCard(
                  name: 'SUPPORTER',
                  icon: '⚽',
                  price: 'FREE',
                  color: const Color(0xFF6070A0),
                  fetShare: '0%',
                  perks: const [
                    'Club profile access',
                    'View club news & fixtures',
                    'Club Fan ID badge on profile',
                    'Counted in club\'s member total',
                  ],
                  onSelect: () => onSelectTier('Supporter'),
                ),
                const SizedBox(height: 12),
                _TierCard(
                  name: 'MEMBER',
                  icon: '🏅',
                  price: '500 RWF',
                  color: FzColors.primary,
                  fetShare: '10%',
                  perks: const [
                    'All Supporter benefits',
                    '10% of earned FET shared to club',
                    'Member-only club chat',
                    'Digital membership card',
                  ],
                  onSelect: () => onSelectTier('Member'),
                ),
                const SizedBox(height: 12),
                _TierCard(
                  name: 'ULTRA',
                  icon: '🔥',
                  price: '1,500 RWF',
                  color: const Color(0xFFFFD32A),
                  fetShare: '20%',
                  popular: true,
                  perks: const [
                    'All Member benefits',
                    'Gold \'Ultra\' badge on profile',
                    '20% of earned FET shared to club',
                    'Priority access to Jackpot rounds',
                  ],
                  onSelect: () => onSelectTier('Ultra'),
                ),
                const SizedBox(height: 12),
                _TierCard(
                  name: 'LEGEND',
                  icon: '👑',
                  price: '5,000 RWF',
                  color: const Color(0xFFE0393E),
                  fetShare: '35%',
                  perks: const [
                    'All Ultra benefits',
                    'Animated \'Legend\' crown badge',
                    '35% of earned FET shared to club',
                    'Top 10 Legends listed publicly',
                  ],
                  onSelect: () => onSelectTier('Legend'),
                ),

                const SizedBox(height: 20),

                // Info box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: FzColors.darkSurface3,
                    borderRadius: FzRadii.cardAltRadius,
                    border: Border.all(
                      color: const Color(0xFFFFCC00).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ℹ️', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FET CONTRIBUTION POOL LOGIC',
                              style: FzTypography.statusLabel(
                                color: const Color(0xFFFFCC00),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Each member\'s prediction FET earn is split: (100% - tier%) goes to personal wallet, tier% goes to the club\'s collective FET pool. Club\'s total pooled FET is the ranking currency on the Fan Club Leaderboard.',
                              style: FzTypography.metaLabel(size: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.name,
    required this.icon,
    required this.price,
    required this.color,
    required this.fetShare,
    required this.perks,
    required this.onSelect,
    this.popular = false,
  });

  final String name;
  final String icon;
  final String price;
  final Color color;
  final String fetShare;
  final List<String> perks;
  final VoidCallback onSelect;
  final bool popular;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: FzColors.darkSurface3,
          borderRadius: FzRadii.cardAltRadius,
          border: Border(
            top: BorderSide(color: color, width: 4),
            left: BorderSide(
              color: popular ? const Color(0xFFFFCC00) : Colors.transparent,
              width: 2,
            ),
            right: BorderSide(
              color: popular ? const Color(0xFFFFCC00) : Colors.transparent,
              width: 2,
            ),
            bottom: BorderSide(
              color: popular ? const Color(0xFFFFCC00) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Popular badge
            if (popular)
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFCC00),
                    borderRadius: FzRadii.fullRadius,
                  ),
                  child: Text(
                    'POPULAR',
                    style: FzTypography.metaLabel(
                      size: 9,
                      color: const Color(0xFF1A1400),
                    ),
                  ),
                ),
              ),

            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(name, style: FzTypography.display(size: 20, color: color)),
            Text(
              price,
              style: FzTypography.score(size: 20),
            ),
            const SizedBox(height: 2),
            Text(
              'PER MONTH · MOMO USSD',
              style: FzTypography.metaLabel(),
            ),

            const SizedBox(height: 16),
            Container(height: 1, color: FzColors.darkBorder),
            const SizedBox(height: 16),

            // Perks
            ...perks.map((perk) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.check, size: 12, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      perk,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: FzColors.darkText,
                      ),
                    ),
                  ),
                ],
              ),
            )),

            const SizedBox(height: 12),

            // FET share footer
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FzColors.darkSurface2,
                borderRadius: FzRadii.buttonRadius,
                border: Border.all(color: FzColors.darkBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'FET TO CLUB',
                    style: FzTypography.metaLabel(),
                  ),
                  Text(
                    fetShare,
                    style: FzTypography.score(size: 14, color: FzColors.secondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

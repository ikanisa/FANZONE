import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';

class StandardLeaderboardEntry {
  const StandardLeaderboardEntry({
    required this.rank,
    required this.name,
    required this.fetValue,
  });

  final int rank;
  final String name;
  final int fetValue;

  String get fetLabel => formatCompactFet(fetValue);
}

String formatCompactFet(int value) {
  if (value >= 1000000) {
    final millions = value / 1000000;
    return '${millions.toStringAsFixed(millions >= 10 ? 0 : 1).replaceAll('.0', '')}m';
  }
  if (value >= 1000) {
    final thousands = value / 1000;
    return '${thousands.toStringAsFixed(thousands >= 10 ? 0 : 1).replaceAll('.0', '')}k';
  }
  return '$value';
}

class PodiumItem extends StatelessWidget {
  const PodiumItem({
    super.key,
    required this.rank,
    required this.name,
    required this.fet,
    required this.pedestalHeight,
  });

  final int rank;
  final String name;
  final String fet;
  final double pedestalHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final surface3Color = isDark
        ? FzColors.darkSurface3
        : FzColors.lightSurface3;
    final trophyColor = switch (rank) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      _ => const Color(0xFFCD7F32),
    };

    return SizedBox(
      width: 72,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(
            LucideIcons.trophy,
            size: rank == 1 ? 32 : 24,
            color: trophyColor,
          ),
          const SizedBox(height: 8),
          Container(
            width: 64,
            height: pedestalHeight,
            decoration: BoxDecoration(
              color: surface3Color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border(
                top: BorderSide(color: borderColor, width: 1),
                left: BorderSide(color: borderColor, width: 1),
                right: BorderSide(color: borderColor, width: 1),
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Text(
                '#$rank',
                style: FzTypography.scoreCompact(
                  color: isDark ? FzColors.darkText : FzColors.lightText,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? FzColors.darkText : FzColors.lightText,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$fet FET',
            style: FzTypography.scoreCompact(color: FzColors.coral),
          ),
        ],
      ),
    );
  }
}

class LeaderboardRow extends StatelessWidget {
  const LeaderboardRow({super.key, required this.entry});

  final StandardLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final surface2Color = isDark
        ? FzColors.darkSurface2
        : FzColors.lightSurface2;
    final surface3Color = isDark
        ? FzColors.darkSurface3
        : FzColors.lightSurface3;

    return FzCard(
      borderRadius: 16,
      color: surface2Color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Text('${entry.rank}', style: FzTypography.scoreCompact(color: muted)),
          const SizedBox(width: 12),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: surface3Color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
              ),
            ),
            alignment: Alignment.center,
            child: const Text('👤', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
          Text(
            '${entry.fetLabel} FET',
            style: FzTypography.scoreCompact(color: FzColors.coral),
          ),
          const SizedBox(width: 10),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: surface3Color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              LucideIcons.userPlus,
              size: 14,
              color: FzColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class PinnedUserCard extends StatelessWidget {
  const PinnedUserCard({
    super.key,
    required this.rankAsync,
    required this.balanceAsync,
    required this.bottomOffset,
  });

  final AsyncValue<int?> rankAsync;
  final AsyncValue<int> balanceAsync;
  final double bottomOffset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final surface3Color = isDark
        ? FzColors.darkSurface3
        : FzColors.lightSurface3;
    final rankLabel = rankAsync.when(
      data: (rank) => '#${rank ?? 42}',
      loading: () => '#42',
      error: (e, s) => '#42',
    );
    final balanceLabel = balanceAsync.when(
      data: (b) => '+${formatCompactFet(b > 0 ? b : 2100)} FET',
      loading: () => '+2.1k FET',
      error: (e, s) => '+2.1k FET',
    );

    return Positioned(
      left: 12,
      right: 12,
      bottom: bottomOffset,
      child: IgnorePointer(
        ignoring: true,
        child: Container(
          decoration: BoxDecoration(
            color: FzColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: FzColors.primary.withValues(alpha: 0.22)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Text(
                rankLabel,
                style: FzTypography.scoreCompact(color: FzColors.primary),
              ),
              const SizedBox(width: 12),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: surface3Color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: FzColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '👤',
                  style: TextStyle(color: textColor, fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Accuracy 68%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: muted,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                balanceLabel,
                style: FzTypography.scoreCompact(color: FzColors.coral),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';

// ──────────────────────────────────────────────
// Data models
// ──────────────────────────────────────────────

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

class FanClubEntry {
  const FanClubEntry({
    required this.rank,
    required this.name,
    required this.crest,
    required this.fetValue,
    required this.trend,
  });

  final int rank;
  final String name;
  final String crest;
  final int fetValue;
  final Trend trend;

  String get fetLabel => formatCompactFet(fetValue);
}

enum Trend { up, down, same }

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

// ──────────────────────────────────────────────
// Seed / fallback data
// ──────────────────────────────────────────────

const List<StandardLeaderboardEntry> weeklyEntries = <StandardLeaderboardEntry>[
  StandardLeaderboardEntry(rank: 1, name: 'SpartanKing', fetValue: 15200),
  StandardLeaderboardEntry(rank: 2, name: 'MaltaFan', fetValue: 12400),
  StandardLeaderboardEntry(rank: 3, name: 'PacevillePro', fetValue: 10100),
  StandardLeaderboardEntry(rank: 4, name: 'User_4', fetValue: 6500),
  StandardLeaderboardEntry(rank: 5, name: 'User_5', fetValue: 5500),
  StandardLeaderboardEntry(rank: 6, name: 'User_6', fetValue: 4500),
  StandardLeaderboardEntry(rank: 7, name: 'User_7', fetValue: 3500),
  StandardLeaderboardEntry(rank: 8, name: 'User_8', fetValue: 2500),
];

const List<StandardLeaderboardEntry> friendsEntries = <StandardLeaderboardEntry>[
  StandardLeaderboardEntry(rank: 1, name: 'Marco_B', fetValue: 9800),
  StandardLeaderboardEntry(rank: 2, name: 'Sarah_G', fetValue: 9100),
  StandardLeaderboardEntry(rank: 3, name: 'Jake_C', fetValue: 8400),
  StandardLeaderboardEntry(rank: 4, name: 'Isla_F', fetValue: 7600),
  StandardLeaderboardEntry(rank: 5, name: 'Daniel_G', fetValue: 6900),
  StandardLeaderboardEntry(rank: 6, name: 'Maria_T', fetValue: 6200),
];

const List<FanClubEntry> fanClubEntries = <FanClubEntry>[
  FanClubEntry(rank: 1, name: 'Hamrun S.', crest: 'H', fetValue: 620000, trend: Trend.up),
  FanClubEntry(rank: 2, name: 'Sliema W.', crest: 'S', fetValue: 450000, trend: Trend.same),
  FanClubEntry(rank: 3, name: 'Valletta FC', crest: 'V', fetValue: 310000, trend: Trend.up),
  FanClubEntry(rank: 4, name: 'Floriana', crest: 'F', fetValue: 280000, trend: Trend.up),
  FanClubEntry(rank: 5, name: 'Birkirkara', crest: 'B', fetValue: 210000, trend: Trend.down),
  FanClubEntry(rank: 6, name: 'Hibernians', crest: 'H', fetValue: 195000, trend: Trend.same),
  FanClubEntry(rank: 7, name: 'Balzan FC', crest: 'B', fetValue: 150000, trend: Trend.up),
];

// ──────────────────────────────────────────────
// Tab chip
// ──────────────────────────────────────────────

class LeaderboardTabChip extends StatelessWidget {
  const LeaderboardTabChip({
    super.key,
    required this.label,
    required this.active,
    required this.onPressed,
  });

  final String label;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inactiveColor = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final inactiveBorder = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final inactiveText = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? FzColors.primary : inactiveColor,
            borderRadius: BorderRadius.circular(999),
            border: active ? null : Border.all(color: inactiveBorder, width: 1),
            boxShadow: active
                ? [BoxShadow(color: FzColors.primary.withValues(alpha: 0.28), blurRadius: 14, spreadRadius: 0)]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? FzColors.darkBg : inactiveText,
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Podium
// ──────────────────────────────────────────────

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
    final surface3Color = isDark ? FzColors.darkSurface3 : FzColors.lightSurface3;
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
          Icon(LucideIcons.trophy, size: rank == 1 ? 32 : 24, color: trophyColor),
          const SizedBox(height: 8),
          Container(
            width: 64,
            height: pedestalHeight,
            decoration: BoxDecoration(
              color: surface3Color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                style: FzTypography.scoreCompact(color: isDark ? FzColors.darkText : FzColors.lightText),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? FzColors.darkText : FzColors.lightText, height: 1.15),
          ),
          const SizedBox(height: 2),
          Text('$fet FET', style: FzTypography.scoreCompact(color: FzColors.coral)),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Standard row
// ──────────────────────────────────────────────

class LeaderboardRow extends StatelessWidget {
  const LeaderboardRow({super.key, required this.entry});

  final StandardLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final surface2Color = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final surface3Color = isDark ? FzColors.darkSurface3 : FzColors.lightSurface3;

    return FzCard(
      borderRadius: 16,
      color: surface2Color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Text('${entry.rank}', style: FzTypography.scoreCompact(color: muted)),
          const SizedBox(width: 12),
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: surface3Color, shape: BoxShape.circle, border: Border.all(color: isDark ? FzColors.darkBorder : FzColors.lightBorder)),
            alignment: Alignment.center,
            child: const Text('👤', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(entry.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor))),
          Text('${entry.fetLabel} FET', style: FzTypography.scoreCompact(color: FzColors.coral)),
          const SizedBox(width: 10),
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: surface3Color, shape: BoxShape.circle, border: Border.all(color: isDark ? FzColors.darkBorder : FzColors.lightBorder)),
            alignment: Alignment.center,
            child: const Icon(LucideIcons.userPlus, size: 14, color: FzColors.primary),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Pinned user card
// ──────────────────────────────────────────────

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
    final surface3Color = isDark ? FzColors.darkSurface3 : FzColors.lightSurface3;
    final rankLabel = rankAsync.when(data: (rank) => '#${rank ?? 42}', loading: () => '#42', error: (e, s) => '#42');
    final balanceLabel = balanceAsync.when(data: (b) => '+${formatCompactFet(b > 0 ? b : 2100)} FET', loading: () => '+2.1k FET', error: (e, s) => '+2.1k FET');

    return Positioned(
      left: 12, right: 12, bottom: bottomOffset,
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
              Text(rankLabel, style: FzTypography.scoreCompact(color: FzColors.primary)),
              const SizedBox(width: 12),
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: surface3Color, shape: BoxShape.circle, border: Border.all(color: FzColors.primary.withValues(alpha: 0.3))),
                alignment: Alignment.center,
                child: Text('👤', style: TextStyle(color: textColor, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('You', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor, height: 1.0)),
                    const SizedBox(height: 3),
                    Text('Accuracy 68%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: muted, letterSpacing: 0.9)),
                  ],
                ),
              ),
              Text(balanceLabel, style: FzTypography.scoreCompact(color: FzColors.coral)),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Fan Club view
// ──────────────────────────────────────────────

class FanClubLeaderboardView extends StatelessWidget {
  const FanClubLeaderboardView({super.key, required this.entries});

  final List<FanClubEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final surface2Color = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final podium = entries.take(3).toList(growable: false);
    final rows = entries.skip(3).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.only(bottom: 128),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          decoration: BoxDecoration(
            color: surface2Color,
            border: Border(bottom: BorderSide(color: borderColor, width: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (podium.length > 1) ClubPodiumItem(entry: podium[1], pedestalHeight: 112),
              if (podium.length > 1) const SizedBox(width: 8),
              ClubPodiumItem(entry: podium[0], pedestalHeight: 144),
              if (podium.length > 2) const SizedBox(width: 8),
              if (podium.length > 2) ClubPodiumItem(entry: podium[2], pedestalHeight: 96),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            children: [
              for (final entry in rows) ...[
                ClubLeaderboardRow(entry: entry),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class ClubPodiumItem extends StatelessWidget {
  const ClubPodiumItem({super.key, required this.entry, required this.pedestalHeight});

  final FanClubEntry entry;
  final double pedestalHeight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final surfaceColor = isDark ? FzColors.darkSurface : FzColors.lightSurface;
    final surface3Color = isDark ? FzColors.darkSurface3 : FzColors.lightSurface3;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    return SizedBox(
      width: 80,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Container(
                  width: 80, height: pedestalHeight,
                  decoration: BoxDecoration(
                    color: surface3Color,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    border: Border(
                      top: BorderSide(color: borderColor, width: 1),
                      left: BorderSide(color: borderColor, width: 1),
                      right: BorderSide(color: borderColor, width: 1),
                    ),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Align(alignment: Alignment.bottomCenter, child: Text('#${entry.rank}', style: FzTypography.scoreCompact(color: textColor))),
                ),
              ),
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08), blurRadius: 14, offset: const Offset(0, 4))],
                ),
                alignment: Alignment.center,
                child: Text(entry.crest, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(entry.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textColor, height: 1.15)),
          const SizedBox(height: 2),
          Text('${entry.fetLabel} FET', style: FzTypography.scoreCompact(color: FzColors.primary)),
        ],
      ),
    );
  }
}

class ClubLeaderboardRow extends StatelessWidget {
  const ClubLeaderboardRow({super.key, required this.entry});

  final FanClubEntry entry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final surface3Color = isDark ? FzColors.darkSurface3 : FzColors.lightSurface3;

    return FzCard(
      borderRadius: 16,
      color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Text('${entry.rank}', style: FzTypography.scoreCompact(color: muted)),
                const SizedBox(height: 2),
                Icon(
                  switch (entry.trend) { Trend.up => LucideIcons.trendingUp, Trend.down => LucideIcons.trendingDown, Trend.same => LucideIcons.minus },
                  size: 10,
                  color: switch (entry.trend) { Trend.up => FzColors.primary, Trend.down => FzColors.coral, Trend.same => muted },
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: surface3Color, borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? FzColors.darkBorder : FzColors.lightBorder)),
            alignment: Alignment.center,
            child: Text(entry.crest, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(entry.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(entry.fetLabel, style: FzTypography.scoreCompact(color: FzColors.primary)),
              const SizedBox(height: 2),
              Text('POOL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: muted, letterSpacing: 0.9)),
            ],
          ),
        ],
      ),
    );
  }
}

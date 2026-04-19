import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../services/leaderboard_service.dart';
import '../../../services/wallet_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';

/// Canonical leaderboard screen aligned to the reference UI.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  _LeaderboardTab _activeTab = _LeaderboardTab.global;

  @override
  Widget build(BuildContext context) {
    final leaderboardAsync = ref.watch(globalLeaderboardProvider);
    final userRankAsync = ref.watch(userRankProvider);
    final balanceAsync = ref.watch(walletServiceProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final borderColor = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final surfaceColor = isDark ? FzColors.darkSurface : FzColors.lightSurface;
    final surface2Color = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final width = MediaQuery.sizeOf(context).width;
    final pinnedBottomOffset = width >= 1024 ? 24.0 : 86.0;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        toolbarHeight: 82,
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: Border(
          bottom: BorderSide(color: borderColor, width: 1),
        ),
        titleSpacing: 16,
        title: Text(
          'Leaderboard',
          style: FzTypography.display(
            size: 34,
            color: textColor,
            letterSpacing: 0.4,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final tab in _LeaderboardTab.values) ...[
                    _LeaderboardTabChip(
                      label: tab.label,
                      active: _activeTab == tab,
                      onPressed: () => setState(() => _activeTab = tab),
                    ),
                    if (tab != _LeaderboardTab.values.last)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      body: leaderboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => StateView.error(
          title: 'Could not load leaderboard',
          onRetry: () => ref.invalidate(globalLeaderboardProvider),
        ),
        data: (rankings) {
          final standardEntries = _resolveStandardEntries(rankings, _activeTab);
          final pinnedCard = _PinnedUserCard(
            rankAsync: userRankAsync,
            balanceAsync: balanceAsync,
            bottomOffset: pinnedBottomOffset,
          );

          if (_activeTab == _LeaderboardTab.fanClubs) {
            return const AnimatedSwitcher(
              duration: Duration(milliseconds: 220),
              child: _FanClubLeaderboardView(
                key: ValueKey('fan-clubs-leaderboard'),
                entries: _fanClubEntries,
              ),
            );
          }

          if (standardEntries.isEmpty) {
            return StateView.empty(
              title: 'No rankings yet',
              subtitle: 'Rankings will appear once users start earning FET.',
              icon: LucideIcons.trophy,
            );
          }

          final podium = standardEntries.take(3).toList(growable: false);
          final rows = standardEntries.skip(3).toList(growable: false);

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Stack(
              key: ValueKey<String>(_activeTab.label),
              children: [
                ListView(
                  padding: const EdgeInsets.only(bottom: 188),
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                      decoration: BoxDecoration(
                        color: surface2Color,
                        border: Border(
                          bottom: BorderSide(color: borderColor, width: 1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (podium.length > 1)
                            _PodiumItem(
                              rank: podium[1].rank,
                              name: podium[1].name,
                              fet: podium[1].fetLabel,
                              pedestalHeight: 112,
                            ),
                          if (podium.length > 1) const SizedBox(width: 8),
                          _PodiumItem(
                            rank: podium[0].rank,
                            name: podium[0].name,
                            fet: podium[0].fetLabel,
                            pedestalHeight: 144,
                          ),
                          if (podium.length > 2) const SizedBox(width: 8),
                          if (podium.length > 2)
                            _PodiumItem(
                              rank: podium[2].rank,
                              name: podium[2].name,
                              fet: podium[2].fetLabel,
                              pedestalHeight: 96,
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Column(
                        children: [
                          for (final entry in rows) ...[
                            _LeaderboardRow(entry: entry),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                pinnedCard,
              ],
            ),
          );
        },
      ),
    );
  }

  List<_StandardLeaderboardEntry> _resolveStandardEntries(
    List<Map<String, dynamic>> rankings,
    _LeaderboardTab tab,
  ) {
    switch (tab) {
      case _LeaderboardTab.global:
        final resolved = <_StandardLeaderboardEntry>[];
        for (final row in rankings) {
          resolved.add(
            _StandardLeaderboardEntry(
              rank: (row['rank'] as num?)?.toInt() ?? resolved.length + 1,
              name: row['name']?.toString() ?? 'Fan',
              fetValue: _coerceInt(row['fet']),
            ),
          );
        }
        return resolved.isEmpty ? _weeklyEntries : resolved;
      case _LeaderboardTab.weekly:
        return _weeklyEntries;
      case _LeaderboardTab.friends:
        return _friendsEntries;
      case _LeaderboardTab.fanClubs:
        return const <_StandardLeaderboardEntry>[];
    }
  }

  int _coerceInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

enum _LeaderboardTab {
  global('Global'),
  weekly('Weekly'),
  friends('Friends'),
  fanClubs('Fan Clubs');

  const _LeaderboardTab(this.label);

  final String label;
}

class _LeaderboardTabChip extends StatelessWidget {
  const _LeaderboardTabChip({
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
            color: active ? FzColors.accent : inactiveColor,
            borderRadius: BorderRadius.circular(999),
            border: active
                ? null
                : Border.all(color: inactiveBorder, width: 1),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: FzColors.accent.withValues(alpha: 0.28),
                      blurRadius: 14,
                      spreadRadius: 0,
                    ),
                  ]
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

class _PodiumItem extends StatelessWidget {
  const _PodiumItem({
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

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry});

  final _StandardLeaderboardEntry entry;

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
          Text(
            '${entry.rank}',
            style: FzTypography.scoreCompact(color: muted),
          ),
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
            child: const Text(
              '👤',
              style: TextStyle(fontSize: 12),
            ),
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
              color: FzColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedUserCard extends StatelessWidget {
  const _PinnedUserCard({
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
    final rankLabel = rankAsync.when(
      data: (rank) => '#${rank ?? 42}',
      loading: () => '#42',
      error: (error, stackTrace) => '#42',
    );
    final balanceLabel = balanceAsync.when(
      data: (balance) => '+${_formatCompactFet(balance > 0 ? balance : 2100)} FET',
      loading: () => '+2.1k FET',
      error: (error, stackTrace) => '+2.1k FET',
    );

    return Positioned(
      left: 12,
      right: 12,
      bottom: bottomOffset,
      child: IgnorePointer(
        ignoring: true,
        child: Container(
          decoration: BoxDecoration(
            color: FzColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: FzColors.accent.withValues(alpha: 0.22)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Text(
                rankLabel,
                style: FzTypography.scoreCompact(color: FzColors.accent),
              ),
              const SizedBox(width: 12),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: surface3Color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: FzColors.accent.withValues(alpha: 0.3),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '👤',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                  ),
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

class _FanClubLeaderboardView extends StatelessWidget {
  const _FanClubLeaderboardView({
    super.key,
    required this.entries,
  });

  final List<_FanClubEntry> entries;

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
            border: Border(
              bottom: BorderSide(color: borderColor, width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (podium.length > 1)
                _ClubPodiumItem(entry: podium[1], pedestalHeight: 112),
              if (podium.length > 1) const SizedBox(width: 8),
              _ClubPodiumItem(entry: podium[0], pedestalHeight: 144),
              if (podium.length > 2) const SizedBox(width: 8),
              if (podium.length > 2)
                _ClubPodiumItem(entry: podium[2], pedestalHeight: 96),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            children: [
              for (final entry in rows) ...[
                _ClubLeaderboardRow(entry: entry),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ClubPodiumItem extends StatelessWidget {
  const _ClubPodiumItem({
    required this.entry,
    required this.pedestalHeight,
  });

  final _FanClubEntry entry;
  final double pedestalHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
                  width: 80,
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
                      '#${entry.rank}',
                      style: FzTypography.scoreCompact(color: textColor),
                    ),
                  ),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  entry.crest,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            entry.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${entry.fetLabel} FET',
            style: FzTypography.scoreCompact(color: FzColors.accent),
          ),
        ],
      ),
    );
  }
}

class _ClubLeaderboardRow extends StatelessWidget {
  const _ClubLeaderboardRow({required this.entry});

  final _FanClubEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
                Text(
                  '${entry.rank}',
                  style: FzTypography.scoreCompact(color: muted),
                ),
                const SizedBox(height: 2),
                Icon(
                  switch (entry.trend) {
                    _Trend.up => LucideIcons.trendingUp,
                    _Trend.down => LucideIcons.trendingDown,
                    _Trend.same => LucideIcons.minus,
                  },
                  size: 10,
                  color: switch (entry.trend) {
                    _Trend.up => FzColors.accent,
                    _Trend.down => FzColors.coral,
                    _Trend.same => muted,
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: surface3Color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              entry.crest,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                entry.fetLabel,
                style: FzTypography.scoreCompact(color: FzColors.accent),
              ),
              const SizedBox(height: 2),
              Text(
                'POOL',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: muted,
                  letterSpacing: 0.9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StandardLeaderboardEntry {
  const _StandardLeaderboardEntry({
    required this.rank,
    required this.name,
    required this.fetValue,
  });

  final int rank;
  final String name;
  final int fetValue;

  String get fetLabel => _formatCompactFet(fetValue);
}

class _FanClubEntry {
  const _FanClubEntry({
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
  final _Trend trend;

  String get fetLabel => _formatCompactFet(fetValue);
}

enum _Trend { up, down, same }

String _formatCompactFet(int value) {
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

const List<_StandardLeaderboardEntry> _weeklyEntries = <_StandardLeaderboardEntry>[
  _StandardLeaderboardEntry(rank: 1, name: 'SpartanKing', fetValue: 15200),
  _StandardLeaderboardEntry(rank: 2, name: 'MaltaFan', fetValue: 12400),
  _StandardLeaderboardEntry(rank: 3, name: 'PacevillePro', fetValue: 10100),
  _StandardLeaderboardEntry(rank: 4, name: 'User_4', fetValue: 6500),
  _StandardLeaderboardEntry(rank: 5, name: 'User_5', fetValue: 5500),
  _StandardLeaderboardEntry(rank: 6, name: 'User_6', fetValue: 4500),
  _StandardLeaderboardEntry(rank: 7, name: 'User_7', fetValue: 3500),
  _StandardLeaderboardEntry(rank: 8, name: 'User_8', fetValue: 2500),
];

const List<_StandardLeaderboardEntry> _friendsEntries = <_StandardLeaderboardEntry>[
  _StandardLeaderboardEntry(rank: 1, name: 'Marco_B', fetValue: 9800),
  _StandardLeaderboardEntry(rank: 2, name: 'Sarah_G', fetValue: 9100),
  _StandardLeaderboardEntry(rank: 3, name: 'Jake_C', fetValue: 8400),
  _StandardLeaderboardEntry(rank: 4, name: 'Isla_F', fetValue: 7600),
  _StandardLeaderboardEntry(rank: 5, name: 'Daniel_G', fetValue: 6900),
  _StandardLeaderboardEntry(rank: 6, name: 'Maria_T', fetValue: 6200),
];

const List<_FanClubEntry> _fanClubEntries = <_FanClubEntry>[
  _FanClubEntry(
    rank: 1,
    name: 'Hamrun S.',
    crest: 'H',
    fetValue: 620000,
    trend: _Trend.up,
  ),
  _FanClubEntry(
    rank: 2,
    name: 'Sliema W.',
    crest: 'S',
    fetValue: 450000,
    trend: _Trend.same,
  ),
  _FanClubEntry(
    rank: 3,
    name: 'Valletta FC',
    crest: 'V',
    fetValue: 310000,
    trend: _Trend.up,
  ),
  _FanClubEntry(
    rank: 4,
    name: 'Floriana',
    crest: 'F',
    fetValue: 280000,
    trend: _Trend.up,
  ),
  _FanClubEntry(
    rank: 5,
    name: 'Birkirkara',
    crest: 'B',
    fetValue: 210000,
    trend: _Trend.down,
  ),
  _FanClubEntry(
    rank: 6,
    name: 'Hibernians',
    crest: 'H',
    fetValue: 195000,
    trend: _Trend.same,
  ),
  _FanClubEntry(
    rank: 7,
    name: 'Balzan FC',
    crest: 'B',
    fetValue: 150000,
    trend: _Trend.up,
  ),
];

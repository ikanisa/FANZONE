import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../models/community_contest_model.dart';
import '../../../providers/community_contest_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/match/match_list_widgets.dart';

/// Community prediction contests — fan club vs fan club.
class CommunityContestsScreen extends ConsumerStatefulWidget {
  const CommunityContestsScreen({super.key});

  @override
  ConsumerState<CommunityContestsScreen> createState() =>
      _CommunityContestsScreenState();
}

class _CommunityContestsScreenState
    extends ConsumerState<CommunityContestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'FAN CONTESTS',
          style: FzTypography.display(
            size: 28,
            color: isDark ? FzColors.darkText : FzColors.lightText,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: FzColors.accent,
          labelColor: FzColors.accent,
          unselectedLabelColor: muted,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          tabs: const [
            Tab(text: 'OPEN'),
            Tab(text: 'RESULTS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OpenContestsTab(),
          _SettledContestsTab(),
        ],
      ),
    );
  }
}

class _OpenContestsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contestsAsync = ref.watch(openContestsProvider);

    return contestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => StateView.error(
        title: 'Could not load contests',
        onRetry: () => ref.invalidate(openContestsProvider),
      ),
      data: (contests) {
        if (contests.isEmpty) {
          return StateView.empty(
            title: 'No open contests',
            subtitle:
                'Fan club contests appear automatically for matches between teams with active communities.',
            icon: LucideIcons.swords,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: contests.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ContestCard(contest: contests[index]),
            );
          },
        );
      },
    );
  }
}

class _SettledContestsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settledAsync = ref.watch(settledContestsProvider);

    return settledAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => StateView.error(
        title: 'Could not load results',
        onRetry: () => ref.invalidate(settledContestsProvider),
      ),
      data: (contests) {
        if (contests.isEmpty) {
          return StateView.empty(
            title: 'No results yet',
            subtitle: 'Settled contest results will appear here.',
            icon: LucideIcons.trophy,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: contests.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ContestCard(
                  contest: contests[index], showResult: true),
            );
          },
        );
      },
    );
  }
}

class _ContestCard extends StatelessWidget {
  const _ContestCard({
    required this.contest,
    this.showResult = false,
  });

  final CommunityContest contest;
  final bool showResult;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    final homeWins =
        contest.isSettled && contest.winningFanClub == contest.homeTeamId;
    final awayWins =
        contest.isSettled && contest.winningFanClub == contest.awayTeamId;

    return FzCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  FzColors.accent.withValues(alpha: 0.1),
                  FzColors.accent.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.swords, size: 16, color: FzColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    contest.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Status
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: contest.isOpen
                        ? FzColors.success.withValues(alpha: 0.15)
                        : muted.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    contest.isOpen
                        ? 'OPEN'
                        : contest.isLocked
                            ? 'LOCKED'
                            : 'SETTLED',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: contest.isOpen ? FzColors.success : muted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Teams face-off
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Home fan club
                Expanded(
                  child: _FanClubColumn(
                    teamId: contest.homeTeamId,
                    fanCount: contest.homeFanCount,
                    accuracy: contest.homeAccuracyAvg,
                    isWinner: homeWins,
                    showResult: showResult,
                    isDark: isDark,
                    muted: muted,
                  ),
                ),

                // VS divider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      const Text(
                        'VS',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: FzColors.accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${contest.totalFans} fans',
                        style: TextStyle(fontSize: 10, color: muted),
                      ),
                    ],
                  ),
                ),

                // Away fan club
                Expanded(
                  child: _FanClubColumn(
                    teamId: contest.awayTeamId,
                    fanCount: contest.awayFanCount,
                    accuracy: contest.awayAccuracyAvg,
                    isWinner: awayWins,
                    showResult: showResult,
                    isDark: isDark,
                    muted: muted,
                  ),
                ),
              ],
            ),
          ),

          // Join CTA (only for open contests)
          if (contest.isOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    // Navigate to contest entry — wired in routing
                  },
                  icon: const Icon(LucideIcons.target, size: 16),
                  label: const Text('Join Contest'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FzColors.accent,
                    side: BorderSide(
                      color: FzColors.accent.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FanClubColumn extends StatelessWidget {
  const _FanClubColumn({
    required this.teamId,
    required this.fanCount,
    required this.accuracy,
    required this.isWinner,
    required this.showResult,
    required this.isDark,
    required this.muted,
  });

  final String teamId;
  final int fanCount;
  final double accuracy;
  final bool isWinner;
  final bool showResult;
  final bool isDark;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final teamLabel = teamId.length > 6
        ? '${teamId.substring(0, 6)}...'
        : teamId;

    return Column(
      children: [
        // Team avatar
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isWinner
                ? FzColors.amber.withValues(alpha: 0.15)
                : (isDark
                    ? FzColors.darkSurface3
                    : FzColors.lightSurface3),
            border: isWinner
                ? Border.all(color: FzColors.amber, width: 2)
                : null,
          ),
          child: Center(
            child: isWinner
                ? const Icon(LucideIcons.crown, size: 20,
                    color: FzColors.amber)
                : TeamAvatar(name: teamLabel, size: 48),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$fanCount fans',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isWinner ? FzColors.amber : muted,
          ),
        ),
        if (showResult && accuracy > 0)
          Text(
            '${accuracy.toStringAsFixed(1)}% avg',
            style: TextStyle(fontSize: 10, color: muted),
          ),
      ],
    );
  }
}

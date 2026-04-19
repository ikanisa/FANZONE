import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/market/launch_market.dart';
import '../../../data/team_search_database.dart';
import '../../../providers/market_preferences_provider.dart';
import '../../../providers/matches_provider.dart';
import '../../../services/team_community_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_badge.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/match/match_list_widgets.dart';

class HomeFeedScreen extends ConsumerWidget {
  const HomeFeedScreen({super.key});

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final matchesAsync = ref.watch(matchesByDateProvider(_today));
    final primaryRegion = ref.watch(primaryMarketRegionProvider);
    final supportedIds =
        ref.watch(supportedTeamsServiceProvider).valueOrNull ??
        const <String>{};

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: FzColors.accent,
          onRefresh: () async {
            ref.invalidate(matchesByDateProvider(_today));
            await ref.read(matchesByDateProvider(_today).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Predictions',
                      style: FzTypography.display(
                        size: 36,
                        color: textColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  _RoundActionButton(
                    tooltip: 'Open pools',
                    backgroundColor: FzColors.coral,
                    foregroundColor: FzColors.darkBg,
                    icon: LucideIcons.plusCircle,
                    onTap: () => context.go('/predict'),
                  ),
                  const SizedBox(width: 8),
                  _RoundActionButton(
                    tooltip: 'Open Fan ID',
                    icon: LucideIcons.shield,
                    onTap: () => context.go('/clubs/fan-id'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              matchesAsync.when(
                data: (matches) {
                  final liveMatches =
                      matches.where((match) => match.isLive).toList()
                        ..sort((a, b) => a.date.compareTo(b.date));
                  final upcomingMatches =
                      matches.where((match) => match.isUpcoming).toList()
                        ..sort((a, b) => a.date.compareTo(b.date));
                  final insightTeam = _resolveInsightTeam(supportedIds);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DailyInsightCard(
                        muted: muted,
                        teamName: insightTeam?.name,
                        primaryRegion: primaryRegion,
                        liveCount: liveMatches.length,
                        upcomingCount: upcomingMatches.length,
                      ),
                      const SizedBox(height: 24),
                      _HomeSectionHeader(
                        icon: LucideIcons.activity,
                        iconColor: FzColors.danger,
                        title: 'Live Action',
                        trailing: FzBadge(
                          label: '${liveMatches.length}',
                          color: FzColors.danger,
                          textColor: Colors.white,
                          pulse: liveMatches.isNotEmpty,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (liveMatches.isEmpty)
                        _CompactEmptyCard(
                          icon: LucideIcons.trophy,
                          title: 'No Live Matches',
                          subtitle:
                              'Check the upcoming slate and lock your next picks.',
                          muted: muted,
                        )
                      else
                        MatchListCard(
                          matches: liveMatches.take(4).toList(),
                          onTapMatch: (match) =>
                              context.push('/match/${match.id}'),
                        ),
                      const SizedBox(height: 24),
                      _HomeSectionHeader(
                        icon: LucideIcons.calendar,
                        iconColor: muted,
                        title: 'Upcoming',
                        trailing: IconButton(
                          onPressed: () => context.go('/scores'),
                          tooltip: 'Open score centre',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            LucideIcons.chevronRight,
                            size: 18,
                            color: muted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (upcomingMatches.isEmpty)
                        _CompactEmptyCard(
                          icon: LucideIcons.calendar,
                          title: 'No Upcoming Matches',
                          subtitle:
                              'The next prediction window will appear here.',
                          muted: muted,
                        )
                      else
                        MatchListCard(
                          matches: upcomingMatches.take(6).toList(),
                          onTapMatch: (match) =>
                              context.push('/match/${match.id}'),
                        ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: StateView.error(
                    title: 'Could not load predictions',
                    subtitle: 'Pull to refresh and try again.',
                    onRetry: () =>
                        ref.invalidate(matchesByDateProvider(_today)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  OnboardingTeam? _resolveInsightTeam(Set<String> supportedIds) {
    for (final team in allTeams) {
      if (supportedIds.contains(team.id)) return team;
    }
    return null;
  }
}

class _DailyInsightCard extends StatelessWidget {
  const _DailyInsightCard({
    required this.muted,
    required this.teamName,
    required this.primaryRegion,
    required this.liveCount,
    required this.upcomingCount,
  });

  final Color muted;
  final String? teamName;
  final String primaryRegion;
  final int liveCount;
  final int upcomingCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final marketLabel = launchRegionLabel(primaryRegion).toLowerCase();
    final insight = teamName != null
        ? '$teamName is in focus today. $liveCount live match window${liveCount == 1 ? '' : 's'} and $upcomingCount upcoming prediction slot${upcomingCount == 1 ? '' : 's'} are active across $marketLabel.'
        : '$liveCount live match window${liveCount == 1 ? '' : 's'} and $upcomingCount upcoming prediction slot${upcomingCount == 1 ? '' : 's'} are active across $marketLabel. Stay close to the next kickoff and lock slips early.';

    return FzCard(
      padding: const EdgeInsets.all(16),
      borderColor: FzColors.success.withValues(alpha: 0.18),
      child: Stack(
        children: [
          Positioned(
            top: -22,
            right: -18,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FzColors.success.withValues(alpha: 0.08),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: FzColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: FzColors.success.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  LucideIcons.sparkles,
                  size: 16,
                  color: FzColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Insight',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: muted,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      insight,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeSectionHeader extends StatelessWidget {
  const _HomeSectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkText
        : FzColors.lightText;

    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
        trailing,
      ],
    );
  }
}

class _CompactEmptyCard extends StatelessWidget {
  const _CompactEmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.muted,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: FzColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 18, color: FzColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: muted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color:
                backgroundColor ??
                (isDark ? FzColors.darkSurface2 : FzColors.lightSurface2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color:
                foregroundColor ??
                (isDark ? FzColors.darkText : FzColors.lightText),
          ),
        ),
      ),
    );
  }
}

part of '../../screens/match_detail_screen.dart';

class _StatsTab extends ConsumerWidget {
  const _StatsTab({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final advancedAsync = ref.watch(matchAdvancedStatsProvider(match.id));

    final hasScores = match.ftHome != null && match.ftAway != null;
    final totalHome = match.ftHome ?? 0;
    final totalAway = match.ftAway ?? 0;

    return advancedAsync.when(
      data: (stats) {
        if (stats == null || !stats.hasData) {
          if (!hasScores && !match.isLive) {
            return Center(
              child: StateView.empty(
                title: 'Stats not available yet',
                subtitle: 'Statistics appear after kickoff.',
                icon: Icons.bar_chart_rounded,
              ),
            );
          }
          return _BasicStatsView(
            match: match,
            isDark: isDark,
            muted: muted,
            totalHome: totalHome,
            totalAway: totalAway,
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (stats.homeXg != null && stats.awayXg != null) ...[
              Text(
                'Expected Goals (xG)',
                style: FzTypography.sectionLabel(Theme.of(context).brightness),
              ),
              const SizedBox(height: 12),
              FzCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            stats.homeXg!.toStringAsFixed(2),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: stats.homeXg! > stats.awayXg!
                                  ? FzColors.accent
                                  : (isDark
                                        ? FzColors.darkText
                                        : FzColors.lightText),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            match.homeTeam,
                            style: TextStyle(fontSize: 11, color: muted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: FzColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'xG',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: FzColors.accent,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            stats.awayXg!.toStringAsFixed(2),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: stats.awayXg! > stats.homeXg!
                                  ? FzColors.accent
                                  : (isDark
                                        ? FzColors.darkText
                                        : FzColors.lightText),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            match.awayTeam,
                            style: TextStyle(fontSize: 11, color: muted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            if (stats.homePossession != null) ...[
              Text(
                'Possession',
                style: FzTypography.sectionLabel(Theme.of(context).brightness),
              ),
              const SizedBox(height: 12),
              FzCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text(
                          '${stats.homePossession}%',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: FzColors.accent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          match.homeTeam,
                          style: TextStyle(fontSize: 11, color: muted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CustomPaint(
                        painter: _PossessionRingPainter(
                          homePercent: stats.homePossession!,
                          isDark: isDark,
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '${stats.awayPossession ?? (100 - stats.homePossession!)}%',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? FzColors.darkText
                                : FzColors.lightText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          match.awayTeam,
                          style: TextStyle(fontSize: 11, color: muted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            Text(
              'Match Statistics',
              style: FzTypography.sectionLabel(Theme.of(context).brightness),
            ),
            const SizedBox(height: 12),
            FzCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _DualStatBar(
                    label: 'Goals',
                    leftValue: totalHome.toDouble(),
                    rightValue: totalAway.toDouble(),
                    leftLabel: '$totalHome',
                    rightLabel: '$totalAway',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                  _DualStatBar(
                    label: 'Shots',
                    leftValue: stats.homeShots.toDouble(),
                    rightValue: stats.awayShots.toDouble(),
                    leftLabel: '${stats.homeShots}',
                    rightLabel: '${stats.awayShots}',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                  _DualStatBar(
                    label: 'Shots on Target',
                    leftValue: stats.homeShotsOnTarget.toDouble(),
                    rightValue: stats.awayShotsOnTarget.toDouble(),
                    leftLabel: '${stats.homeShotsOnTarget}',
                    rightLabel: '${stats.awayShotsOnTarget}',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                  _DualStatBar(
                    label: 'Corners',
                    leftValue: stats.homeCorners.toDouble(),
                    rightValue: stats.awayCorners.toDouble(),
                    leftLabel: '${stats.homeCorners}',
                    rightLabel: '${stats.awayCorners}',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                  _DualStatBar(
                    label: 'Fouls',
                    leftValue: stats.homeFouls.toDouble(),
                    rightValue: stats.awayFouls.toDouble(),
                    leftLabel: '${stats.homeFouls}',
                    rightLabel: '${stats.awayFouls}',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                  _DualStatBar(
                    label: 'Yellow Cards',
                    leftValue: stats.homeYellowCards.toDouble(),
                    rightValue: stats.awayYellowCards.toDouble(),
                    leftLabel: '${stats.homeYellowCards}',
                    rightLabel: '${stats.awayYellowCards}',
                    isDark: isDark,
                  ),
                  if (stats.homeRedCards > 0 || stats.awayRedCards > 0) ...[
                    const SizedBox(height: 14),
                    _DualStatBar(
                      label: 'Red Cards',
                      leftValue: stats.homeRedCards.toDouble(),
                      rightValue: stats.awayRedCards.toDouble(),
                      leftLabel: '${stats.homeRedCards}',
                      rightLabel: '${stats.awayRedCards}',
                      isDark: isDark,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            FzCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    label: 'Source',
                    value: stats.dataSource,
                    muted: muted,
                  ),
                  if (stats.refreshedAt != null)
                    _InfoRow(
                      label: 'Updated',
                      value: DateFormat(
                        'HH:mm, d MMM',
                      ).format(stats.refreshedAt!),
                      muted: muted,
                    ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const FzGlassLoader(message: 'Syncing...'),
      error: (err, st) => _BasicStatsView(
        match: match,
        isDark: isDark,
        muted: muted,
        totalHome: totalHome,
        totalAway: totalAway,
      ),
    );
  }
}

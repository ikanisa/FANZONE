import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../models/leaderboard_season_model.dart';
import '../../../providers/seasonal_leaderboard_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/fan/fan_identity_widgets.dart';

/// Seasonal leaderboard screen — active seasons with tabbed rankings.
class SeasonalLeaderboardScreen extends ConsumerWidget {
  const SeasonalLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasonsAsync = ref.watch(activeLeaderboardSeasonsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SEASONS',
          style: FzTypography.display(
            size: 28,
            color: isDark ? FzColors.darkText : FzColors.lightText,
          ),
        ),
      ),
      body: seasonsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => StateView.error(
          title: 'Could not load seasons',
          onRetry: () => ref.invalidate(activeLeaderboardSeasonsProvider),
        ),
        data: (seasons) {
          if (seasons.isEmpty) {
            return StateView.empty(
              title: 'No active seasons',
              subtitle:
                  'Seasonal competitions will appear here when they begin.',
              icon: LucideIcons.trophy,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: seasons.length,
            itemBuilder: (context, index) {
              final season = seasons[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _SeasonCard(season: season),
              );
            },
          );
        },
      ),
    );
  }
}

class _SeasonCard extends ConsumerWidget {
  const _SeasonCard({required this.season});

  final LeaderboardSeason season;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingsAsync = ref.watch(seasonRankingsProvider(season.id));
    final userEntryAsync = ref.watch(userSeasonEntryProvider(season.id));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final dateFormat = DateFormat('d MMM');

    final statusColor = season.isActive ? FzColors.success : FzColors.amber;

    return FzCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  statusColor.withValues(alpha: 0.12),
                  statusColor.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(LucideIcons.trophy, size: 18, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        season.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            season.typeLabel,
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                          Text(' · ', style: TextStyle(color: muted)),
                          Text(
                            '${dateFormat.format(season.startsAt)} – ${dateFormat.format(season.endsAt)}',
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    season.isActive
                        ? '${season.daysRemaining}d left'
                        : 'Upcoming',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Prize pool if any
          if (season.prizePoolFet > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.coins,
                    size: 14,
                    color: FzColors.amber,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${season.prizePoolFet} FET Prize Pool',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: FzColors.amber,
                    ),
                  ),
                ],
              ),
            ),

          // User's position
          userEntryAsync.when(
            data: (entry) {
              if (entry == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: FzCard(
                  padding: const EdgeInsets.all(12),
                  borderColor: FzColors.accent.withValues(alpha: 0.3),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: FzColors.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            entry.rank != null ? '#${entry.rank}' : '—',
                            style: FzTypography.scoreCompact(
                              color: FzColors.accent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Ranking',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${entry.points} pts · ${entry.accuracy.toStringAsFixed(0)}% accuracy',
                              style: TextStyle(fontSize: 11, color: muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'Your ranking is unavailable right now.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ),
          ),

          // Top 5 rankings
          rankingsAsync.when(
            data: (rankings) {
              if (rankings.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No rankings yet. Start predicting!',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                );
              }

              final top5 = rankings.take(5).toList();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOP 5',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: muted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...top5.asMap().entries.map((e) {
                      final idx = e.key;
                      final entry = e.value;
                      final isTop3 = idx < 3;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text(
                                '${idx + 1}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isTop3 ? FzColors.amber : muted,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Avatar
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? FzColors.darkSurface3
                                    : FzColors.lightSurface3,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  entry.name.isNotEmpty ? entry.name[0] : '?',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (entry.currentLevel != null &&
                                entry.currentLevel! > 1)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FanLevelBadge(
                                  level: entry.currentLevel!,
                                  title: '',
                                  colorValue: _levelColor(entry.currentLevel!),
                                  compact: true,
                                ),
                              ),
                            Text(
                              '${entry.points}',
                              style: FzTypography.scoreCompact(
                                color: FzColors.accent,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'pts',
                              style: TextStyle(fontSize: 9, color: muted),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Season rankings could not be loaded.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static int _levelColor(int level) {
    const colors = {
      1: 0xFFA8A29E, // Stone muted
      2: 0xFF98FF98, // Mint Green
      3: 0xFF22D3EE, // Cyan
      4: 0xFF2563EB, // Blue
      5: 0xFFFF7F50, // Coral
      6: 0xFFEF4444, // Red
      7: 0xFFFFD700, // Gold
    };
    return colors[level] ?? 0xFFA8A29E;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/league_constants.dart';
import '../../../models/competition_model.dart';
import '../../../models/featured_event_model.dart';
import '../../../providers/competitions_provider.dart';
import '../../../providers/favourites_provider.dart';
import '../../../providers/featured_events_provider.dart';
import '../../../providers/market_preferences_provider.dart';
import '../../../providers/teams_provider.dart';
import '../../../theme/colors.dart';
import '../../../widgets/common/fz_animated_entry.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_shimmer.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/match/match_list_widgets.dart';

/// Leagues Discovery Screen — curated league browsing experience.
///
/// Layout:
///   1. Top 5 European Leagues (horizontal row + "Others" card)
///   2. Major Competitions (WC 2026, UCL, AFCON, etc.)
///   3. Your Local Leagues (personalised by user region)
///   4. Your Favorite Teams (from user followed teams)
class LeaguesDiscoveryScreen extends ConsumerWidget {
  const LeaguesDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    final top5Async = ref.watch(top5EuropeanLeaguesProvider);
    final majorCompsAsync = ref.watch(majorCompetitionsProvider);
    final primaryRegion = ref.watch(primaryMarketRegionProvider);
    final localLeaguesAsync = ref.watch(localLeaguesProvider(primaryRegion));
    final teamsAsync = ref.watch(teamsProvider);
    final favourites =
        ref.watch(favouritesProvider).valueOrNull ?? const FavouritesState();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: FzColors.accent,
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            ref.invalidate(top5EuropeanLeaguesProvider);
            ref.invalidate(majorCompetitionsProvider);
            ref.invalidate(localLeaguesProvider(primaryRegion));
            ref.invalidate(teamsProvider);
            await Future.wait([
              ref.read(top5EuropeanLeaguesProvider.future),
              ref.read(majorCompetitionsProvider.future),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              // ── Header ──
              Row(
                children: [
                  const Spacer(),
                  IconButton(
                    onPressed: () => context.push('/search'),
                    icon: const Icon(Icons.search_rounded, size: 22),
                    tooltip: 'Search',
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ═══ Section 1: Top 5 European Leagues ═══
              _SectionLabel(label: 'EUROPE', muted: muted),
              const SizedBox(height: 12),
              top5Async.when(
                data: (leagues) => _Top5Row(
                  leagues: leagues,
                  onTapLeague: (league) =>
                      context.push('/league/${league.id}'),
                  onTapOthers: () => context.push('/leagues/all'),
                ),
                loading: () => const _Top5Skeleton(),
                error: (_, _) => StateView.error(
                  title: 'Could not load leagues',
                  onRetry: () => ref.invalidate(top5EuropeanLeaguesProvider),
                ),
              ),
              const SizedBox(height: 28),

              // ═══ Section 2: Major Competitions ═══
              _SectionLabel(label: 'MAJOR TOURNAMENTS', muted: muted),
              const SizedBox(height: 12),
              majorCompsAsync.when(
                data: (events) {
                  if (events.isEmpty) {
                    return FzCard(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No major competitions active right now.',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    );
                  }
                  return _MajorCompetitionsGrid(events: events);
                },
                loading: () => const _MajorCompsSkeleton(),
                error: (_, _) => StateView.error(
                  title: 'Could not load competitions',
                  onRetry: () => ref.invalidate(majorCompetitionsProvider),
                ),
              ),
              const SizedBox(height: 28),

              // ═══ Section 3: Your Local Leagues ═══
              _SectionLabel(label: 'LOCAL', muted: muted),
              const SizedBox(height: 12),
              localLeaguesAsync.when(
                data: (locals) {
                  if (locals.isEmpty) {
                    return FzCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(LucideIcons.mapPin, size: 16, color: muted),
                          const SizedBox(width: 10),
                          Text(
                            'None for your region',
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (int i = 0; i < locals.length; i++) ...[
                        FzAnimatedEntry(
                          index: i,
                          child: _LeagueListTile(
                            league: locals[i],
                            onTap: () =>
                                context.push('/league/${locals[i].id}'),
                          ),
                        ),
                        if (i < locals.length - 1) const SizedBox(height: 8),
                      ],
                    ],
                  );
                },
                loading: () => const _LocalLeaguesSkeleton(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 28),

              // ═══ Section 4: Your Favorite Teams ═══
              if (favourites.teamIds.isNotEmpty) ...[
                _SectionLabel(label: 'FAVORITES', muted: muted),
                const SizedBox(height: 12),
                teamsAsync.when(
                  data: (allTeams) {
                    final favTeams = allTeams
                        .where((t) => favourites.isTeamFavourite(t.id))
                        .toList()
                      ..sort((a, b) => a.name.compareTo(b.name));

                    if (favTeams.isEmpty) return const SizedBox.shrink();

                    return SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: favTeams.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final team = favTeams[index];
                          return GestureDetector(
                            onTap: () =>
                                context.push('/clubs/team/${team.id}'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 72,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? FzColors.darkSurface2
                                    : FzColors.lightSurface2,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? FzColors.darkBorder
                                      : FzColors.lightBorder,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TeamAvatar(name: team.name, size: 36),
                                  const SizedBox(height: 4),
                                  Text(
                                    team.shortName ?? team.name,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: muted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// Section Label Widget
// ═════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.muted});

  final String label;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: muted,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// Top 5 European Leagues Row
// ═════════════════════════════════════════════════════════════════

class _Top5Row extends StatelessWidget {
  const _Top5Row({
    required this.leagues,
    required this.onTapLeague,
    required this.onTapOthers,
  });

  final List<CompetitionModel> leagues;
  final void Function(CompetitionModel) onTapLeague;
  final VoidCallback onTapOthers;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: leagues.length + 1, // +1 for "Others"
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index == leagues.length) {
            // "Others" card
            return GestureDetector(
              onTap: onTapOthers,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      FzColors.accent.withValues(alpha: 0.08),
                      FzColors.accent.withValues(alpha: 0.18),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: FzColors.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: FzColors.accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.globe2,
                        size: 20,
                        color: FzColors.accent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Others',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: FzColors.accent,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final league = leagues[index];
          final flag = flagForCountry(league.country);
          final label =
              kTop5LeagueLabels[league.country] ?? league.shortName;

          return GestureDetector(
            onTap: () => onTapLeague(league),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 72,
              decoration: BoxDecoration(
                color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(flag, style: const TextStyle(fontSize: 28)),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: muted,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// Major Competitions Grid
// ═════════════════════════════════════════════════════════════════

class _MajorCompetitionsGrid extends StatelessWidget {
  const _MajorCompetitionsGrid({required this.events});

  final List<FeaturedEventModel> events;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: events.map((event) {
        final color = event.bannerColor != null
            ? Color(int.parse(event.bannerColor!.replaceFirst('#', '0xFF')))
            : FzColors.accent;

        final dateLabel = event.isCurrentlyActive
            ? 'LIVE NOW'
            : event.daysUntilStart > 0
                ? DateFormat('MMM yyyy').format(event.startDate)
                : 'ENDED';

        return GestureDetector(
          onTap: () => context.push('/event/${event.eventTag}'),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: (MediaQuery.of(context).size.width - 42) / 2,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.08),
                  color.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: event.isCurrentlyActive
                          ? FzColors.live
                          : color,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  event.shortName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark ? FzColors.darkText : FzColors.lightText,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  event.name,
                  style: TextStyle(fontSize: 11, color: muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// League List Tile (for local leagues)
// ═════════════════════════════════════════════════════════════════

class _LeagueListTile extends StatelessWidget {
  const _LeagueListTile({required this.league, required this.onTap});

  final CompetitionModel league;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final flag = flagForCountry(league.country);

    return FzCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  league.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  league.country,
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: muted,
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// Skeleton Loaders
// ═════════════════════════════════════════════════════════════════

class _Top5Skeleton extends StatelessWidget {
  const _Top5Skeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, _) => const FzShimmer(
          width: 72,
          height: 100,
          borderRadius: 16,
        ),
      ),
    );
  }
}

class _MajorCompsSkeleton extends StatelessWidget {
  const _MajorCompsSkeleton();

  @override
  Widget build(BuildContext context) {
    final halfWidth = (MediaQuery.of(context).size.width - 42) / 2;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(
        4,
        (_) => FzShimmer(width: halfWidth, height: 90, borderRadius: 16),
      ),
    );
  }
}

class _LocalLeaguesSkeleton extends StatelessWidget {
  const _LocalLeaguesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        2,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: FzShimmer(width: double.infinity, height: 56, borderRadius: 14),
        ),
      ),
    );
  }
}

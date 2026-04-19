import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/league_constants.dart';
import '../../../data/team_search_database.dart';
import '../../../models/competition_model.dart';
import '../../../models/featured_event_model.dart';
import '../../../providers/competitions_provider.dart';
import '../../../providers/favorite_teams_provider.dart';
import '../../../providers/featured_events_provider.dart';
import '../../../providers/market_preferences_provider.dart';
import '../../../theme/colors.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_shimmer.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/match/match_list_widgets.dart';

/// Leagues Discovery Screen — curated league browsing experience.
///
/// Layout:
///   1. For You (local league + supported teams)
///   2. Top European Leagues
///   3. Major Competitions (WC 2026, UCL, AFCON, etc.)
class LeaguesDiscoveryScreen extends ConsumerWidget {
  const LeaguesDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(body: SafeArea(child: LeaguesDiscoveryContent()));
  }
}

class LeaguesDiscoveryContent extends ConsumerWidget {
  const LeaguesDiscoveryContent({
    super.key,
    this.showSearchAction = true,
    this.topPadding = 16,
    this.bottomPadding = 120,
  });

  final bool showSearchAction;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    final top5Async = ref.watch(top5EuropeanLeaguesProvider);
    final majorCompsAsync = ref.watch(majorCompetitionsProvider);
    final primaryRegion = ref.watch(primaryMarketRegionProvider);
    final localLeaguesAsync = ref.watch(localLeaguesProvider(primaryRegion));
    final favoriteTeamsAsync = ref.watch(favoriteTeamRecordsProvider);

    return RefreshIndicator(
      color: FzColors.accent,
      onRefresh: () async {
        await HapticFeedback.mediumImpact();
        ref.invalidate(top5EuropeanLeaguesProvider);
        ref.invalidate(majorCompetitionsProvider);
        ref.invalidate(localLeaguesProvider(primaryRegion));
        ref.invalidate(favoriteTeamRecordsProvider);
        await Future.wait([
          ref.read(top5EuropeanLeaguesProvider.future),
          ref.read(majorCompetitionsProvider.future),
        ]);
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, topPadding, 16, bottomPadding),
        children: [
          // ── Header ──
          if (showSearchAction) ...[
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
          ],

          if (_shouldShowForYou(
            localLeagues: localLeaguesAsync.valueOrNull,
            favoriteTeams: favoriteTeamsAsync.valueOrNull,
            localLeaguesLoading: localLeaguesAsync.isLoading,
            favoriteTeamsLoading: favoriteTeamsAsync.isLoading,
          )) ...[
            const _SectionLabel(
              label: 'For You',
              icon: LucideIcons.star,
              iconColor: FzColors.coral,
            ),
            const SizedBox(height: 12),
            _ForYouSection(
              localLeaguesAsync: localLeaguesAsync,
              favoriteTeamsAsync: favoriteTeamsAsync,
            ),
            const SizedBox(height: 28),
          ],

          const _SectionLabel(
            label: 'Europe',
            icon: LucideIcons.globe2,
            iconColor: FzColors.accent,
          ),
          const SizedBox(height: 12),
          top5Async.when(
            data: (leagues) => _Top5Row(
              leagues: leagues,
              onTapLeague: (league) => context.push('/league/${league.id}'),
              onTapOthers: () => context.push('/leagues/all'),
            ),
            loading: () => const _Top5Skeleton(),
            error: (_, _) => StateView.error(
              title: 'Could not load leagues',
              onRetry: () => ref.invalidate(top5EuropeanLeaguesProvider),
            ),
          ),
          const SizedBox(height: 28),

          const _SectionLabel(
            label: 'Major Tournaments',
            icon: LucideIcons.trophy,
            iconColor: FzColors.coral,
          ),
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
        ],
      ),
    );
  }

  bool _shouldShowForYou({
    required List<CompetitionModel>? localLeagues,
    required List<FavoriteTeamRecordDto>? favoriteTeams,
    required bool localLeaguesLoading,
    required bool favoriteTeamsLoading,
  }) {
    return localLeaguesLoading ||
        favoriteTeamsLoading ||
        (localLeagues?.isNotEmpty ?? false) ||
        (favoriteTeams?.isNotEmpty ?? false);
  }
}

// ═════════════════════════════════════════════════════════════════
// Section Label Widget
// ═════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.label,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).brightness == Brightness.dark
                ? FzColors.darkText
                : FzColors.lightText,
          ),
        ),
      ],
    );
  }
}

class _ForYouSection extends StatelessWidget {
  const _ForYouSection({
    required this.localLeaguesAsync,
    required this.favoriteTeamsAsync,
  });

  final AsyncValue<List<CompetitionModel>> localLeaguesAsync;
  final AsyncValue<List<FavoriteTeamRecordDto>> favoriteTeamsAsync;

  @override
  Widget build(BuildContext context) {
    final localLeagues =
        localLeaguesAsync.valueOrNull ?? const <CompetitionModel>[];
    final favoriteTeams =
        favoriteTeamsAsync.valueOrNull ?? const <FavoriteTeamRecordDto>[];

    if (localLeaguesAsync.isLoading || favoriteTeamsAsync.isLoading) {
      return const _ForYouSkeleton();
    }

    final items = <_ForYouCardData>[
      if (localLeagues.isNotEmpty)
        _ForYouCardData.localLeague(league: localLeagues.first),
      ...favoriteTeams.map(_ForYouCardData.favoriteTeam),
    ];

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length > 6 ? 6 : items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.92,
      ),
      itemBuilder: (context, index) => _ForYouCard(item: items[index]),
    );
  }
}

class _ForYouCardData {
  const _ForYouCardData({
    required this.label,
    required this.caption,
    required this.route,
    this.teamName,
    this.teamCrestUrl,
    this.flag,
  });

  factory _ForYouCardData.localLeague({required CompetitionModel league}) {
    return _ForYouCardData(
      label: league.name,
      caption: league.country,
      route: '/league/${league.id}',
      flag: flagForCountry(league.country),
    );
  }

  factory _ForYouCardData.favoriteTeam(FavoriteTeamRecordDto team) {
    return _ForYouCardData(
      label: team.teamName,
      caption: 'Favorite',
      route: '/team/${team.teamId}',
      teamName: team.teamName,
      teamCrestUrl: team.teamCrestUrl,
    );
  }

  final String label;
  final String caption;
  final String route;
  final String? teamName;
  final String? teamCrestUrl;
  final String? flag;
}

class _ForYouCard extends StatelessWidget {
  const _ForYouCard({required this.item});

  final _ForYouCardData item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return FzCard(
      onTap: () => context.push(item.route),
      color: isDark ? FzColors.darkSurface : FzColors.lightSurface,
      borderColor: isDark ? FzColors.darkBorder : FzColors.lightBorder,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
              ),
            ),
            alignment: Alignment.center,
            child: item.teamName != null
                ? TeamAvatar(
                    name: item.teamName!,
                    logoUrl: item.teamCrestUrl,
                    size: 22,
                  )
                : Text(item.flag ?? '🌍', style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 8),
          Text(
            item.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).brightness == Brightness.dark
                  ? FzColors.darkText
                  : FzColors.lightText,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, color: muted),
          ),
        ],
      ),
    );
  }
}

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
    return Column(
      children: [
        for (int index = 0; index < leagues.length; index++) ...[
          _LeagueListTile(
            league: leagues[index],
            onTap: () => onTapLeague(leagues[index]),
          ),
          if (index < leagues.length - 1) const SizedBox(height: 8),
        ],
        const SizedBox(height: 10),
        _OthersLeaguesButton(onTap: onTapOthers),
      ],
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
                      color: event.isCurrentlyActive ? FzColors.live : color,
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
                    color: isDark ? FzColors.darkText : FzColors.lightText,
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
    final label = kTop5LeagueLabels[league.country] ?? league.shortName;

    return FzCard(
      onTap: onTap,
      color: isDark ? FzColors.darkSurface : FzColors.lightSurface,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 14,
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  league.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${league.country} · $label',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: muted),
        ],
      ),
    );
  }
}

class _OthersLeaguesButton extends StatelessWidget {
  const _OthersLeaguesButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? FzColors.darkSurface2.withValues(alpha: 0.55)
              : FzColors.lightSurface2.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              LucideIcons.chevronDown,
              size: 14,
              color: FzColors.accent,
            ),
            const SizedBox(width: 8),
            Text(
              'Other Leagues',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: muted,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
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
    return Column(
      children: List.generate(
        5,
        (index) => const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: FzShimmer(
            width: double.infinity,
            height: 52,
            borderRadius: 14,
          ),
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

class _ForYouSkeleton extends StatelessWidget {
  const _ForYouSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.92,
      ),
      itemBuilder: (_, _) => const FzShimmer(
        width: double.infinity,
        height: 110,
        borderRadius: 16,
      ),
    );
  }
}

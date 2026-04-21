import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../models/competition_model.dart';
import '../../../models/match_model.dart';
import '../../../providers/competitions_provider.dart';
import '../../../providers/favourites_provider.dart';
import '../../../providers/matches_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_shimmer.dart';
import '../../../widgets/common/state_view.dart';
import '../widgets/fixtures_widgets.dart';

class FixturesScreen extends ConsumerStatefulWidget {
  const FixturesScreen({super.key});

  @override
  ConsumerState<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends ConsumerState<FixturesScreen> {
  late final List<DateTime> _dates;
  late DateTime _selectedDate;
  FixturesPrimaryView _activeView = FixturesPrimaryView.matches;
  String? _selectedCompetitionId;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    // Source-of-truth reference shows a compact 7-day rail.
    _dates = List.generate(
      7,
      (index) => DateTime(today.year, today.month, today.day + index - 2),
    );
    _selectedDate = DateTime(today.year, today.month, today.day);
  }

  Future<void> _onRefresh() async {
    await HapticFeedback.mediumImpact();
    ref.invalidate(matchesByDateProvider(_selectedDate));
    ref.invalidate(competitionsProvider);

    await Future.wait([
      ref.read(matchesByDateProvider(_selectedDate).future),
      ref.read(competitionsProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final matchesAsync = ref.watch(matchesByDateProvider(_selectedDate));
    final competitionsAsync = ref.watch(competitionsProvider);
    final top5Async = ref.watch(top5EuropeanLeaguesProvider);
    final localAsync = ref.watch(localLeaguesProvider('malta'));
    final favourites =
        ref.watch(favouritesProvider).valueOrNull ?? const FavouritesState();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Fixtures',
                      style: FzTypography.display(
                        size: 36,
                        color: isDark ? FzColors.darkText : FzColors.lightText,
                      ),
                    ),
                  ),
                  PrimaryViewToggle(
                    activeView: _activeView,
                    onSelected: (view) => setState(() => _activeView = view),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _activeView == FixturesPrimaryView.competitions
                    ? KeyedSubtree(
                        key: const ValueKey('fixtures-competitions'),
                        child: _FixturesCompetitionsView(
                          competitionsAsync: competitionsAsync,
                          top5Async: top5Async,
                          localAsync: localAsync,
                          favourites: favourites,
                        ),
                      )
                    : KeyedSubtree(
                        key: const ValueKey('fixtures-matches'),
                        child: _buildMatchesView(
                          context: context,
                          muted: muted,
                          isDark: isDark,
                          matchesAsync: matchesAsync,
                          competitionsAsync: competitionsAsync,
                          favourites: favourites,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchesView({
    required BuildContext context,
    required Color muted,
    required bool isDark,
    required AsyncValue<List<MatchModel>> matchesAsync,
    required AsyncValue<List<CompetitionModel>> competitionsAsync,
    required FavouritesState favourites,
  }) {
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: FzColors.primary,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? FzColors.darkSurface2
                          : FzColors.lightSurface2,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? FzColors.darkBorder
                            : FzColors.lightBorder,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _dates.length,
                        itemBuilder: (context, index) {
                          final date = _dates[index];
                          final selected = _isSameDate(date, _selectedDate);
                          return Padding(
                            padding: EdgeInsets.only(
                              left: index == 0 ? 0 : 6,
                              right: index == _dates.length - 1 ? 0 : 0,
                            ),
                            child: _FixtureDateChip(
                              date: date,
                              selected: selected,
                              onTap: () => setState(() => _selectedDate = date),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ToolbarIconButton(
                    tooltip: 'Calendar',
                    icon: LucideIcons.calendar,
                    muted: muted,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 42,
              child: matchesAsync.when(
                data: (matches) {
                  final competitionIds =
                      matches
                          .map((match) => match.competitionId)
                          .toSet()
                          .toList()
                        ..sort((left, right) {
                          final leftFav =
                              favourites.isCompetitionFavourite(left) ? 0 : 1;
                          final rightFav =
                              favourites.isCompetitionFavourite(right) ? 0 : 1;
                          if (leftFav != rightFav) {
                            return leftFav.compareTo(rightFav);
                          }
                          return left.compareTo(right);
                        });
                  final competitionLabels = {
                    for (final competition
                        in competitionsAsync.valueOrNull ?? const [])
                      competition.id: competition.shortName.isNotEmpty
                          ? competition.shortName
                          : competition.name,
                  };

                  return ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      FixtureStateChip(
                        label: 'All',
                        selected: _selectedCompetitionId == null,
                        onTap: () =>
                            setState(() => _selectedCompetitionId = null),
                      ),
                      ...competitionIds.map(
                        (competitionId) => FixtureStateChip(
                          label:
                              competitionLabels[competitionId] ??
                              _fixtureLeagueLabel(competitionId),
                          selected: _selectedCompetitionId == competitionId,
                          onTap: () => setState(
                            () => _selectedCompetitionId = competitionId,
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: const [
                    Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: FzShimmer(width: 72, height: 34, borderRadius: 18),
                    ),
                    Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: FzShimmer(width: 84, height: 34, borderRadius: 18),
                    ),
                  ],
                ),
                error: (error, stackTrace) => ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? FzColors.darkSurface2
                            : FzColors.lightSurface2,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        'Leagues unavailable',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? FzColors.darkMuted
                              : FzColors.lightMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          matchesAsync.when(
            data: (matches) {
              final filtered = _filterMatches(matches);
              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: StateView.empty(
                    title: 'No fixtures',
                    subtitle: 'Try another date or league.',
                    icon: LucideIcons.calendar,
                  ),
                );
              }
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FixtureGroupCard(
                    matches: filtered,
                    onOpenMatch: (match) => context.push('/match/${match.id}'),
                    onOpenPools: () => context.go('/pools'),
                  ),
                ),
              );
            },
            loading: () =>
                const SliverFillRemaining(child: ScoresPageSkeleton()),
            error: (error, stack) => SliverFillRemaining(
              hasScrollBody: false,
              child: StateView.fromError(
                error,
                onRetry: () =>
                    ref.invalidate(matchesByDateProvider(_selectedDate)),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }

  List<MatchModel> _filterMatches(List<MatchModel> matches) {
    final filtered = matches.where((match) {
      final competitionMatches = _selectedCompetitionId == null
          ? true
          : match.competitionId == _selectedCompetitionId;
      return competitionMatches;
    }).toList();

    filtered.sort((left, right) {
      if (left.isLive != right.isLive) return left.isLive ? -1 : 1;
      return left.date.compareTo(right.date);
    });
    return filtered;
  }

  String _fixtureLeagueLabel(String competitionId) {
    final normalized = competitionId.toLowerCase();
    if (normalized.contains('premier')) return 'Premier League';
    if (normalized.contains('la_liga') || normalized.contains('laliga')) {
      return 'La Liga';
    }
    if (normalized.contains('serie')) return 'Serie A';
    if (normalized.contains('champions') || normalized.contains('ucl')) {
      return 'UCL';
    }
    if (normalized.contains('malta')) return 'Malta Premier';
    return competitionId;
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}

class _FixtureDateChip extends StatelessWidget {
  const _FixtureDateChip({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 74,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? FzColors.darkSurface2 : FzColors.lightSurface2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? (isDark
                      ? FzColors.darkBorder.withValues(alpha: 0.5)
                      : FzColors.lightBorder.withValues(alpha: 0.5))
                : Colors.transparent,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 12,
                    spreadRadius: -8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('EEE').format(date).toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: selected ? textColor : muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('d MMM').format(date).toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
                color: selected ? textColor.withValues(alpha: 0.84) : muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FixturesCompetitionsView extends StatelessWidget {
  const _FixturesCompetitionsView({
    required this.competitionsAsync,
    required this.top5Async,
    required this.localAsync,
    required this.favourites,
  });

  final AsyncValue<List<CompetitionModel>> competitionsAsync;
  final AsyncValue<List<CompetitionModel>> top5Async;
  final AsyncValue<List<CompetitionModel>> localAsync;
  final FavouritesState favourites;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return competitionsAsync.when(
      data: (allCompetitions) {
        final local = localAsync.valueOrNull ?? const <CompetitionModel>[];
        final top5 = top5Async.valueOrNull ?? const <CompetitionModel>[];
        final favouriteCompetitions = allCompetitions
            .where(
              (competition) =>
                  favourites.competitionIds.contains(competition.id),
            )
            .toList(growable: false);
        final forYou = <CompetitionModel>[
          ...local,
          ...favouriteCompetitions.where(
            (competition) =>
                !local.any((existing) => existing.id == competition.id),
          ),
        ].take(3).toList(growable: false);
        final majorCompetitions = allCompetitions
            .where(
              (competition) =>
                  competition.name.toLowerCase().contains('champions') ||
                  competition.name.toLowerCase().contains('europa') ||
                  competition.name.toLowerCase().contains('world cup') ||
                  competition.name.toLowerCase().contains('euro') ||
                  competition.name.toLowerCase().contains('cup'),
            )
            .take(4)
            .toList(growable: false);
        final otherCompetitions = allCompetitions
            .where(
              (competition) =>
                  !forYou.any((existing) => existing.id == competition.id) &&
                  !top5.any((existing) => existing.id == competition.id) &&
                  !majorCompetitions.any(
                    (existing) => existing.id == competition.id,
                  ),
            )
            .take(5)
            .toList(growable: false);

        return ListView(
          key: const ValueKey('fixtures-competitions-list'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            const _CompetitionSectionTitle(
              title: 'For You',
              icon: LucideIcons.star,
              iconColor: FzColors.accent3,
            ),
            const SizedBox(height: 8),
            if (forYou.isEmpty)
              StateView.empty(
                title: 'No competitions pinned',
                subtitle: 'Favourite competitions will show up here.',
                icon: LucideIcons.star,
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: forYou.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.05,
                ),
                itemBuilder: (context, index) {
                  final competition = forYou[index];
                  return _CompetitionTile(
                    competition: competition,
                    compact: true,
                  );
                },
              ),
            const SizedBox(height: 24),
            const _CompetitionSectionTitle(
              title: 'Europe',
              icon: LucideIcons.globe2,
              iconColor: FzColors.accent,
            ),
            const SizedBox(height: 8),
            ...top5.map(
              (competition) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _CompetitionTile(competition: competition),
              ),
            ),
            if (otherCompetitions.isNotEmpty) ...[
              const SizedBox(height: 12),
              _OtherCompetitionsAccordion(competitions: otherCompetitions),
            ],
            const SizedBox(height: 24),
            const _CompetitionSectionTitle(
              title: 'Major Tournaments',
              icon: LucideIcons.trophy,
              iconColor: FzColors.accent2,
            ),
            const SizedBox(height: 8),
            if (majorCompetitions.isEmpty)
              Text(
                'Major tournaments will appear here when they are available.',
                style: TextStyle(fontSize: 12, color: muted),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: majorCompetitions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.35,
                ),
                itemBuilder: (context, index) {
                  final competition = majorCompetitions[index];
                  return _CompetitionTile(
                    competition: competition,
                    compact: true,
                    iconColor: FzColors.accent2,
                  );
                },
              ),
            if (top5.isEmpty && forYou.isEmpty && majorCompetitions.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Center(
                  child: Text(
                    'Competition catalogue unavailable',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: ScoresPageSkeleton(),
      ),
      error: (_, stackTrace) => StateView.error(
        title: 'Could not load competitions',
        subtitle: 'Pull to refresh and try again.',
      ),
    );
  }
}

class _CompetitionSectionTitle extends StatelessWidget {
  const _CompetitionSectionTitle({
    required this.title,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _CompetitionTile extends StatelessWidget {
  const _CompetitionTile({
    required this.competition,
    this.compact = false,
    this.iconColor,
  });

  final CompetitionModel competition;
  final bool compact;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return InkWell(
      onTap: () => context.push('/league/${competition.id}'),
      borderRadius: BorderRadius.circular(compact ? 14 : 16),
      child: Container(
        padding: EdgeInsets.all(compact ? 12 : 14),
        decoration: BoxDecoration(
          color: compact ? FzColors.darkSurface : FzColors.darkSurface2,
          borderRadius: BorderRadius.circular(compact ? 14 : 16),
          border: Border.all(color: FzColors.darkBorder),
        ),
        child: compact
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.trophy,
                    size: 16,
                    color: iconColor ?? FzColors.accent,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    competition.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: text,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Icon(
                    LucideIcons.trophy,
                    size: 16,
                    color: iconColor ?? FzColors.accent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      competition.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: text,
                      ),
                    ),
                  ),
                  Icon(LucideIcons.chevronRight, size: 14, color: muted),
                ],
              ),
      ),
    );
  }
}

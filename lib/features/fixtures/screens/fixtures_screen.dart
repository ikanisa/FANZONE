import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../models/match_model.dart';
import '../../../providers/competitions_provider.dart';
import '../../../providers/favourites_provider.dart';
import '../../../providers/matches_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_shimmer.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/match/match_list_widgets.dart';

enum _FixtureStateFilter { all, live, upcoming, finished }

class FixturesScreen extends ConsumerStatefulWidget {
  const FixturesScreen({super.key});

  @override
  ConsumerState<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends ConsumerState<FixturesScreen> {
  late final List<DateTime> _dates;
  late DateTime _selectedDate;
  _FixtureStateFilter _selectedState = _FixtureStateFilter.all;
  String? _selectedCompetitionId;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _dates = List.generate(
      9,
      (index) => DateTime(today.year, today.month, today.day + index - 2),
    );
    _selectedDate = DateTime(today.year, today.month, today.day);
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
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
    final chipSurface = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final chipBorder = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final matchesAsync = ref.watch(matchesByDateProvider(_selectedDate));
    final competitionsAsync = ref.watch(competitionsProvider);
    final favourites =
        ref.watch(favouritesProvider).valueOrNull ?? const FavouritesState();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: FzColors.accent,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'FIXTURES',
                          style: FzTypography.display(
                            size: 32,
                            color: isDark
                                ? FzColors.darkText
                                : FzColors.lightText,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => context.push('/search'),
                        icon: const Icon(Icons.search_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 56,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _dates.length,
                    itemBuilder: (context, index) {
                      final date = _dates[index];
                      final selected = _isSameDate(date, _selectedDate);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: InkWell(
                          onTap: () => setState(() => _selectedDate = date),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 72,
                            decoration: BoxDecoration(
                              color: selected ? FzColors.accent : chipSurface,
                              borderRadius: BorderRadius.circular(14),
                              border: selected
                                  ? null
                                  : Border.all(color: chipBorder),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _dateLabel(date),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: selected ? Colors.white : muted,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  DateFormat('dd MMM').format(date),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: selected
                                        ? Colors.white.withValues(alpha: 0.72)
                                        : muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _StateChip(
                        label: 'All',
                        selected: _selectedState == _FixtureStateFilter.all,
                        onTap: () => setState(
                          () => _selectedState = _FixtureStateFilter.all,
                        ),
                      ),
                      _StateChip(
                        label: 'Live',
                        selected: _selectedState == _FixtureStateFilter.live,
                        onTap: () => setState(
                          () => _selectedState = _FixtureStateFilter.live,
                        ),
                      ),
                      _StateChip(
                        label: 'Upcoming',
                        selected:
                            _selectedState == _FixtureStateFilter.upcoming,
                        onTap: () => setState(
                          () => _selectedState = _FixtureStateFilter.upcoming,
                        ),
                      ),
                      _StateChip(
                        label: 'Finished',
                        selected:
                            _selectedState == _FixtureStateFilter.finished,
                        onTap: () => setState(
                          () => _selectedState = _FixtureStateFilter.finished,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
                                  favourites.isCompetitionFavourite(left)
                                  ? 0
                                  : 1;
                              final rightFav =
                                  favourites.isCompetitionFavourite(right)
                                  ? 0
                                  : 1;
                              if (leftFav != rightFav) {
                                return leftFav.compareTo(rightFav);
                              }
                              return left.compareTo(right);
                            });

                      final competitions = {
                        for (final item in competitionsAsync.valueOrNull ?? [])
                          item.id: item,
                      };

                      return ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _StateChip(
                            label: 'All comps',
                            selected: _selectedCompetitionId == null,
                            onTap: () =>
                                setState(() => _selectedCompetitionId = null),
                          ),
                          ...competitionIds.map(
                            (competitionId) => _StateChip(
                              label:
                                  competitions[competitionId]?.shortName ??
                                  competitionId,
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
                          child: FzShimmer(
                            width: 72,
                            height: 34,
                            borderRadius: 18,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: FzShimmer(
                            width: 84,
                            height: 34,
                            borderRadius: 18,
                          ),
                        ),
                      ],
                    ),
                    error: (error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              matchesAsync.when(
                data: (matches) {
                  final competitions = {
                    for (final competition
                        in competitionsAsync.valueOrNull ?? [])
                      competition.id: competition,
                  };
                  final filtered = _filterMatches(matches);
                  if (filtered.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: StateView.empty(
                        title: 'No fixtures',
                        subtitle: 'Try another date or filter.',
                        icon: Icons.calendar_today_rounded,
                      ),
                    );
                  }

                  final grouped = _groupMatches(filtered, favourites);
                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final entry = grouped[index];
                      final competitionId = entry.key;
                      final label =
                          competitions[competitionId]?.shortName ??
                          competitions[competitionId]?.name ??
                          competitionId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          children: [
                            CompetitionSectionHeader(
                              title: label,
                              isFavourite: favourites.isCompetitionFavourite(
                                competitionId,
                              ),
                              onTap: () =>
                                  context.push('/league/$competitionId'),
                              onToggleFavourite: () => ref
                                  .read(favouritesProvider.notifier)
                                  .toggleCompetition(competitionId),
                            ),
                            MatchListCard(
                              matches: entry.value,
                              onTapMatch: (match) =>
                                  context.push('/match/${match.id}'),
                            ),
                          ],
                        ),
                      );
                    }, childCount: grouped.length),
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
        ),
      ),
    );
  }

  List<MapEntry<String, List<MatchModel>>> _groupMatches(
    List<MatchModel> matches,
    FavouritesState favourites,
  ) {
    final grouped = <String, List<MatchModel>>{};
    for (final match in matches) {
      grouped.putIfAbsent(match.competitionId, () => []).add(match);
    }
    final entries = grouped.entries.toList()
      ..sort((left, right) {
        final leftFav = favourites.isCompetitionFavourite(left.key) ? 0 : 1;
        final rightFav = favourites.isCompetitionFavourite(right.key) ? 0 : 1;
        if (leftFav != rightFav) {
          return leftFav.compareTo(rightFav);
        }
        return left.key.compareTo(right.key);
      });
    return entries;
  }

  List<MatchModel> _filterMatches(List<MatchModel> matches) {
    var filtered = matches.where((match) {
      final stateMatches = switch (_selectedState) {
        _FixtureStateFilter.live => match.isLive,
        _FixtureStateFilter.upcoming => match.isUpcoming,
        _FixtureStateFilter.finished => match.isFinished,
        _FixtureStateFilter.all => true,
      };
      final competitionMatches = _selectedCompetitionId == null
          ? true
          : match.competitionId == _selectedCompetitionId;
      return stateMatches && competitionMatches;
    }).toList();

    filtered.sort((left, right) {
      if (left.isLive != right.isLive) {
        return left.isLive ? -1 : 1;
      }
      return left.date.compareTo(right.date);
    });
    return filtered;
  }

  String _dateLabel(DateTime date) {
    final today = DateTime.now();
    if (_isSameDate(date, today)) return 'Today';
    if (_isSameDate(date, today.add(const Duration(days: 1)))) {
      return 'Tomorrow';
    }
    if (_isSameDate(date, today.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return DateFormat('EEE').format(date);
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

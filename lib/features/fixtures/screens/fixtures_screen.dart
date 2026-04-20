import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../home/screens/leagues_discovery_screen.dart';
import '../../../models/match_model.dart';
import '../../../providers/competitions_provider.dart';
import '../../../providers/favourites_provider.dart';
import '../../../providers/matches_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_shimmer.dart';
import '../../../widgets/common/state_view.dart';
import '../widgets/fixtures_widgets.dart';

enum _FixtureStateFilter { all, live, upcoming, finished }

class FixturesScreen extends ConsumerStatefulWidget {
  const FixturesScreen({super.key});

  @override
  ConsumerState<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends ConsumerState<FixturesScreen> {
  late final List<DateTime> _dates;
  late DateTime _selectedDate;
  FixturesPrimaryView _activeView = FixturesPrimaryView.competitions;
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
                        size: 32,
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
                    ? const KeyedSubtree(
                        key: ValueKey('fixtures-competitions'),
                        child: LeaguesDiscoveryContent(
                          showSearchAction: false,
                          topPadding: 12,
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
    required AsyncValue competitionsAsync,
    required FavouritesState favourites,
  }) {
    final chipSurface = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final chipBorder = isDark ? FzColors.darkBorder : FzColors.lightBorder;

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: FzColors.primary,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: chipSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: chipBorder),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _canMoveDateBackward ? () => _shiftSelectedDate(-1) : null,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 14, color: FzColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'This Week',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? FzColors.darkText : FzColors.lightText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _canMoveDateForward ? () => _shiftSelectedDate(1) : null,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ToolbarIconButton(tooltip: 'Search fixtures', icon: Icons.search_rounded, muted: muted, onTap: () => context.push('/search')),
                  const SizedBox(width: 6),
                  ToolbarIconButton(tooltip: 'Filter fixtures', icon: Icons.filter_alt_outlined, muted: muted, onTap: () => _showFilterSheet(context)),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 28,
              child: Center(
                child: Text(
                  _fixtureGroupLabel(_selectedDate),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: muted, letterSpacing: 1.1),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 42,
              child: matchesAsync.when(
                data: (matches) {
                  final competitionIds = matches
                      .map((match) => match.competitionId)
                      .toSet()
                      .toList()
                    ..sort((left, right) {
                      final leftFav = favourites.isCompetitionFavourite(left) ? 0 : 1;
                      final rightFav = favourites.isCompetitionFavourite(right) ? 0 : 1;
                      if (leftFav != rightFav) return leftFav.compareTo(rightFav);
                      return left.compareTo(right);
                    });

                  final competitions = {
                    for (final item in competitionsAsync.valueOrNull ?? []) item.id: item,
                  };

                  return ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      FixtureStateChip(label: 'All', selected: _selectedCompetitionId == null, onTap: () => setState(() => _selectedCompetitionId = null)),
                      ...competitionIds.map(
                        (competitionId) => FixtureStateChip(
                          label: competitions[competitionId]?.shortName ?? competitionId,
                          selected: _selectedCompetitionId == competitionId,
                          onTap: () => setState(() => _selectedCompetitionId = competitionId),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: const [
                    Padding(padding: EdgeInsets.only(right: 8), child: FzShimmer(width: 72, height: 34, borderRadius: 18)),
                    Padding(padding: EdgeInsets.only(right: 8), child: FzShimmer(width: 84, height: 34, borderRadius: 18)),
                  ],
                ),
                error: (error, stackTrace) => ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text('Leagues unavailable', style: TextStyle(fontSize: 12, color: isDark ? FzColors.darkMuted : FzColors.lightMuted)),
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
                  child: StateView.empty(title: 'No fixtures', subtitle: 'Try another date or league.', icon: Icons.calendar_today_rounded),
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
            loading: () => const SliverFillRemaining(child: ScoresPageSkeleton()),
            error: (error, stack) => SliverFillRemaining(
              hasScrollBody: false,
              child: StateView.fromError(error, onRetry: () => ref.invalidate(matchesByDateProvider(_selectedDate))),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }

  List<MatchModel> _filterMatches(List<MatchModel> matches) {
    final filtered = matches.where((match) {
      final stateMatches = switch (_selectedState) {
        _FixtureStateFilter.live => match.isLive,
        _FixtureStateFilter.upcoming => match.isUpcoming,
        _FixtureStateFilter.finished => match.isFinished,
        _FixtureStateFilter.all => true,
      };
      final competitionMatches = _selectedCompetitionId == null ? true : match.competitionId == _selectedCompetitionId;
      return stateMatches && competitionMatches;
    }).toList();

    filtered.sort((left, right) {
      if (left.isLive != right.isLive) return left.isLive ? -1 : 1;
      return left.date.compareTo(right.date);
    });
    return filtered;
  }

  bool get _canMoveDateBackward => _dates.indexWhere((date) => _isSameDate(date, _selectedDate)) > 0;

  bool get _canMoveDateForward {
    final currentIndex = _dates.indexWhere((date) => _isSameDate(date, _selectedDate));
    return currentIndex >= 0 && currentIndex < _dates.length - 1;
  }

  void _shiftSelectedDate(int delta) {
    final currentIndex = _dates.indexWhere((date) => _isSameDate(date, _selectedDate));
    if (currentIndex == -1) return;
    final nextIndex = (currentIndex + delta).clamp(0, _dates.length - 1);
    if (nextIndex == currentIndex) return;
    setState(() => _selectedDate = _dates[nextIndex]);
  }

  Future<void> _showFilterSheet(BuildContext context) async {
    final nextFilter = await showModalBottomSheet<_FixtureStateFilter>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final filter in _FixtureStateFilter.values)
              ListTile(
                title: Text(_stateFilterLabel(filter)),
                trailing: filter == _selectedState ? const Icon(Icons.check_rounded, color: FzColors.primary) : null,
                onTap: () => Navigator.of(context).pop(filter),
              ),
          ],
        ),
      ),
    );
    if (nextFilter == null || !mounted) return;
    setState(() => _selectedState = nextFilter);
  }

  String _stateFilterLabel(_FixtureStateFilter filter) {
    return switch (filter) {
      _FixtureStateFilter.all => 'All Fixtures',
      _FixtureStateFilter.live => 'Live',
      _FixtureStateFilter.upcoming => 'Upcoming',
      _FixtureStateFilter.finished => 'Finished',
    };
  }

  String _fixtureGroupLabel(DateTime date) {
    final today = DateTime.now();
    final prefix = switch (true) {
      _ when _isSameDate(date, today) => 'Today',
      _ when _isSameDate(date, today.add(const Duration(days: 1))) => 'Tomorrow',
      _ when _isSameDate(date, today.subtract(const Duration(days: 1))) => 'Yesterday',
      _ => DateFormat('EEE').format(date),
    };
    return '$prefix, ${DateFormat('MMM d').format(date)}';
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year && left.month == right.month && left.day == right.day;
  }
}

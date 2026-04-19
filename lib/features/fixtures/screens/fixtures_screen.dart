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
import '../../../widgets/match/match_list_widgets.dart';

enum _FixtureStateFilter { all, live, upcoming, finished }

enum _FixturesPrimaryView { competitions, matches }

class FixturesScreen extends ConsumerStatefulWidget {
  const FixturesScreen({super.key});

  @override
  ConsumerState<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends ConsumerState<FixturesScreen> {
  late final List<DateTime> _dates;
  late DateTime _selectedDate;
  _FixturesPrimaryView _activeView = _FixturesPrimaryView.competitions;
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
                  _PrimaryViewToggle(
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
                child: _activeView == _FixturesPrimaryView.competitions
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
      color: FzColors.accent,
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
                            onPressed: _canMoveDateBackward
                                ? () => _shiftSelectedDate(-1)
                                : null,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 14,
                                  color: FzColors.accent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'This Week',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? FzColors.darkText
                                        : FzColors.lightText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _canMoveDateForward
                                ? () => _shiftSelectedDate(1)
                                : null,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _ToolbarIconButton(
                    tooltip: 'Search fixtures',
                    icon: Icons.search_rounded,
                    muted: muted,
                    onTap: () => context.push('/search'),
                  ),
                  const SizedBox(width: 6),
                  _ToolbarIconButton(
                    tooltip: 'Filter fixtures',
                    icon: Icons.filter_alt_outlined,
                    muted: muted,
                    onTap: () => _showFilterSheet(context),
                  ),
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
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: muted,
                    letterSpacing: 1.1,
                  ),
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

                  final competitions = {
                    for (final item in competitionsAsync.valueOrNull ?? [])
                      item.id: item,
                  };

                  return ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _StateChip(
                        label: 'All',
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
                        color: Theme.of(context).brightness == Brightness.dark
                            ? FzColors.darkSurface2
                            : FzColors.lightSurface2,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        'Leagues unavailable',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
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
                    icon: Icons.calendar_today_rounded,
                  ),
                );
              }

              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _FixtureGroupCard(
                    matches: filtered,
                    onOpenMatch: (match) => context.push('/match/${match.id}'),
                    onOpenPools: () => context.go('/predict'),
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

  bool get _canMoveDateBackward {
    return _dates.indexWhere((date) => _isSameDate(date, _selectedDate)) > 0;
  }

  bool get _canMoveDateForward {
    final currentIndex = _dates.indexWhere(
      (date) => _isSameDate(date, _selectedDate),
    );
    return currentIndex >= 0 && currentIndex < _dates.length - 1;
  }

  void _shiftSelectedDate(int delta) {
    final currentIndex = _dates.indexWhere(
      (date) => _isSameDate(date, _selectedDate),
    );
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
                trailing: filter == _selectedState
                    ? const Icon(Icons.check_rounded, color: FzColors.accent)
                    : null,
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
      _ when _isSameDate(date, today.add(const Duration(days: 1))) =>
        'Tomorrow',
      _ when _isSameDate(date, today.subtract(const Duration(days: 1))) =>
        'Yesterday',
      _ => DateFormat('EEE').format(date),
    };
    return '$prefix, ${DateFormat('MMM d').format(date)}';
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

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.tooltip,
    required this.icon,
    required this.muted,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
            ),
          ),
          child: Icon(icon, size: 18, color: muted),
        ),
      ),
    );
  }
}

class _FixtureGroupCard extends StatelessWidget {
  const _FixtureGroupCard({
    required this.matches,
    required this.onOpenMatch,
    required this.onOpenPools,
  });

  final List<MatchModel> matches;
  final ValueChanged<MatchModel> onOpenMatch;
  final VoidCallback onOpenPools;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface : FzColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          for (var index = 0; index < matches.length; index++) ...[
            _FixtureListItem(
              match: matches[index],
              onOpenMatch: () => onOpenMatch(matches[index]),
              onOpenPools: onOpenPools,
            ),
            if (index < matches.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: border.withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
  }
}

class _FixtureListItem extends StatelessWidget {
  const _FixtureListItem({
    required this.match,
    required this.onOpenMatch,
    required this.onOpenPools,
  });

  final MatchModel match;
  final VoidCallback onOpenMatch;
  final VoidCallback onOpenPools;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              match.kickoffTime ?? '--:--',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: muted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onOpenMatch,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  children: [
                    _FixtureTeamRow(name: match.homeTeam, textColor: textColor),
                    const SizedBox(height: 10),
                    _FixtureTeamRow(name: match.awayTeam, textColor: textColor),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              _FixtureActionButton(
                tooltip: 'Open match',
                icon: Icons.gps_fixed_rounded,
                color: FzColors.coral,
                onTap: onOpenMatch,
              ),
              const SizedBox(width: 8),
              _FixtureActionButton(
                tooltip: 'Open pools',
                icon: Icons.sports_martial_arts_rounded,
                color: FzColors.accent,
                onTap: onOpenPools,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FixtureTeamRow extends StatelessWidget {
  const _FixtureTeamRow({required this.name, required this.textColor});

  final String name;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: isDark ? FzColors.darkBg : FzColors.lightBg,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
            ),
          ),
          child: Center(child: TeamAvatar(name: name, size: 14)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _FixtureActionButton extends StatelessWidget {
  const _FixtureActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _PrimaryViewToggle extends StatelessWidget {
  const _PrimaryViewToggle({
    required this.activeView,
    required this.onSelected,
  });

  final _FixturesPrimaryView activeView;
  final ValueChanged<_FixturesPrimaryView> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PrimaryViewButton(
            icon: Icons.explore_rounded,
            tooltip: 'Competitions',
            selected: activeView == _FixturesPrimaryView.competitions,
            activeColor: FzColors.coral,
            mutedColor: muted,
            onTap: () => onSelected(_FixturesPrimaryView.competitions),
          ),
          const SizedBox(width: 4),
          _PrimaryViewButton(
            icon: Icons.calendar_today_rounded,
            tooltip: 'Matches',
            selected: activeView == _FixturesPrimaryView.matches,
            activeColor: FzColors.accent,
            mutedColor: muted,
            onTap: () => onSelected(_FixturesPrimaryView.matches),
          ),
        ],
      ),
    );
  }
}

class _PrimaryViewButton extends StatelessWidget {
  const _PrimaryViewButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.activeColor,
    required this.mutedColor,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final Color activeColor;
  final Color mutedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      splashRadius: 18,
      style: IconButton.styleFrom(
        backgroundColor: selected ? activeColor : Colors.transparent,
        foregroundColor: selected ? Colors.white : mutedColor,
        shape: const CircleBorder(),
      ),
      icon: Icon(icon, size: 18),
    );
  }
}

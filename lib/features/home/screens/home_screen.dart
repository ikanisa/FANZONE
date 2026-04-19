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
import '../../../widgets/common/fz_animated_entry.dart';
import '../../../widgets/common/fz_shimmer.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/match/match_list_widgets.dart';

// ─── Status filter (secondary axis) ─────────────────────────────
enum _StatusFilter { all, live, results, following }

// ─── Date ribbon helpers ────────────────────────────────────────
List<DateTime> _buildDateRange() {
  final today = DateTime.now();
  return List.generate(15, (i) {
    return DateTime(today.year, today.month, today.day - 3 + i);
  });
}

String _dayLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = date.difference(today).inDays;
  if (diff == -1) return 'YTD';
  if (diff == 0) return 'TODAY';
  if (diff == 1) return 'TMR';
  return DateFormat('EEE').format(date).toUpperCase();
}

String _dayNumber(DateTime date) => DateFormat('d').format(date);

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// ─── Home screen ────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final List<DateTime> _dates;
  late final ScrollController _dateScrollController;
  late DateTime _selectedDate;
  _StatusFilter _statusFilter = _StatusFilter.all;

  @override
  void initState() {
    super.initState();
    _dates = _buildDateRange();
    _selectedDate = _dates.firstWhere(
      (d) => _isSameDay(d, DateTime.now()),
      orElse: () => _dates[3],
    );
    _dateScrollController = ScrollController();
    // Scroll to "today" after layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final idx = _dates.indexWhere((d) => _isSameDay(d, _selectedDate));
      if (idx >= 0 && _dateScrollController.hasClients) {
        _dateScrollController.animateTo(
          (idx * 58.0) - 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    ref.invalidate(competitionsProvider);
    ref.invalidate(matchesByDateProvider(_selectedDate));

    await Future.wait([
      ref.read(competitionsProvider.future),
      ref.read(matchesByDateProvider(_selectedDate).future),
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
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: FzColors.accent,
          child: CustomScrollView(
            slivers: [
              // ── Title ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MATCHES',
                              style: FzTypography.display(
                                size: 32,
                                color: isDark
                                    ? FzColors.darkText
                                    : FzColors.lightText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Live scores, fixtures, and following in one fast match hub.',
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Search matches',
                        onTap: () => context.push('/search'),
                        child: Tooltip(
                          message: 'Search matches',
                          child: ExcludeSemantics(
                            child: IconButton(
                              onPressed: () => context.push('/search'),
                              tooltip: 'Search matches',
                              icon: const Icon(Icons.search_rounded),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Date picker ribbon (P0-N1) ──
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 64,
                  child: ListView.builder(
                    controller: _dateScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _dates.length,
                    itemBuilder: (context, index) {
                      final date = _dates[index];
                      final isSelected = _isSameDay(date, _selectedDate);
                      final isToday = _isSameDay(date, DateTime.now());
                      return _DateChip(
                        dayLabel: _dayLabel(date),
                        dayNumber: _dayNumber(date),
                        isSelected: isSelected,
                        isToday: isToday,
                        isDark: isDark,
                        semanticLabel:
                            'Open matches for ${_dayLabel(date)} ${_dayNumber(date)}',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedDate = date);
                        },
                      );
                    },
                  ),
                ),
              ),

              // ── Status filter chips (Live · Results · Following) ──
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _FilterChip(
                        label: 'All',
                        tooltip: 'Filter all matches',
                        semanticLabel: 'Filter all matches',
                        selected: _statusFilter == _StatusFilter.all,
                        onTap: () =>
                            setState(() => _statusFilter = _StatusFilter.all),
                      ),
                      // P0-N2: LIVE count badge
                      _FilterChip(
                        label: _liveLabelWithCount(matchesAsync),
                        tooltip: 'Filter live matches',
                        semanticLabel: 'Filter live matches',
                        selected: _statusFilter == _StatusFilter.live,
                        onTap: () =>
                            setState(() => _statusFilter = _StatusFilter.live),
                        isLive: true,
                      ),
                      _FilterChip(
                        label: 'Results',
                        tooltip: 'Filter finished matches',
                        semanticLabel: 'Filter finished matches',
                        selected: _statusFilter == _StatusFilter.results,
                        onTap: () => setState(
                          () => _statusFilter = _StatusFilter.results,
                        ),
                      ),
                      _FilterChip(
                        label: 'Following',
                        tooltip: 'Filter followed matches',
                        semanticLabel: 'Filter followed matches',
                        selected: _statusFilter == _StatusFilter.following,
                        onTap: () => setState(
                          () => _statusFilter = _StatusFilter.following,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ── Match list ──
              matchesAsync.when(
                data: (matches) {
                  final competitions = {
                    for (final competition
                        in competitionsAsync.valueOrNull ?? [])
                      competition.id: competition,
                  };
                  final filtered = _applyFilter(matches, favourites);
                  if (filtered.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: StateView.empty(
                        title: _emptyTitle,
                        subtitle: _emptySubtitle,
                        icon: Icons.sports_soccer_rounded,
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

                      return FzAnimatedEntry(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            children: [
                              CompetitionSectionHeader(
                                title: label,
                                countryCode:
                                    competitions[competitionId]?.country,
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
            ],
          ),
        ),
      ),
    );
  }

  // ── LIVE label with count (P0-N2) ──
  String _liveLabelWithCount(AsyncValue<List<MatchModel>> matchesAsync) {
    final matches = matchesAsync.valueOrNull;
    if (matches == null) return 'Live';
    final count = matches.where((m) => m.isLive).length;
    return count > 0 ? 'Live · $count' : 'Live';
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
        final leftFavourite = favourites.isCompetitionFavourite(left.key)
            ? 0
            : 1;
        final rightFavourite = favourites.isCompetitionFavourite(right.key)
            ? 0
            : 1;
        if (leftFavourite != rightFavourite) {
          return leftFavourite.compareTo(rightFavourite);
        }
        final leftLive = left.value.any((match) => match.isLive) ? 0 : 1;
        final rightLive = right.value.any((match) => match.isLive) ? 0 : 1;
        if (leftLive != rightLive) {
          return leftLive.compareTo(rightLive);
        }
        return left.key.compareTo(right.key);
      });

    return entries;
  }

  List<MatchModel> _applyFilter(
    List<MatchModel> matches,
    FavouritesState favourites,
  ) {
    final filtered = matches.where((match) {
      switch (_statusFilter) {
        case _StatusFilter.all:
          return true;
        case _StatusFilter.live:
          return match.isLive;
        case _StatusFilter.results:
          return match.isFinished;
        case _StatusFilter.following:
          return favourites.isCompetitionFavourite(match.competitionId) ||
              (match.homeTeamId != null &&
                  favourites.isTeamFavourite(match.homeTeamId!)) ||
              (match.awayTeamId != null &&
                  favourites.isTeamFavourite(match.awayTeamId!));
      }
    }).toList();

    filtered.sort((left, right) {
      if (left.isLive != right.isLive) return left.isLive ? -1 : 1;
      return left.date.compareTo(right.date);
    });
    return filtered;
  }

  String get _emptyTitle {
    final dateLabel = _isSameDay(_selectedDate, DateTime.now())
        ? 'today'
        : DateFormat('MMM d').format(_selectedDate);
    switch (_statusFilter) {
      case _StatusFilter.all:
        return 'No matches on $dateLabel';
      case _StatusFilter.live:
        return 'No live matches';
      case _StatusFilter.results:
        return 'No results on $dateLabel';
      case _StatusFilter.following:
        return 'Nothing followed yet';
    }
  }

  String get _emptySubtitle {
    switch (_statusFilter) {
      case _StatusFilter.following:
        return 'Follow teams or competitions.';
      default:
        return 'Try selecting a different date.';
    }
  }
}

// ─── Date chip widget ────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.dayLabel,
    required this.dayNumber,
    required this.isSelected,
    required this.isToday,
    required this.isDark,
    required this.semanticLabel,
    required this.onTap,
  });

  final String dayLabel;
  final String dayNumber;
  final bool isSelected;
  final bool isToday;
  final bool isDark;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isSelected
        ? FzColors.accent
        : (isDark ? FzColors.darkSurface2 : FzColors.lightSurface2);
    final textColor = isSelected
        ? Colors.white
        : (isDark ? FzColors.darkMuted : FzColors.lightMuted);
    final labelColor = isSelected
        ? Colors.white70
        : (isToday ? FzColors.accent : textColor);

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: 50,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? FzColors.accent
                    : (isToday
                          ? FzColors.accent.withValues(alpha: 0.4)
                          : (isDark
                                ? FzColors.darkBorder
                                : FzColors.lightBorder)),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dayLabel,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dayNumber,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Filter chip widget ──────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.tooltip,
    required this.semanticLabel,
    this.isLive = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String tooltip;
  final String semanticLabel;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        label: semanticLabel,
        child: Tooltip(
          message: tooltip,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? FzColors.accent
                    : (isDark ? FzColors.darkSurface2 : FzColors.lightSurface2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? FzColors.accent
                      : (isDark ? FzColors.darkBorder : FzColors.lightBorder),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLive && !selected) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: FzColors.live,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : muted,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

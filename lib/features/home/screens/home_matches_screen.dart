import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../design_system/design_system.dart';
import '../../../models/sports/match_model.dart';
import '../../../providers/matches_provider.dart';
import '../../../providers/profile_country_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../../../widgets/common/state_view.dart';
import '../../ordering/providers/venue_context_provider.dart';

class HomeMatchesScreen extends ConsumerStatefulWidget {
  const HomeMatchesScreen({super.key, this.anchorDay});

  final DateTime? anchorDay;

  @override
  ConsumerState<HomeMatchesScreen> createState() => _HomeMatchesScreenState();
}

class _HomeMatchesScreenState extends ConsumerState<HomeMatchesScreen> {
  static const _matchWindowDays = 14;

  var _filter = _HomeMatchFilter.all;

  DateTime get _anchorDay {
    final now = widget.anchorDay ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  MatchesFilter get _matchesFilter {
    final venueContext = ref.watch(venueContextProvider);
    final selectedCountryCode =
        venueContext.venue?.countryCode.name.toUpperCase() ??
        ref.watch(profileCountryProvider);
    return MatchesFilter(
      dateFrom: _anchorDay.toIso8601String(),
      dateTo: _anchorDay
          .add(const Duration(days: _matchWindowDays))
          .toIso8601String(),
      countryCode: selectedCountryCode,
      venueId: venueContext.venueId,
      ascending: true,
      limit: 120,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = _matchesFilter;
    final matchesAsync = ref.watch(matchesProvider(filter));

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(matchesProvider(filter));
            await ref.read(matchesProvider(filter).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
            children: [
              FzBackHeader(
                title: 'Matches',
                subtitle: 'Live and upcoming fixtures',
                onClose: () => context.go('/home'),
              ),
              const SizedBox(height: 20),
              _MatchSummaryHeader(matchesAsync: matchesAsync),
              const SizedBox(height: 18),
              _FilterBar(
                selected: _filter,
                onSelected: (value) => setState(() => _filter = value),
              ),
              const SizedBox(height: 18),
              matchesAsync.when(
                data: (matches) => _MatchList(
                  matches: _visibleMatches(matches),
                  filter: _filter,
                ),
                loading: () => const _MatchesLoading(),
                error: (error, _) => StateView.error(
                  title: 'Could not load matches',
                  subtitle: 'Pull to retry.',
                  onRetry: () => ref.invalidate(matchesProvider(filter)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<MatchModel> _visibleMatches(List<MatchModel> matches) {
    return switch (_filter) {
      _HomeMatchFilter.live => matches.where((match) => match.isLive).toList(),
      _HomeMatchFilter.upcoming =>
        matches.where((match) => match.isUpcoming).toList(),
      _HomeMatchFilter.all =>
        matches.where((match) => match.isLive || match.isUpcoming).toList(),
    };
  }
}

enum _HomeMatchFilter { all, live, upcoming }

class _MatchSummaryHeader extends StatelessWidget {
  const _MatchSummaryHeader({required this.matchesAsync});

  final AsyncValue<List<MatchModel>> matchesAsync;

  @override
  Widget build(BuildContext context) {
    final matches = matchesAsync.valueOrNull ?? const <MatchModel>[];
    final liveCount = matches.where((match) => match.isLive).length;
    final upcomingCount = matches.where((match) => match.isUpcoming).length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: FzRadii.heroRadius,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MATCH CENTER',
                  style: FzTypography.chipLabel(
                    size: 12,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$liveCount live',
                  style: FzTypography.display(size: 28, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  '$upcomingCount upcoming',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: FzRadii.buttonRadius,
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Icon(
              LucideIcons.calendarClock,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelected});

  final _HomeMatchFilter selected;
  final ValueChanged<_HomeMatchFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterPill(
            label: 'All',
            selected: selected == _HomeMatchFilter.all,
            onTap: () => onSelected(_HomeMatchFilter.all),
          ),
          _FilterPill(
            label: 'Live',
            selected: selected == _HomeMatchFilter.live,
            onTap: () => onSelected(_HomeMatchFilter.live),
          ),
          _FilterPill(
            label: 'Upcoming',
            selected: selected == _HomeMatchFilter.upcoming,
            onTap: () => onSelected(_HomeMatchFilter.upcoming),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
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
      child: FzPill(label: label, selected: selected, onTap: onTap),
    );
  }
}

class _MatchList extends StatelessWidget {
  const _MatchList({required this.matches, required this.filter});

  final List<MatchModel> matches;
  final _HomeMatchFilter filter;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      final title = switch (filter) {
        _HomeMatchFilter.live => 'No live matches',
        _HomeMatchFilter.upcoming => 'No upcoming matches',
        _HomeMatchFilter.all => 'No matches available',
      };
      return _MatchesEmpty(title: title);
    }

    return Column(
      children: [
        for (final match in matches)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppMatchCard(
              homeTeam: match.homeTeam,
              awayTeam: match.awayTeam,
              homeLogoUrl: match.homeLogoUrl,
              awayLogoUrl: match.awayLogoUrl,
              competitionName: match.competitionName,
              kickoffLabel: match.kickoffLabel,
              homeScore: match.ftHome,
              awayScore: match.ftAway,
              isLive: match.isLive,
              liveMinute: match.isLive ? match.kickoffLabel : null,
              sourceLabel: match.sourceLabel,
              onTap: () => context.push('/match/${match.id}'),
            ),
          ),
      ],
    );
  }
}

class _MatchesLoading extends StatelessWidget {
  const _MatchesLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 64),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _MatchesEmpty extends StatelessWidget {
  const _MatchesEmpty({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FzColors.darkSurface,
        borderRadius: FzRadii.cardRadius,
        border: Border.all(color: FzColors.darkBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: FzColors.darkSurface2,
              borderRadius: FzRadii.buttonRadius,
            ),
            child: const Icon(
              LucideIcons.calendarOff,
              color: FzColors.cyan,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

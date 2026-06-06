import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/team_search_database.dart';
import '../../../models/hospitality/venue_model.dart';

import '../../../design_system/design_system.dart';
import '../../../providers/home_feed_provider.dart';
import '../../../providers/matches_provider.dart';
import '../../../providers/profile_country_provider.dart';
import '../../../services/wallet_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../../../widgets/common/team_crest.dart';
import '../data/home_match_curator.dart';
import '../../ordering/providers/venue_context_provider.dart';
import '../../ordering/providers/venue_discovery_provider.dart';
import '../../pools/data/pools_repository.dart';

class HomeFeedScreen extends ConsumerWidget {
  const HomeFeedScreen({super.key});

  static const _feedWindowDays = 7;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueContext = ref.watch(venueContextProvider);
    final profileCountryCode = ref.watch(profileCountryProvider);
    final selectedCountryCode =
        venueContext.venue?.countryCode.name.toUpperCase() ??
        profileCountryCode;
    final filter = MatchesFilter(
      dateFrom: _today.toIso8601String(),
      dateTo: _today
          .add(const Duration(days: _feedWindowDays))
          .toIso8601String(),
      countryCode: selectedCountryCode,
      venueId: venueContext.venueId,
      ascending: true,
      limit: 24,
    );
    final walletAsync = ref.watch(walletBalanceProvider);
    final teamsAsync = ref.watch(homeDefaultTeamsProvider);
    final matchesAsync = ref.watch(homeFeedMatchesProvider(filter));
    final venuesAsync = ref.watch(activeVenuesProvider);
    final poolsAsync = ref.watch(poolsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(walletBalanceProvider);
            ref.invalidate(homeDefaultTeamsProvider);
            ref.invalidate(homeFeedMatchesProvider(filter));
            ref.invalidate(activeVenuesProvider);
            ref.invalidate(poolsProvider);
            await Future.wait([
              ref.read(walletBalanceProvider.future),
              ref.read(homeDefaultTeamsProvider.future),
              ref.read(homeFeedMatchesProvider(filter).future),
              ref.read(activeVenuesProvider.future),
              ref.read(poolsProvider.future),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
            children: [
              const FzReferenceHeader(),
              const SizedBox(height: 20),
              _HomeCommandPanel(
                availableFet: walletAsync.valueOrNull?.availableFet ?? 0,
                pendingFet: walletAsync.valueOrNull?.pendingFet ?? 0,
                liveMatchCount:
                    matchesAsync.valueOrNull?.liveMatches.length ?? 0,
                upcomingMatchCount:
                    matchesAsync.valueOrNull?.upcomingMatches.length ?? 0,
                venueLabel: venueContext.venue?.name,
                onBrowseVenues: () => context.go('/venues'),
                onPlay: () => context.go('/pools'),
                onRewards: () => context.push('/wallet'),
              ),
              ..._barsSection(context: context, venuesAsync: venuesAsync),
              ..._teamsSection(context: context, teamsAsync: teamsAsync),
              ..._selectedVenueSection(
                context: context,
                venue: venueContext.venue,
              ),
              ..._poolSection(context: context, poolsAsync: poolsAsync),
              ..._matchesSection(context: context, matchesAsync: matchesAsync),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _barsSection({
    required BuildContext context,
    required AsyncValue<List<VenueModel>> venuesAsync,
  }) {
    return venuesAsync.when(
      data: (venues) {
        final visible = venues.take(3).toList(growable: false);
        return [
          const SizedBox(height: 28),
          AppSectionHeader(
            title: 'Bars',
            actionLabel: 'View all',
            actionKey: const ValueKey('home_bars_view_all'),
            onAction: () => context.go('/venues'),
          ),
          const SizedBox(height: 10),
          if (visible.isEmpty)
            _HomeEmptyPanel(
              icon: LucideIcons.store,
              title: 'No bars loaded',
              body: 'Open the bars page to search venues.',
              actionLabel: 'View all',
              onAction: () => context.go('/venues'),
            )
          else
            for (final venue in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppVenueCard(
                  name: venue.name,
                  city: venue.discoverySubtitle,
                  coverUrl: venue.coverUrl,
                  isLive: venue.isOpen,
                  onTap: () => context.push('/venue/${venue.id}'),
                ),
              ),
        ];
      },
      loading: () => const [
        SizedBox(height: 28),
        AppSectionHeader(title: 'Bars'),
        SizedBox(height: 10),
        _HomeLoadingPanel(label: 'Loading bars'),
      ],
      error: (_, _) => [
        const SizedBox(height: 28),
        AppSectionHeader(
          title: 'Bars',
          actionLabel: 'View all',
          onAction: () => context.go('/venues'),
        ),
        const SizedBox(height: 10),
        _HomeEmptyPanel(
          icon: LucideIcons.store,
          title: 'Bars unavailable',
          body: 'Open the bars page to retry.',
          actionLabel: 'View all',
          onAction: () => context.go('/venues'),
        ),
      ],
    );
  }

  List<Widget> _teamsSection({
    required BuildContext context,
    required AsyncValue<List<OnboardingTeam>> teamsAsync,
  }) {
    return teamsAsync.when(
      data: (teams) {
        if (teams.isEmpty) return const <Widget>[];
        return [
          const SizedBox(height: 24),
          AppSectionHeader(
            title: 'My Teams',
            actionLabel: 'Edit',
            onAction: () => context.push('/profile'),
          ),
          const SizedBox(height: 10),
          _TeamsStrip(teams: teams),
        ];
      },
      loading: () => const <Widget>[],
      error: (_, _) => const <Widget>[],
    );
  }

  List<Widget> _selectedVenueSection({
    required BuildContext context,
    required VenueModel? venue,
  }) {
    if (venue == null) return const <Widget>[];
    return [
      const SizedBox(height: 28),
      AppSectionHeader(
        title: 'Current Venue',
        actionLabel: 'Bars',
        onAction: () => context.go('/venues'),
      ),
      const SizedBox(height: 10),
      _LiveVenueCard(venue: venue),
    ];
  }

  List<Widget> _poolSection({
    required BuildContext context,
    required AsyncValue<List<PoolSummary>> poolsAsync,
  }) {
    return poolsAsync.when(
      data: (pools) {
        PoolSummary? openPool;
        for (final pool in pools) {
          if (pool.status == 'open') {
            openPool = pool;
            break;
          }
        }
        if (openPool == null) return const <Widget>[];
        return [
          const SizedBox(height: 28),
          AppSectionHeader(
            title: 'Open Pool',
            actionLabel: 'View all',
            actionKey: const ValueKey('home_pools_view_all'),
            onAction: () => context.go('/pools'),
          ),
          const SizedBox(height: 10),
          _EligiblePoolCard(pool: openPool),
        ];
      },
      loading: () => const <Widget>[],
      error: (_, _) => const <Widget>[],
    );
  }

  List<Widget> _matchesSection({
    required BuildContext context,
    required AsyncValue<HomeFeedSelection> matchesAsync,
  }) {
    return matchesAsync.when(
      data: (selection) {
        final matches = [
          ...selection.liveMatches,
          ...selection.upcomingMatches,
        ].take(4).toList(growable: false);
        if (matches.isEmpty) return const <Widget>[];
        return [
          const SizedBox(height: 28),
          AppSectionHeader(
            title: 'Live & Upcoming Matches',
            actionLabel: 'View all',
            actionKey: const ValueKey('home_matches_view_all'),
            onAction: () => context.go('/home/matches'),
          ),
          const SizedBox(height: 10),
          for (final match in matches)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppMatchCard(
                key: ValueKey('home_match_${match.id}'),
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
        ];
      },
      loading: () => const [
        SizedBox(height: 28),
        AppSectionHeader(title: 'Live & Upcoming Matches'),
        SizedBox(height: 10),
        _HomeLoadingPanel(label: 'Loading matches'),
      ],
      error: (_, _) => [
        const SizedBox(height: 28),
        AppSectionHeader(
          title: 'Live & Upcoming Matches',
          actionLabel: 'View all',
          actionKey: const ValueKey('home_matches_view_all_error'),
          onAction: () => context.go('/home/matches'),
        ),
        const SizedBox(height: 10),
        _HomeEmptyPanel(
          icon: LucideIcons.calendar,
          title: 'Matches unavailable',
          body: 'Open the matches page to retry.',
          actionLabel: 'View all',
          onAction: () => context.go('/home/matches'),
        ),
      ],
    );
  }
}

class _HomeCommandPanel extends StatelessWidget {
  const _HomeCommandPanel({
    required this.availableFet,
    required this.pendingFet,
    required this.liveMatchCount,
    required this.upcomingMatchCount,
    required this.venueLabel,
    required this.onBrowseVenues,
    required this.onPlay,
    required this.onRewards,
  });

  final int availableFet;
  final int pendingFet;
  final int liveMatchCount;
  final int upcomingMatchCount;
  final String? venueLabel;
  final VoidCallback onBrowseVenues;
  final VoidCallback onPlay;
  final VoidCallback onRewards;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: FzRadii.heroRadius,
        boxShadow: [
          BoxShadow(
            color: FzColors.cyan.withValues(alpha: 0.2),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MATCH DAY',
                      style: FzTypography.chipLabel(
                        size: 12,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      venueLabel == null ? 'Your FANZONE' : venueLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FzTypography.display(
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatNumber(availableFet),
                    style: FzTypography.heroFet(size: 42, color: Colors.white),
                  ),
                  const Text(
                    'FET READY',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroPill(icon: LucideIcons.radio, label: '$liveMatchCount live'),
              _HeroPill(
                icon: LucideIcons.calendarClock,
                label: '$upcomingMatchCount upcoming',
              ),
              if (pendingFet > 0)
                _HeroPill(
                  icon: LucideIcons.timer,
                  label: '$pendingFet pending',
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HomeCommandAction(
                  icon: AppIconName.bars,
                  label: 'Bars',
                  color: FzColors.cyan,
                  onTap: onBrowseVenues,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HomeCommandAction(
                  icon: AppIconName.play,
                  label: 'Play',
                  color: FzColors.orange,
                  onTap: onPlay,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HomeCommandAction(
                  icon: AppIconName.wallet,
                  label: 'Rewards',
                  color: FzColors.danger,
                  onTap: onRewards,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeCommandAction extends StatelessWidget {
  const _HomeCommandAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final AppIconName icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const foregroundColor = FzColors.darkBg;
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 58,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppSvgIcon(icon, color: foregroundColor, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: foregroundColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: FzRadii.fullRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeLoadingPanel extends StatelessWidget {
  const _HomeLoadingPanel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: FzColors.darkSurface,
        borderRadius: FzRadii.cardRadius,
        border: Border.all(color: FzColors.darkBorder),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: FzColors.darkMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeEmptyPanel extends StatelessWidget {
  const _HomeEmptyPanel({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FzColors.darkSurface,
        borderRadius: FzRadii.cardRadius,
        border: Border.all(color: FzColors.darkBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: FzColors.darkSurface2,
              borderRadius: FzRadii.buttonRadius,
            ),
            child: Icon(icon, color: FzColors.cyan, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: FzColors.darkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _TeamsStrip extends StatelessWidget {
  const _TeamsStrip({required this.teams});

  final List<OnboardingTeam> teams;

  @override
  Widget build(BuildContext context) {
    final visible = teams.take(8).toList(growable: false);
    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: visible.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final team = visible[index];
          return SizedBox(
            width: 72,
            child: Column(
              children: [
                TeamCrest(
                  label: team.name,
                  crestUrl: team.crestUrl,
                  size: 52,
                  backgroundColor: FzColors.darkSurface2,
                  borderColor: FzColors.darkBorder,
                ),
                const SizedBox(height: 6),
                Text(
                  team.shortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LiveVenueCard extends StatelessWidget {
  const _LiveVenueCard({required this.venue});

  final VenueModel venue;

  @override
  Widget build(BuildContext context) {
    return AppVenueCard(
      name: venue.name,
      city: venue.discoverySubtitle,
      coverUrl: venue.coverUrl,
      isLive: true,
      onTap: () => context.push('/venue/${venue.id}'),
    );
  }
}

class _EligiblePoolCard extends StatelessWidget {
  const _EligiblePoolCard({required this.pool});

  final PoolSummary pool;

  @override
  Widget build(BuildContext context) {
    return AppPoolCard(
      title: pool.title,
      status: pool.status,
      totalStakedFet: pool.totalStakedFet,
      totalMembers: pool.totalMembers,
      defaultStakeFet: pool.defaultStakeFet,
      onTap: () => context.push('/pool/${pool.id}'),
      onJoin: () => context.push('/pool/${pool.id}/join'),
    );
  }
}

String _formatNumber(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final fromEnd = text.length - i;
    buffer.write(text[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

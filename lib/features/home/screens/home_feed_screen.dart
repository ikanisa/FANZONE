import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

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
    final poolsAsync = ref.watch(poolsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(walletBalanceProvider);
            ref.invalidate(homeDefaultTeamsProvider);
            ref.invalidate(homeFeedMatchesProvider(filter));
            ref.invalidate(poolsProvider);
            await Future.wait([
              ref.read(walletBalanceProvider.future),
              ref.read(homeDefaultTeamsProvider.future),
              ref.read(homeFeedMatchesProvider(filter).future),
              ref.read(poolsProvider.future),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
            children: [
              const FzReferenceHeader(),
              const SizedBox(height: 20),
              walletAsync.when(
                data: (wallet) => _BalanceHero(
                  available: wallet.availableFet,
                  pending: wallet.pendingFet,
                ),
                loading: () => const _BalanceHero(available: 0, pending: 0),
                error: (_, _) => const _BalanceHero(available: 0, pending: 0),
              ),
              const SizedBox(height: 18),
              _ActionRail(
                onBrowseVenues: () => context.go('/venues'),
                onJoinPool: () => context.go('/pools'),
                onJoinGame: () => context.go('/games'),
              ),
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
            actionLabel: 'Pools',
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
          const AppSectionHeader(title: 'Matches'),
          const SizedBox(height: 10),
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
                onTap: () => context.push('/match/${match.id}'),
              ),
            ),
        ];
      },
      loading: () => const <Widget>[],
      error: (_, _) => const <Widget>[],
    );
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.available, required this.pending});

  final int available;
  final int pending;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: FzRadii.heroRadius,
        boxShadow: [
          BoxShadow(
            color: FzColors.cyan.withValues(alpha: 0.22),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -34,
            child: Icon(
              LucideIcons.zap,
              size: 170,
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FET',
                style: FzTypography.chipLabel(size: 13, color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text(
                _formatNumber(available),
                style: FzTypography.heroFet(size: 48, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (pending > 0)
                    _HeroPill(
                      icon: LucideIcons.timer,
                      label: '$pending pending',
                    ),
                ],
              ),
            ],
          ),
        ],
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

class _ActionRail extends StatelessWidget {
  const _ActionRail({
    required this.onBrowseVenues,
    required this.onJoinPool,
    required this.onJoinGame,
  });

  final VoidCallback onBrowseVenues;
  final VoidCallback onJoinPool;
  final VoidCallback onJoinGame;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ActionRailItem(
          icon: AppIconName.bars,
          label: 'Bars',
          color: FzColors.cyan,
          onTap: onBrowseVenues,
        ),
        _ActionRailItem(
          icon: AppIconName.pool,
          label: 'Pools',
          color: FzColors.orange,
          onTap: onJoinPool,
        ),
        _ActionRailItem(
          icon: AppIconName.game,
          label: 'Games',
          color: FzColors.danger,
          onTap: onJoinGame,
        ),
      ],
    );
  }
}

class _ActionRailItem extends StatelessWidget {
  const _ActionRailItem({
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
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: FzColors.darkSurface2,
              border: Border.all(color: FzColors.darkBorder),
            ),
            child: Center(child: AppSvgIcon(icon, color: color, size: 24)),
          ),
        ),
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
      city: venue.city ?? venue.countryCode.label,
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

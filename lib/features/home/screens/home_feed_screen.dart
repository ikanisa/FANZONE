import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../data/team_search_database.dart';
import '../../../models/hospitality/venue_model.dart';
import '../../../models/sports/match_model.dart';
import '../../../providers/home_feed_provider.dart';
import '../../../providers/matches_provider.dart';
import '../../../services/wallet_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_empty_state.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../../../widgets/common/team_crest.dart';
import '../../../widgets/common/state_view.dart';
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
    final filter = MatchesFilter(
      dateFrom: _today.toIso8601String(),
      dateTo: _today
          .add(const Duration(days: _feedWindowDays))
          .toIso8601String(),
      countryCode: venueContext.venue?.countryCode.name.toUpperCase(),
      venueId: venueContext.venueId,
      ascending: true,
      limit: 24,
    );
    final walletAsync = ref.watch(walletBalanceProvider);
    final teamsAsync = ref.watch(homeDefaultTeamsProvider);
    final matchesAsync = ref.watch(homeFeedMatchesProvider(filter));
    final poolsAsync = ref.watch(poolsProvider);
    final venuesAsync = ref.watch(activeVenuesProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(walletBalanceProvider);
            ref.invalidate(homeDefaultTeamsProvider);
            ref.invalidate(homeFeedMatchesProvider(filter));
            ref.invalidate(poolsProvider);
            ref.invalidate(activeVenuesProvider);
            await Future.wait([
              ref.read(walletBalanceProvider.future),
              ref.read(homeFeedMatchesProvider(filter).future),
              ref.read(poolsProvider.future),
              ref.read(activeVenuesProvider.future),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
            children: [
              const FzReferenceHeader(title: 'Sports Elite'),
              const SizedBox(height: 20),
              walletAsync.when(
                data: (wallet) => _BalanceHero(
                  available: wallet.availableFet,
                  pending: wallet.pendingFet,
                ),
                loading: () => const _BalanceHero(available: 0, pending: 0),
                error: (_, _) => const _BalanceHero(available: 0, pending: 0),
              ),
              const SizedBox(height: 16),
              _ActionGrid(
                onBrowseVenues: () => context.go('/venues'),
                onJoinPool: () => context.go('/pools'),
                onJoinGame: () => context.go('/pools'),
                onCreate: () => context.push('/pools/create'),
              ),
              const SizedBox(height: 24),
              FzSectionHeader(
                title: 'My Teams',
                actionLabel: 'Edit',
                onAction: () => context.push('/profile'),
              ),
              const SizedBox(height: 10),
              teamsAsync.when(
                data: (teams) => _TeamsStrip(teams: teams),
                loading: () => const _TeamsLoadingStrip(),
                error: (_, _) => const _TeamsStrip(teams: []),
              ),
              const SizedBox(height: 24),
              FzSectionHeader(
                title: 'Live Now',
                actionLabel: 'Venues',
                onAction: () => context.go('/venues'),
              ),
              const SizedBox(height: 10),
              venuesAsync.when(
                data: (venues) =>
                    _LiveVenueCard(venue: venues.isEmpty ? null : venues.first),
                loading: () => const _LiveVenueCard(venue: null),
                error: (_, _) => const _LiveVenueCard(venue: null),
              ),
              const SizedBox(height: 18),
              poolsAsync.when(
                data: (pools) {
                  PoolSummary? openPool;
                  for (final pool in pools) {
                    if (pool.status == 'open') {
                      openPool = pool;
                      break;
                    }
                  }
                  return _EligiblePoolCard(pool: openPool);
                },
                loading: () => const _EligiblePoolCard(pool: null),
                error: (_, _) => const _EligiblePoolCard(pool: null),
              ),
              const SizedBox(height: 24),
              const FzSectionHeader(title: 'Featured Matches'),
              const SizedBox(height: 10),
              matchesAsync.when(
                data: (selection) {
                  final matches = [
                    ...selection.liveMatches,
                    ...selection.upcomingMatches,
                  ].take(4).toList(growable: false);
                  if (matches.isEmpty) {
                    return FzEmptyState(
                      title: 'No matches yet',
                      description:
                          'Featured match cards appear as soon as curated fixtures are available.',
                      icon: const Icon(LucideIcons.calendar),
                      actionLabel: 'Open Arena',
                      onAction: () => context.go('/pools'),
                    );
                  }
                  return Column(
                    children: [
                      for (final match in matches)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DashboardMatchCard(match: match),
                        ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 34),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => StateView.error(
                  title: 'Could not load matches',
                  subtitle: error.toString(),
                  onRetry: () =>
                      ref.invalidate(homeFeedMatchesProvider(filter)),
                ),
              ),
            ],
          ),
        ),
      ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FzColors.accent, Color(0xFF1734B8)],
        ),
        borderRadius: FzRadii.heroRadius,
        boxShadow: [
          BoxShadow(
            color: FzColors.accent.withValues(alpha: 0.28),
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
              LucideIcons.coins,
              size: 170,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AVAILABLE FET',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatNumber(available),
                style: FzTypography.score(
                  size: 48,
                  color: Colors.white,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroPill(icon: LucideIcons.timer, label: '$pending pending'),
                  const _HeroPill(
                    icon: LucideIcons.zap,
                    label: 'Ready to play',
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
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: FzRadii.fullRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
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

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.onBrowseVenues,
    required this.onJoinPool,
    required this.onJoinGame,
    required this.onCreate,
  });

  final VoidCallback onBrowseVenues;
  final VoidCallback onJoinPool;
  final VoidCallback onJoinGame;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.62,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _ActionTile(
          icon: LucideIcons.mapPin,
          label: 'Browse Venues',
          onTap: onBrowseVenues,
        ),
        _ActionTile(
          icon: LucideIcons.trophy,
          label: 'Join Pool',
          color: FzColors.success,
          onTap: onJoinPool,
        ),
        _ActionTile(
          icon: LucideIcons.gamepad2,
          label: 'Join Game',
          color: FzColors.accent3,
          onTap: onJoinGame,
        ),
        _ActionTile(icon: LucideIcons.plus, label: 'Create', onTap: onCreate),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = FzColors.accent,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      borderRadius: FzRadii.compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
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
    if (visible.isEmpty) {
      return const FzCard(
        padding: EdgeInsets.all(16),
        borderRadius: FzRadii.card,
        child: Text(
          'Pick favorite teams from Profile to personalize matches and pools.',
          style: TextStyle(
            color: FzColors.darkMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return SizedBox(
      height: 78,
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
                  size: 48,
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
                    fontSize: 11,
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

class _TeamsLoadingStrip extends StatelessWidget {
  const _TeamsLoadingStrip();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 78,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _LiveVenueCard extends StatelessWidget {
  const _LiveVenueCard({required this.venue});

  final VenueModel? venue;

  @override
  Widget build(BuildContext context) {
    if (venue == null) {
      return FzCard(
        onTap: () => context.go('/venues'),
        padding: const EdgeInsets.all(18),
        borderRadius: FzRadii.card,
        child: const Row(
          children: [
            Icon(LucideIcons.mapPin, color: FzColors.accent),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Browse venues to find live rooms and menus.',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
    }

    return FzCard(
      onTap: () => context.push('/venue/${venue!.id}'),
      padding: EdgeInsets.zero,
      borderRadius: FzRadii.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              FzImageSurface(
                imageUrl: venue!.coverUrl,
                icon: LucideIcons.utensils,
                height: 150,
              ),
              const Positioned(
                left: 12,
                top: 12,
                child: FzPill(
                  label: 'Live Now',
                  icon: LucideIcons.zap,
                  color: FzColors.success,
                  selected: true,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venue!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        venue!.city ?? venue!.countryCode.label,
                        style: const TextStyle(
                          color: FzColors.darkMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevronRight, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EligiblePoolCard extends StatelessWidget {
  const _EligiblePoolCard({required this.pool});

  final PoolSummary? pool;

  @override
  Widget build(BuildContext context) {
    if (pool == null) {
      return FzCard(
        onTap: () => context.go('/pools'),
        padding: const EdgeInsets.all(18),
        borderRadius: FzRadii.card,
        child: const Row(
          children: [
            Icon(LucideIcons.trophy, color: FzColors.success),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'The Arena is quiet. Open pools appear here when live.',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
    }

    return FzCard(
      onTap: () => context.push('/pool/${pool!.id}'),
      padding: const EdgeInsets.all(18),
      borderRadius: FzRadii.card,
      color: FzColors.success.withValues(alpha: 0.10),
      borderColor: FzColors.success.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FzPill(
            label: 'Eligible Pool',
            icon: LucideIcons.zap,
            color: FzColors.success,
            selected: true,
          ),
          const SizedBox(height: 14),
          Text(
            pool!.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: FzTypography.display(size: 25, color: FzColors.darkText),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FzMetricTile(
                  label: 'Pool',
                  value: '${pool!.totalStakedFet} FET',
                  color: FzColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FzMetricTile(
                  label: 'Entries',
                  value: '${pool!.totalMembers}',
                  color: FzColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardMatchCard extends StatelessWidget {
  const _DashboardMatchCard({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      onTap: () => context.push('/match/${match.id}'),
      padding: const EdgeInsets.all(16),
      borderRadius: FzRadii.card,
      child: Row(
        children: [
          TeamCrest(
            label: match.homeTeam,
            crestUrl: match.homeLogoUrl,
            size: 42,
            backgroundColor: FzColors.darkSurface2,
            borderColor: FzColors.darkBorder,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  match.competitionName ?? 'Featured Match',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FzColors.darkMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${match.homeTeam} vs ${match.awayTeam}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  match.kickoffLabel,
                  style: TextStyle(
                    color: match.isLive ? FzColors.danger : FzColors.accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TeamCrest(
            label: match.awayTeam,
            crestUrl: match.awayLogoUrl,
            size: 42,
            backgroundColor: FzColors.darkSurface2,
            borderColor: FzColors.darkBorder,
          ),
        ],
      ),
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

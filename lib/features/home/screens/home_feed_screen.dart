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
              const FzReferenceHeader(title: 'FZ'),
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
              _ActionGrid(
                onBrowseVenues: () => context.go('/venues'),
                onJoinPool: () => context.go('/pools'),
                onJoinGame: () => context.go('/pools'),
                onCreate: () => context.push('/pools/create'),
              ),
              const SizedBox(height: 28),
              AppSectionHeader(
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
              const SizedBox(height: 28),
              AppSectionHeader(
                title: 'Live Now',
                actionLabel: 'Bars',
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
              const SizedBox(height: 28),
              const AppSectionHeader(title: 'Matches'),
              const SizedBox(height: 10),
              matchesAsync.when(
                data: (selection) {
                  final matches = [
                    ...selection.liveMatches,
                    ...selection.upcomingMatches,
                  ].take(4).toList(growable: false);
                  if (matches.isEmpty) {
                    return FzEmptyState(
                      title: 'No matches',
                      description: 'Check soon.',
                      icon: const Icon(LucideIcons.calendar),
                      actionLabel: 'Play',
                      onAction: () => context.go('/pools'),
                    );
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
                            liveMinute: match.isLive
                                ? match.kickoffLabel
                                : null,
                            onTap: () => context.push('/match/${match.id}'),
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 34),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => StateView.error(
                  title: 'Load failed',
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
                  _HeroPill(icon: LucideIcons.timer, label: '$pending pending'),
                  const _HeroPill(icon: LucideIcons.zap, label: 'Ready'),
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
      childAspectRatio: 1.05,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        AppQuickAction(
          icon: AppIconName.bars,
          label: 'Bars',
          color: FzColors.cyan,
          onTap: onBrowseVenues,
        ),
        AppQuickAction(
          icon: AppIconName.pool,
          label: 'Pools',
          color: FzColors.orange,
          onTap: onJoinPool,
        ),
        AppQuickAction(
          icon: AppIconName.game,
          label: 'Games',
          color: FzColors.danger,
          onTap: onJoinGame,
        ),
        AppQuickAction(
          icon: AppIconName.plus,
          label: 'Create',
          color: FzColors.green,
          onTap: onCreate,
        ),
      ],
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
      return FzCard(
        padding: const EdgeInsets.all(16),
        borderRadius: FzRadii.card,
        child: const Text(
          'Pick teams.',
          style: TextStyle(
            color: FzColors.darkMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

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

class _TeamsLoadingStrip extends StatelessWidget {
  const _TeamsLoadingStrip();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 82,
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
      return AppVenueCard(
        name: 'Find bars',
        isLive: false,
        onTap: () => context.go('/venues'),
      );
    }

    return AppVenueCard(
      name: venue!.name,
      city: venue!.city ?? venue!.countryCode.label,
      coverUrl: venue!.coverUrl,
      isLive: true,
      onTap: () => context.push('/venue/${venue!.id}'),
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
            Icon(LucideIcons.trophy, color: FzColors.green),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No live pools.',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );
    }

    return AppPoolCard(
      title: pool!.title,
      status: pool!.status,
      totalStakedFet: pool!.totalStakedFet,
      totalMembers: pool!.totalMembers,
      defaultStakeFet: pool!.defaultStakeFet,
      onTap: () => context.push('/pool/${pool!.id}'),
      onJoin: () => context.push('/pool/${pool!.id}/join'),
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

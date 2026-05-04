import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/sports/match_model.dart';
import '../../../providers/matches_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/common/team_crest.dart';
import '../../pools/data/pools_repository.dart';

class MatchDetailScreen extends ConsumerWidget {
  const MatchDetailScreen({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchAsync = ref.watch(matchDetailProvider(matchId));

    return Scaffold(
      body: SafeArea(
        child: matchAsync.when(
          data: (match) {
            if (match == null) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
                children: [
                  const FzBackHeader(
                    title: 'MATCH',
                    subtitle: 'Pools for this fixture',
                  ),
                  const SizedBox(height: 48),
                  StateView.empty(
                    title: 'Match not found',
                    subtitle: 'Open pools to choose another match.',
                    icon: LucideIcons.trophy,
                    action: () => context.go('/pools'),
                    actionLabel: 'Open Pools',
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
              children: [
                const FzBackHeader(
                  title: 'Match Pools',
                  subtitle: 'Arena entries for this fixture',
                ),
                const SizedBox(height: 18),
                _MatchHeroCard(match: match),
                const SizedBox(height: 14),
                _PoolEntryCard(match: match),
                const SizedBox(height: 14),
                _MatchPoolsList(matchId: match.id),
              ],
            );
          },
          loading: () => const _MatchPoolsLoadingState(),
          error: (_, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
            children: [
              const FzBackHeader(
                title: 'Match Pools',
                subtitle: 'Arena entries for this fixture',
              ),
              const SizedBox(height: 48),
              StateView.error(
                title: 'Match pools unavailable',
                subtitle: 'Try again later.',
                onRetry: () => ref.invalidate(matchDetailProvider(matchId)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchHeroCard extends StatelessWidget {
  const _MatchHeroCard({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    final statusColor = match.isLive ? FzColors.danger : FzColors.cyan;
    return FzCard(
      padding: const EdgeInsets.all(18),
      borderColor: match.isLive ? FzColors.activeBorderRed : null,
      child: Column(
        children: [
          Row(
            children: [
              Text(
                match.kickoffLabel,
                style: FzTypography.metaLabel(color: statusColor),
              ),
              const Spacer(),
              Text(
                match.season,
                style: FzTypography.metaLabel(color: FzColors.darkMuted),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _HeroTeam(match.homeTeam, match.homeLogoUrl)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  match.scoreDisplay ?? 'VS',
                  style: FzTypography.heroScore(
                    size: match.isLive ? 48 : 36,
                    color: match.isLive ? FzColors.danger : FzColors.darkText,
                  ),
                ),
              ),
              Expanded(
                child: _HeroTeam(
                  match.awayTeam,
                  match.awayLogoUrl,
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroTeam extends StatelessWidget {
  const _HeroTeam(this.name, this.logoUrl, {this.alignEnd = false});

  final String name;
  final String? logoUrl;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        TeamCrest(label: name, crestUrl: logoUrl, size: 52),
        const SizedBox(height: 10),
        Text(
          name,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: FzColors.darkText,
          ),
        ),
      ],
    );
  }
}

class _MatchPoolsLoadingState extends StatelessWidget {
  const _MatchPoolsLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
          FzBackHeader(
            title: 'MATCH',
            subtitle: 'Pools for this fixture',
          ),
          Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}

class _PoolEntryCard extends StatelessWidget {
  const _PoolEntryCard({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Join a venue-linked pool for this match.',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: FzColors.darkText,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/pools/create'),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Create pool'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FzColors.accent2,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/pools'),
              icon: const Icon(LucideIcons.trophy, size: 16),
              label: const Text('Open match pools'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchPoolsList extends ConsumerWidget {
  const _MatchPoolsList({required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poolsAsync = ref.watch(matchPoolsProvider(matchId));

    return poolsAsync.when(
      data: (pools) {
        if (pools.isEmpty) {
          return const FzCard(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(LucideIcons.trophy, color: FzColors.darkMuted),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No pools are open for this match yet.',
                    style: TextStyle(fontSize: 13, color: FzColors.darkMuted),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OPEN POOLS',
              style: FzTypography.sportsTitle(size: 22, color: FzColors.darkText),
            ),
            const SizedBox(height: 10),
            ...pools.map(
              (pool) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FzCard(
                  onTap: () => context.push('/pool/${pool.id}'),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pool.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '${pool.scope} - ${pool.totalMembers} members - ${pool.totalStakedFet} FET',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: FzColors.darkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(LucideIcons.chevronRight, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

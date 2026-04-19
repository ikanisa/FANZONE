import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/market/launch_market.dart';
import '../../../models/featured_event_model.dart';
import '../../../models/global_challenge_model.dart';
import '../../../models/pool.dart';
import '../../../providers/market_preferences_provider.dart';
import '../../../providers/matches_provider.dart';
import '../../../providers/teams_provider.dart';
import '../../../services/pool_service.dart';
import '../../../services/team_community_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/fan/fan_identity_widgets.dart';
import '../../../widgets/match/match_list_widgets.dart';
import '../../../widgets/team/team_widgets.dart';
import '../../../widgets/common/featured_event_banner.dart';

class MatchdayHubScreen extends ConsumerWidget {
  const MatchdayHubScreen({super.key});

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final matchesAsync = ref.watch(matchesByDateProvider(_today));
    final poolsAsync = ref.watch(poolServiceProvider);
    final teamsAsync = ref.watch(teamsProvider);
    final launchEventsAsync = ref.watch(homeLaunchEventsProvider);
    final launchChallengesAsync = ref.watch(spotlightChallengesProvider);
    final supportedIds =
        ref.watch(supportedTeamsServiceProvider).valueOrNull ??
        const <String>{};
    final primaryRegion = ref.watch(primaryMarketRegionProvider);
    final focusTags = ref.watch(marketFocusTagsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: FzColors.accent,
          onRefresh: () async {
            ref.invalidate(matchesByDateProvider(_today));
            ref.invalidate(poolServiceProvider);
            ref.invalidate(teamsProvider);
            ref.invalidate(supportedTeamsServiceProvider);
            ref.invalidate(homeLaunchEventsProvider);
            ref.invalidate(spotlightChallengesProvider);
            await Future.wait([
              ref.read(matchesByDateProvider(_today).future),
              ref.read(poolServiceProvider.future),
              ref.read(teamsProvider.future),
              ref.read(homeLaunchEventsProvider.future),
              ref.read(spotlightChallengesProvider.future),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MATCHDAY HUB',
                          style: FzTypography.display(
                            size: 32,
                            color: isDark
                                ? FzColors.darkText
                                : FzColors.lightText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Predict matches, follow global football moments, support clubs, and move FET across Africa, Europe, and North America.',
                          style: TextStyle(fontSize: 13, color: muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.push('/search'),
                    icon: const Icon(Icons.search_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const FanIdentityCard(),
              const SizedBox(height: 16),
              // ── Featured Event Banner (Phase 5) ──
              const FeaturedEventBanner(),
              const SizedBox(height: 16),
              _LaunchStrategyCard(
                primaryRegion: primaryRegion,
                focusTags: focusTags,
                spotlightEventsAsync: launchEventsAsync,
                onRetrySpotlightEvents: () =>
                    ref.invalidate(homeLaunchEventsProvider),
              ),
              const SizedBox(height: 16),
              const _HubActionGrid(),
              const SizedBox(height: 20),
              _HubSectionHeader(
                title: 'Live Now',
                actionLabel: 'Score Centre',
                onAction: () => context.push('/scores'),
              ),
              const SizedBox(height: 10),
              matchesAsync.when(
                data: (matches) {
                  final liveMatches =
                      matches.where((match) => match.isLive).toList()
                        ..sort((a, b) => a.date.compareTo(b.date));
                  final upcomingMatches =
                      matches.where((match) => match.isUpcoming).toList()
                        ..sort((a, b) => a.date.compareTo(b.date));
                  final totalPredictionMatches =
                      liveMatches.length + upcomingMatches.length;

                  return Column(
                    children: [
                      FzCard(
                        padding: const EdgeInsets.all(16),
                        borderColor: FzColors.accent.withValues(alpha: 0.25),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: FzColors.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                LucideIcons.target,
                                color: FzColors.accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$totalPredictionMatches matches ready for prediction',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Free slips build streaks first. Pools and challenges put FET in play when you want extra competition.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: muted,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (liveMatches.isEmpty)
                        FzCard(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No live matches right now. Upcoming prediction windows are listed below.',
                            style: TextStyle(
                              fontSize: 12,
                              color: muted,
                              height: 1.35,
                            ),
                          ),
                        )
                      else
                        MatchListCard(
                          matches: liveMatches.take(4).toList(),
                          onTapMatch: (match) =>
                              context.push('/match/${match.id}'),
                        ),
                      const SizedBox(height: 20),
                      _HubSectionHeader(
                        title: 'Upcoming Matches',
                        actionLabel: 'Fixtures',
                        onAction: () => context.push('/fixtures'),
                      ),
                      const SizedBox(height: 10),
                      if (upcomingMatches.isEmpty)
                        StateView.empty(
                          title: 'No upcoming match windows yet',
                          subtitle:
                              'Open the score centre for the wider fixture list and results archive.',
                          icon: LucideIcons.calendar,
                        )
                      else
                        MatchListCard(
                          matches: upcomingMatches.take(6).toList(),
                          onTapMatch: (match) =>
                              context.push('/match/${match.id}'),
                        ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => StateView.error(
                  title: 'Could not load matchday picks',
                  onRetry: () => ref.invalidate(matchesByDateProvider(_today)),
                ),
              ),
              const SizedBox(height: 20),
              _HubSectionHeader(
                title: 'Pools & Challenges',
                actionLabel: 'Open Predict',
                onAction: () => context.go('/predict'),
              ),
              const SizedBox(height: 10),
              launchChallengesAsync.when(
                data: (challenges) {
                  if (challenges.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      children: [
                        for (var i = 0; i < challenges.length; i++) ...[
                          _GlobalChallengeCard(
                            challenge: challenges[i],
                            onTap: () => context.go('/predict'),
                          ),
                          if (i < challenges.length - 1)
                            const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              poolsAsync.when(
                data: (pools) {
                  final featured =
                      pools.where((pool) => pool.status == 'open').toList()
                        ..sort((a, b) => a.lockAt.compareTo(b.lockAt));

                  if (featured.isEmpty) {
                    return FzCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.swords,
                            size: 18,
                            color: FzColors.accent,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No open pools right now. Use free slips today and come back for the next challenge window.',
                              style: TextStyle(
                                fontSize: 12,
                                color: muted,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final visiblePools = featured.take(3).toList();
                  return Column(
                    children: [
                      for (var i = 0; i < visiblePools.length; i++) ...[
                        _PoolPreviewCard(
                          pool: visiblePools[i],
                          onTap: () => context.push(
                            '/predict/pool/${visiblePools[i].id}',
                          ),
                        ),
                        if (i < visiblePools.length - 1)
                          const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => StateView.error(
                  title: 'Could not load pools',
                  onRetry: () => ref.invalidate(poolServiceProvider),
                ),
              ),
              const SizedBox(height: 20),
              _HubSectionHeader(
                title: 'My Clubs',
                actionLabel: 'Open Clubs',
                onAction: () => context.go('/clubs'),
              ),
              const SizedBox(height: 10),
              teamsAsync.when(
                data: (teams) {
                  final supported = teams
                      .where((team) => supportedIds.contains(team.id))
                      .toList();
                  final featured = teams
                      .where((team) => team.isFeatured)
                      .take(3);
                  final visibleTeams = supported.isNotEmpty
                      ? supported.take(3).toList()
                      : featured.toList();

                  if (visibleTeams.isEmpty) {
                    return StateView.empty(
                      title: 'No clubs selected yet',
                      subtitle:
                          'Open Clubs to join supporter communities and register your fan identity.',
                      icon: LucideIcons.users,
                    );
                  }

                  return Column(
                    children: [
                      for (var i = 0; i < visibleTeams.length; i++) ...[
                        if (supported.isNotEmpty)
                          SupportedTeamCard(
                            team: visibleTeams[i],
                            index: i,
                            onTap: () => context.push(
                              '/clubs/team/${visibleTeams[i].id}',
                            ),
                          )
                        else
                          TeamCard(
                            team: visibleTeams[i],
                            index: i,
                            onTap: () => context.push(
                              '/clubs/team/${visibleTeams[i].id}',
                            ),
                          ),
                        if (i < visibleTeams.length - 1)
                          const SizedBox(height: 8),
                      ],
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => StateView.error(
                  title: 'Could not load clubs',
                  onRetry: () => ref.invalidate(teamsProvider),
                ),
              ),
              const SizedBox(height: 20),
              FzCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.activity,
                          size: 18,
                          color: FzColors.accent,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Score Centre',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? FzColors.darkText
                                : FzColors.lightText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Live score, fixtures, and following stay available here as supporting information.',
                      style: TextStyle(fontSize: 12, color: muted, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => context.push('/scores'),
                          icon: const Icon(LucideIcons.trophy, size: 16),
                          label: const Text('Scores'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/fixtures'),
                          icon: const Icon(LucideIcons.calendar, size: 16),
                          label: const Text('Fixtures'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/following'),
                          icon: const Icon(LucideIcons.star, size: 16),
                          label: const Text('Following'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LaunchStrategyCard extends StatelessWidget {
  const _LaunchStrategyCard({
    required this.primaryRegion,
    required this.focusTags,
    required this.spotlightEventsAsync,
    required this.onRetrySpotlightEvents,
  });

  final String primaryRegion;
  final Set<String> focusTags;
  final AsyncValue<List<FeaturedEventModel>> spotlightEventsAsync;
  final VoidCallback onRetrySpotlightEvents;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final effectiveFocusTags = focusTags.isEmpty
        ? defaultFocusTagsForRegion(primaryRegion)
        : focusTags.toList();

    return FzCard(
      padding: const EdgeInsets.all(16),
      borderColor: FzColors.accent.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: FzColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.globe2,
                  size: 18,
                  color: FzColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Global launch profile',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${launchRegionLabel(primaryRegion)} stays first in the queue while the wider football cycle remains visible.',
                      style: TextStyle(fontSize: 12, color: muted, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LaunchPill(label: launchRegionKicker(primaryRegion)),
              for (final tag in effectiveFocusTags.take(3))
                _LaunchPill(
                  label: launchMomentByTag(tag)?.title ?? tag,
                  accent: true,
                ),
            ],
          ),
          spotlightEventsAsync.when(
            data: (events) {
              if (events.isEmpty) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top moments right now',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: muted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < events.take(2).length; i++) ...[
                      _EventMomentumRow(event: events[i]),
                      if (i < events.take(2).length - 1)
                        const SizedBox(height: 8),
                    ],
                  ],
                ),
              );
            },
            loading: () => Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                'Loading top moments...',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.only(top: 14),
              child: TextButton(
                onPressed: onRetrySpotlightEvents,
                child: const Text('Retry top moments'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LaunchPill extends StatelessWidget {
  const _LaunchPill({required this.label, this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent
            ? FzColors.accent.withValues(alpha: 0.12)
            : (isDark ? FzColors.darkSurface2 : FzColors.lightSurface2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent
              ? FzColors.accent.withValues(alpha: 0.4)
              : (isDark ? FzColors.darkBorder : FzColors.lightBorder),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: accent
              ? FzColors.accent
              : (isDark ? FzColors.darkText : FzColors.lightText),
        ),
      ),
    );
  }
}

class _EventMomentumRow extends StatelessWidget {
  const _EventMomentumRow({required this.event});

  final FeaturedEventModel event;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final localStart = event.startDate.toLocal();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.shortName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  launchMomentByTag(event.eventTag)?.subtitle ??
                      (event.description ?? ''),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: muted, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('d MMM').format(localStart),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: FzColors.accent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                launchRegionLabel(event.region),
                style: TextStyle(fontSize: 10, color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HubActionGrid extends StatelessWidget {
  const _HubActionGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.45,
      children: [
        _HubActionCard(
          icon: LucideIcons.target,
          title: 'Predict',
          subtitle: 'Free slips and matchday picks',
          onTap: () => context.go('/predict'),
        ),
        _HubActionCard(
          icon: LucideIcons.users,
          title: 'Clubs',
          subtitle: 'Memberships, communities, fan zones',
          onTap: () => context.go('/clubs'),
        ),
        _HubActionCard(
          icon: LucideIcons.wallet,
          title: 'Wallet',
          subtitle: 'FET balance, transfers, and rewards',
          onTap: () => context.go('/wallet'),
        ),
        _HubActionCard(
          icon: LucideIcons.hash,
          title: 'Fan ID',
          subtitle: 'Identity, badges, and supporter registry',
          onTap: () => context.push('/clubs/fan-id'),
        ),
      ],
    );
  }
}

class _GlobalChallengeCard extends StatelessWidget {
  const _GlobalChallengeCard({required this.challenge, required this.onTap});

  final GlobalChallengeModel challenge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final entryLabel = challenge.entryFeeFet == 0
        ? 'Free'
        : '${challenge.entryFeeFet} FET';

    return FzCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      borderColor: FzColors.teal.withValues(alpha: 0.24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  challenge.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _LaunchPill(label: launchRegionLabel(challenge.region)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            challenge.description ?? 'Open prediction challenge',
            style: TextStyle(fontSize: 12, color: muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ChallengeStat(label: 'Entry', value: entryLabel),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ChallengeStat(
                  label: 'Prize',
                  value: '${challenge.prizePoolFet} FET',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChallengeStat extends StatelessWidget {
  const _ChallengeStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: muted,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _HubActionCard extends StatelessWidget {
  const _HubActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return FzCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      borderColor: FzColors.accent.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: FzColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: FzColors.accent),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: muted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _HubSectionHeader extends StatelessWidget {
  const _HubSectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: FzTypography.sectionLabel(
            isDark ? Brightness.dark : Brightness.light,
          ),
        ),
        const Spacer(),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _PoolPreviewCard extends StatelessWidget {
  const _PoolPreviewCard({required this.pool, required this.onTap});

  final ScorePool pool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return FzCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: FzColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              LucideIcons.swords,
              color: FzColors.accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pool.matchName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Created by ${pool.creatorName} • ${pool.participantsCount} fans',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PoolMetaChip(label: '${pool.stake} FET entry'),
                    _PoolMetaChip(label: '${pool.totalPool} FET pool'),
                    _PoolMetaChip(label: pool.status.toUpperCase()),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(LucideIcons.chevronRight, size: 18),
        ],
      ),
    );
  }
}

class _PoolMetaChip extends StatelessWidget {
  const _PoolMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isDark ? FzColors.darkMuted : FzColors.lightMuted,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

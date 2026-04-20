import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/competition_model.dart';
import '../../../models/team_model.dart';
import '../../../providers/competitions_provider.dart';
import '../../../providers/favourites_provider.dart';
import '../../../providers/teams_provider.dart';
import '../../../services/team_community_service.dart';
import '../../../theme/colors.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/match/match_list_widgets.dart';
import '../../../widgets/common/fz_glass_loader.dart';

// ──────────────────────────────────────────────
// Followable row (shared by teams & competitions)
// ──────────────────────────────────────────────

class FollowableRow extends StatelessWidget {
  const FollowableRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.selected,
    required this.onTap,
    this.onTrailingTap,
  });

  final String title;
  final String subtitle;
  final Widget leading;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return FzCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(fontSize: 12, color: muted)),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onTrailingTap ?? onTap,
            icon: Icon(
              selected ? Icons.star_rounded : Icons.add_rounded,
              color: selected ? FzColors.amber : FzColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Quick Add Section
// ──────────────────────────────────────────────

class QuickAddSection extends ConsumerWidget {
  const QuickAddSection({
    super.key,
    required this.query,
    required this.teamsAsync,
    required this.competitionsAsync,
    required this.muted,
  });

  final String query;
  final AsyncValue<List<TeamModel>> teamsAsync;
  final AsyncValue<List<CompetitionModel>> competitionsAsync;
  final Color muted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (teamsAsync.isLoading && competitionsAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: const FzGlassLoader(message: 'Syncing...'),
      );
    }

    if (teamsAsync.hasError && competitionsAsync.hasError) {
      return StateView.error(
        title: 'Could not search',
        onRetry: () {
          ref.invalidate(teamsProvider);
          ref.invalidate(competitionsProvider);
        },
      );
    }

    final lowered = query.toLowerCase();
    final matchingTeams = (teamsAsync.valueOrNull ?? [])
        .where((team) => team.name.toLowerCase().contains(lowered) || (team.shortName?.toLowerCase().contains(lowered) ?? false))
        .take(5)
        .toList();
    final matchingCompetitions = (competitionsAsync.valueOrNull ?? [])
        .where((competition) => competition.name.toLowerCase().contains(lowered) || competition.shortName.toLowerCase().contains(lowered) || competition.country.toLowerCase().contains(lowered))
        .take(5)
        .toList();

    if (matchingTeams.isEmpty && matchingCompetitions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('No results for "$query"', style: TextStyle(fontSize: 13, color: muted)),
      );
    }

    final favourites = ref.watch(favouritesProvider).valueOrNull ?? const FavouritesState();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ADD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: muted, letterSpacing: 0.8)),
        const SizedBox(height: 10),
        ...matchingTeams.map(
          (team) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FollowableRow(
              title: team.name,
              subtitle: team.country ?? team.shortName ?? '',
              leading: TeamAvatar(name: team.name),
              selected: favourites.isTeamFavourite(team.id),
              onTap: () => ref.read(favouritesProvider.notifier).toggleTeam(team.id),
            ),
          ),
        ),
        ...matchingCompetitions.map(
          (competition) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FollowableRow(
              title: competition.name,
              subtitle: competition.country,
              leading: const Icon(LucideIcons.trophy, size: 18, color: FzColors.primary),
              selected: favourites.isCompetitionFavourite(competition.id),
              onTap: () => ref.read(favouritesProvider.notifier).toggleCompetition(competition.id),
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Followed Teams Section
// ──────────────────────────────────────────────

class FollowedTeamsSection extends ConsumerWidget {
  const FollowedTeamsSection({
    super.key,
    required this.favourites,
    required this.teamsAsync,
    required this.muted,
  });

  final FavouritesState favourites;
  final AsyncValue<List<TeamModel>> teamsAsync;
  final Color muted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TEAMS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: muted, letterSpacing: 0.8)),
        const SizedBox(height: 10),
        teamsAsync.when(
          loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: const FzGlassLoader(message: 'Syncing...')),
          error: (err, st) => StateView.error(title: 'Could not load teams', onRetry: () => ref.invalidate(teamsProvider)),
          data: (allTeams) {
            final teams = allTeams.where((team) => favourites.isTeamFavourite(team.id)).toList()..sort((left, right) => left.name.compareTo(right.name));
            if (teams.isEmpty) return const SizedBox.shrink();
            return Column(
              children: teams.map(
                (team) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FollowableRow(
                    title: team.name,
                    subtitle: team.country ?? '',
                    leading: TeamAvatar(name: team.name),
                    selected: true,
                    onTap: () => context.push('/team/${team.id}'),
                    onTrailingTap: () => ref.read(favouritesProvider.notifier).toggleTeam(team.id),
                  ),
                ),
              ).toList(),
            );
          },
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Followed Competitions Section
// ──────────────────────────────────────────────

class FollowedCompetitionsSection extends ConsumerWidget {
  const FollowedCompetitionsSection({
    super.key,
    required this.favourites,
    required this.competitionsAsync,
    required this.muted,
  });

  final FavouritesState favourites;
  final AsyncValue<List<CompetitionModel>> competitionsAsync;
  final Color muted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('COMPETITIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: muted, letterSpacing: 0.8)),
        const SizedBox(height: 10),
        competitionsAsync.when(
          loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: const FzGlassLoader(message: 'Syncing...')),
          error: (err, st) => StateView.error(title: 'Could not load competitions', onRetry: () => ref.invalidate(competitionsProvider)),
          data: (allComps) {
            final competitions = allComps.where((competition) => favourites.isCompetitionFavourite(competition.id)).toList()..sort((left, right) => left.name.compareTo(right.name));
            if (competitions.isEmpty) return const SizedBox.shrink();
            return Column(
              children: competitions.map(
                (competition) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FollowableRow(
                    title: competition.name,
                    subtitle: competition.country,
                    leading: const Icon(LucideIcons.trophy, size: 18, color: FzColors.primary),
                    selected: true,
                    onTap: () => context.push('/league/${competition.id}'),
                    onTrailingTap: () => ref.read(favouritesProvider.notifier).toggleCompetition(competition.id),
                  ),
                ),
              ).toList(),
            );
          },
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Supported Teams Section
// ──────────────────────────────────────────────

class SupportedTeamsSection extends ConsumerWidget {
  const SupportedTeamsSection({super.key, required this.teamsAsync, required this.muted});

  final AsyncValue<List<TeamModel>> teamsAsync;
  final Color muted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supportedIds = ref.watch(supportedTeamsServiceProvider).valueOrNull ?? {};

    if (supportedIds.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('SUPPORTING', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: muted, letterSpacing: 0.8)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: FzColors.maltaRed.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Text('${supportedIds.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: FzColors.maltaRed)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        teamsAsync.when(
          loading: () => Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('Loading supported teams...', style: TextStyle(fontSize: 12, color: muted))),
          error: (_, errorDetails) => Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('Supported teams are unavailable right now.', style: TextStyle(fontSize: 12, color: muted))),
          data: (allTeams) {
            final supported = allTeams.where((team) => supportedIds.contains(team.id)).toList()..sort((a, b) => a.name.compareTo(b.name));
            if (supported.isEmpty) return const SizedBox.shrink();
            return Column(
              children: supported.map(
                (team) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FollowableRow(
                    title: team.name,
                    subtitle: team.country ?? '',
                    leading: TeamAvatar(name: team.name),
                    selected: true,
                    onTap: () => context.push('/team/${team.id}'),
                    onTrailingTap: () => ref.read(supportedTeamsServiceProvider.notifier).toggleSupport(team.id),
                  ),
                ),
              ).toList(),
            );
          },
        ),
      ],
    );
  }
}

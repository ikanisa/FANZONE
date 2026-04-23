import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/match_model.dart';
import '../../../models/team_model.dart';
import '../../../providers/competitions_provider.dart';
import '../../../providers/matches_provider.dart';
import '../../../providers/teams_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/common/team_crest.dart';

class TeamProfileScreen extends ConsumerWidget {
  const TeamProfileScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamProvider(teamId));
    final matchesAsync = ref.watch(teamMatchesProvider(teamId));
    final competitions = ref.watch(competitionsProvider).valueOrNull ?? const [];

    return teamAsync.when(
      data: (team) {
        if (team == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Team')),
            body: StateView.empty(
              title: 'Team not found',
              subtitle: 'Return to fixtures to choose another team.',
              icon: LucideIcons.shield,
            ),
          );
        }

        String? competitionName;
        for (final competition in competitions) {
          if (team.competitionIds.contains(competition.id)) {
            competitionName = competition.name;
            break;
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(team.name),
            leading: IconButton(
              tooltip: 'Back',
              onPressed: () => context.pop(),
              icon: const Icon(LucideIcons.chevronLeft),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              _TeamHeroCard(team: team, competitionName: competitionName),
              if ((team.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                FzCard(
                  child: Text(
                    team.description!.trim(),
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: FzColors.darkText,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const _SectionTitle(title: 'Team Snapshot'),
              const SizedBox(height: 10),
              _TeamSnapshotCard(team: team, competitionName: competitionName),
              const SizedBox(height: 24),
              const _SectionTitle(title: 'Recent Fixtures'),
              const SizedBox(height: 10),
              matchesAsync.when(
                data: (matches) {
                  final visible = matches.take(6).toList(growable: false);
                  if (visible.isEmpty) {
                    return StateView.empty(
                      title: 'No fixtures available',
                      subtitle: 'Recent and upcoming matches will appear here.',
                      icon: LucideIcons.calendar,
                    );
                  }

                  return FzCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var index = 0; index < visible.length; index++) ...[
                          if (index > 0) const Divider(height: 0.5, indent: 68),
                          _FixtureRow(match: visible[index]),
                        ],
                      ],
                    ),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (_, _) => StateView.error(
                  title: 'Could not load fixtures',
                  onRetry: () => ref.invalidate(teamMatchesProvider(teamId)),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(title: const Text('Team')),
        body: StateView.error(
          title: 'Could not load team profile',
          onRetry: () => ref.invalidate(teamProvider(teamId)),
        ),
      ),
    );
  }
}

class _TeamHeroCard extends StatelessWidget {
  const _TeamHeroCard({required this.team, required this.competitionName});

  final TeamModel team;
  final String? competitionName;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TeamCrest(
                label: team.name,
                crestUrl: team.crestUrl ?? team.logoUrl,
                size: 64,
                backgroundColor: FzColors.darkSurface2,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: FzTypography.display(
                        size: 28,
                        color: FzColors.darkText,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if ((competitionName ?? '').trim().isNotEmpty)
                          competitionName!.trim(),
                        if ((team.country ?? '').trim().isNotEmpty)
                          team.country!.trim(),
                      ].join(' • '),
                      style: const TextStyle(
                        fontSize: 13,
                        color: FzColors.darkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (team.aliases.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final alias in team.aliases.take(6))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: FzColors.darkSurface2,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: FzColors.darkBorder),
                    ),
                    child: Text(
                      alias,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: FzColors.darkText,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TeamSnapshotCard extends StatelessWidget {
  const _TeamSnapshotCard({required this.team, required this.competitionName});

  final TeamModel team;
  final String? competitionName;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      child: Column(
        children: [
          _SnapshotRow(
            label: 'Competition',
            value: (competitionName ?? '').trim().isEmpty
                ? 'Unassigned'
                : competitionName!,
          ),
          const Divider(height: 20, color: FzColors.darkBorder),
          _SnapshotRow(
            label: 'Country',
            value: (team.country ?? '').trim().isEmpty ? 'Unknown' : team.country!,
          ),
          const Divider(height: 20, color: FzColors.darkBorder),
          _SnapshotRow(
            label: 'Followers',
            value: '${team.fanCount}',
          ),
        ],
      ),
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: FzColors.darkMuted,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: FzColors.darkText,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: FzTypography.display(
        size: 24,
        color: FzColors.darkText,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _FixtureRow extends StatelessWidget {
  const _FixtureRow({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    final subtitle = match.isFinished
        ? (match.scoreDisplay ?? 'FT')
        : match.kickoffLabel;

    return InkWell(
      onTap: () => context.push('/match/${match.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _FixtureTeam(
                name: match.homeTeam,
                crestUrl: match.homeLogoUrl,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: FzColors.darkMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    match.isFinished ? 'RESULT' : 'FIXTURE',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: FzColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _FixtureTeam(
                name: match.awayTeam,
                crestUrl: match.awayLogoUrl,
                alignEnd: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FixtureTeam extends StatelessWidget {
  const _FixtureTeam({
    required this.name,
    required this.crestUrl,
    this.alignEnd = false,
  });

  final String name;
  final String? crestUrl;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        TeamCrest(
          label: name,
          crestUrl: crestUrl,
          size: 36,
          backgroundColor: FzColors.darkSurface2,
        ),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: FzColors.darkText,
          ),
        ),
      ],
    );
  }
}

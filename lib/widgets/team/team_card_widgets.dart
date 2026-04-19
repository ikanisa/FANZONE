import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/team_model.dart';
import '../../services/team_community_service.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../common/fz_animated_entry.dart';
import '../common/fz_card.dart';
import '../match/match_list_widgets.dart';
import 'team_support_widgets.dart';
import 'team_widget_utils.dart';

class TeamCard extends ConsumerWidget {
  const TeamCard({super.key, required this.team, this.onTap, this.index = 0});

  final TeamModel team;
  final VoidCallback? onTap;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final supported =
        ref.watch(supportedTeamsServiceProvider).valueOrNull ?? {};
    final isSupported = supported.contains(team.id);

    return FzAnimatedEntry(
      index: index,
      child: FzCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            TeamAvatar(
              name: team.name,
              logoUrl: team.logoUrl ?? team.crestUrl,
              size: 44,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (team.leagueName != null || team.country != null)
                        Expanded(
                          child: Text(
                            team.leagueName ?? team.country ?? '',
                            style: TextStyle(fontSize: 12, color: muted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (team.fanCount > 0) ...[
                        const SizedBox(width: 8),
                        SupporterCounterChip(count: team.fanCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SupportTeamButton(
              isSupported: isSupported,
              compact: true,
              onTap: () => ref
                  .read(supportedTeamsServiceProvider.notifier)
                  .toggleSupport(team.id),
            ),
          ],
        ),
      ),
    );
  }
}

class SupportedTeamCard extends StatelessWidget {
  const SupportedTeamCard({
    super.key,
    required this.team,
    this.onTap,
    this.onUnsupport,
    this.index = 0,
  });

  final TeamModel team;
  final VoidCallback? onTap;
  final VoidCallback? onUnsupport;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return FzAnimatedEntry(
      index: index,
      child: FzCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            TeamAvatar(
              name: team.name,
              logoUrl: team.logoUrl ?? team.crestUrl,
              size: 40,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (team.fanCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${formatCompactTeamCount(team.fanCount)} supporters',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class TeamHeroHeader extends ConsumerWidget {
  const TeamHeroHeader({super.key, required this.team});

  final TeamModel team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final supported =
        ref.watch(supportedTeamsServiceProvider).valueOrNull ?? {};
    final isSupported = supported.contains(team.id);

    return FzCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  FzColors.accent.withValues(alpha: isDark ? 0.15 : 0.08),
                  FzColors.violet.withValues(alpha: isDark ? 0.1 : 0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                TeamAvatar(
                  name: team.name,
                  logoUrl: team.logoUrl ?? team.crestUrl,
                  size: 72,
                ),
                const SizedBox(height: 14),
                Text(
                  team.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (team.leagueName != null || team.country != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      team.leagueName,
                      team.country,
                    ].where((s) => s != null && s.isNotEmpty).join(' · '),
                    style: TextStyle(fontSize: 13, color: muted),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (team.description != null &&
                    team.description!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    team.description!,
                    style: TextStyle(fontSize: 13, color: muted, height: 1.5),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              children: [
                _HeroStat(
                  label: 'Fans',
                  value: formatCompactTeamCount(team.fanCount),
                ),
                const SizedBox(width: 16),
                _HeroStat(
                  label: 'Leagues',
                  value: '${team.competitionIds.length}',
                ),
                const Spacer(),
                SupportTeamButton(
                  isSupported: isSupported,
                  compact: false,
                  onTap: () => ref
                      .read(supportedTeamsServiceProvider.notifier)
                      .toggleSupport(team.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Column(
      children: [
        Text(value, style: FzTypography.score(size: 18)),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

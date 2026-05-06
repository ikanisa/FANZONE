import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';
import '../../theme/typography.dart';
import '../../widgets/common/team_crest.dart';

/// Match card matching reference — league chip, team crests, VS, score, time.
class AppMatchCard extends StatelessWidget {
  const AppMatchCard({
    super.key,
    required this.homeTeam,
    required this.awayTeam,
    this.homeLogoUrl,
    this.awayLogoUrl,
    this.competitionName,
    this.kickoffLabel,
    this.homeScore,
    this.awayScore,
    this.isLive = false,
    this.liveMinute,
    this.openPoolCount,
    this.onTap,
  });

  final String homeTeam;
  final String awayTeam;
  final String? homeLogoUrl;
  final String? awayLogoUrl;
  final String? competitionName;
  final String? kickoffLabel;
  final int? homeScore;
  final int? awayScore;
  final bool isLive;
  final String? liveMinute;
  final int? openPoolCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isLive ? FzColors.activeBorderRed : FzColors.darkBorder;

    return Material(
      color: Colors.transparent,
      borderRadius: FzRadii.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: FzRadii.cardRadius,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: FzColors.darkSurface,
            borderRadius: FzRadii.cardRadius,
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              // League chip row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (competitionName != null)
                    _LeagueChip(label: competitionName!)
                  else
                    const SizedBox.shrink(),
                  if (isLive && liveMinute != null)
                    _LiveChip(minute: liveMinute!)
                  else if (kickoffLabel != null)
                    Text(
                      kickoffLabel!,
                      style: FzTypography.chipLabel(
                        size: 12,
                        color: FzColors.darkMuted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Teams + Score row
              Row(
                children: [
                  // Home team
                  Expanded(
                    child: Column(
                      children: [
                        TeamCrest(
                          label: homeTeam,
                          crestUrl: homeLogoUrl,
                          size: 48,
                          backgroundColor: FzColors.darkSurface2,
                          borderColor: FzColors.darkBorder,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _shortName(homeTeam),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Score / VS
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _buildScoreOrVs(),
                  ),
                  // Away team
                  Expanded(
                    child: Column(
                      children: [
                        TeamCrest(
                          label: awayTeam,
                          crestUrl: awayLogoUrl,
                          size: 48,
                          backgroundColor: FzColors.darkSurface2,
                          borderColor: FzColors.darkBorder,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _shortName(awayTeam),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Pool count
              if (openPoolCount != null && openPoolCount! > 0) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.trophy,
                      size: 14,
                      color: FzColors.cyan,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$openPoolCount pool${openPoolCount! > 1 ? 's' : ''}',
                      style: FzTypography.chipLabel(
                        size: 12,
                        color: FzColors.cyan,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreOrVs() {
    if (homeScore != null && awayScore != null) {
      return Column(
        children: [
          Text(
            '$homeScore - $awayScore',
            style: FzTypography.heroScore(
              size: isLive ? 36 : 28,
              color: isLive ? FzColors.danger : FzColors.darkText,
            ),
          ),
        ],
      );
    }
    return Text(
      'VS',
      style: FzTypography.sportsTitle(size: 22, color: FzColors.darkMuted),
    );
  }

  static String _shortName(String name) {
    if (name.length <= 12) return name;
    final parts = name.split(' ');
    if (parts.length >= 2) return parts.last;
    return name.substring(0, 10);
  }
}

class _LeagueChip extends StatelessWidget {
  const _LeagueChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: FzColors.darkSurface2,
        borderRadius: FzRadii.fullRadius,
        border: Border.all(color: FzColors.darkBorder),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: FzTypography.chipLabel(size: 11, color: FzColors.darkMuted),
      ),
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip({required this.minute});

  final String minute;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: FzColors.danger.withValues(alpha: 0.14),
        borderRadius: FzRadii.fullRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: FzColors.danger,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            minute,
            style: FzTypography.chipLabel(size: 12, color: FzColors.danger),
          ),
        ],
      ),
    );
  }
}

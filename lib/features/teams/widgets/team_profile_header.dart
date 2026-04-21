import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/material.dart';

import '../../../models/competition_model.dart';
import '../../../models/team_contribution_model.dart';
import '../../../models/team_model.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/team_crest.dart';

/// Back-bar header for the team profile screen.
class TeamProfileHeader extends StatelessWidget {
  const TeamProfileHeader({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: (isDark ? FzColors.darkSurface : FzColors.lightSurface)
            .withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(
            color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(LucideIcons.chevronLeft, color: textColor),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Team Profile',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: muted,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// Full-width gradient hero banner with crest overlay.
class TeamHeroBanner extends StatelessWidget {
  const TeamHeroBanner({
    super.key,
    required this.team,
    required this.competition,
  });

  final TeamModel team;
  final CompetitionModel? competition;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 192,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 176,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  FzColors.secondary.withValues(alpha: 0.30),
                  FzColors.primary.withValues(alpha: 0.16),
                ],
              ),
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                (competition?.name ?? team.leagueName ?? 'Club').toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white54,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            bottom: 0,
            child: Container(
              width: 96,
              height: 96,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? FzColors.darkSurface
                    : FzColors.lightSurface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? FzColors.darkSurface2
                      : FzColors.lightSurface2,
                  width: 4,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: TeamCrest(
                label: team.name,
                crestUrl: team.crestUrl ?? team.logoUrl,
                size: 72,
                backgroundColor: Colors.transparent,
                borderColor: Colors.transparent,
                borderWidth: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Team name, stats row, contribution add-on, and membership button.
class TeamInfoSection extends StatelessWidget {
  const TeamInfoSection({
    super.key,
    required this.team,
    required this.stats,
    required this.clubRank,
    required this.isSupported,
    required this.isAuthenticated,
    required this.onMembershipTap,
  });

  final TeamModel team;
  final TeamCommunityStats? stats;
  final int clubRank;
  final bool isSupported;
  final bool isAuthenticated;
  final VoidCallback onMembershipTap;

  @override
  Widget build(BuildContext context) {
    final members = stats?.fanCount ?? team.fanCount;
    final totalFet = stats?.totalFetContributed ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            team.name,
            style: FzTypography.display(
              size: 30,
              color: textColor,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${team.country ?? 'Club'}${team.leagueName != null ? ' · ${team.leagueName}' : ''}',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  value: _formatCompact(members),
                  label: 'Members',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(value: '$clubRank', label: 'Club Rank'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  value: _formatCompact(totalFet),
                  label: 'Club FET',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? FzColors.darkSurface3 : FzColors.lightSurface3,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _addonTitle(team),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _addonValue(team),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: FzColors.primary,
                    letterSpacing: 2.0,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _addonDescription(team),
                  style: TextStyle(fontSize: 10, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onMembershipTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: FzColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      FzColors.primary.withValues(alpha: 0.20),
                      FzColors.primary.withValues(alpha: 0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: FzColors.primary.withValues(alpha: 0.30),
                  ),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  child: Text(
                    isAuthenticated && isSupported
                        ? 'Manage Membership'
                        : 'Join ${team.shortName ?? team.name} Fan Club — Free',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatCompact(int value) {
    if (value >= 1000) {
      final compact = value / 1000;
      final display = compact >= 10
          ? compact.toStringAsFixed(1)
          : compact.toStringAsFixed(2);
      return '${display.replaceFirst(RegExp(r'\.0+$'), '')}K';
    }
    return value.toString();
  }

  String _addonTitle(TeamModel team) {
    if ((team.country ?? '').toLowerCase().contains('malta')) {
      return 'BOV MOBILE PAY ADD-ON';
    }
    if (team.fiatContributionsEnabled) return 'MOMO USSD ADD-ON';
    if (team.fetContributionsEnabled) return 'FET CONTRIBUTION ADD-ON';
    return 'FAN SUPPORT CHANNEL';
  }

  String _addonValue(TeamModel team) {
    if ((team.country ?? '').toLowerCase().contains('malta')) {
      return '79X2 84X1';
    }
    if (team.fiatContributionMode != null &&
        team.fiatContributionMode!.isNotEmpty) {
      return team.fiatContributionMode!.toUpperCase().replaceAll('_', ' ');
    }
    if (team.fetContributionsEnabled) return 'FET ENABLED';
    return 'NOT AVAILABLE';
  }

  String _addonDescription(TeamModel team) {
    if ((team.country ?? '').toLowerCase().contains('malta')) {
      return 'Send instantly using BOV Mobile Pay · Verified via Fan ID';
    }
    if (team.fiatContributionsEnabled || team.fetContributionsEnabled) {
      return 'Send instantly using MoMo USSD · Verified via Fan ID';
    }
    return 'Contribution channels are not available for this club yet.';
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface3 : FzColors.lightSurface3,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isDark ? FzColors.darkMuted : FzColors.lightMuted,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

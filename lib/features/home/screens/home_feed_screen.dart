import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../data/team_search_database.dart';
import '../../../features/profile/providers/profile_identity_provider.dart';
import '../../../models/match_model.dart';
import '../../../providers/competitions_provider.dart';
import '../../../providers/matches_provider.dart';
import '../../../services/team_community_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_badge.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/match/match_list_widgets.dart';
import '../../../widgets/common/fz_shimmer.dart';

class HomeFeedScreen extends ConsumerWidget {
  const HomeFeedScreen({super.key});

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final matchesAsync = ref.watch(matchesByDateProvider(_today));
    final supportedIds =
        ref.watch(supportedTeamsServiceProvider).valueOrNull ??
        const <String>{};
    final competitions =
        ref.watch(competitionsProvider).valueOrNull ?? const [];
    final competitionLabels = {
      for (final competition in competitions)
        competition.id: competition.shortName.isNotEmpty
            ? competition.shortName
            : competition.name,
    };
    final profileIdentity = ref.watch(profileIdentityProvider).valueOrNull;
    final fallbackInsightTeam = _resolveInsightTeam(supportedIds);
    final insightTeamId =
        profileIdentity?.teamId ?? fallbackInsightTeam?.id ?? 'liverpool';
    final insightTeamName =
        profileIdentity?.teamName ?? fallbackInsightTeam?.name ?? 'Liverpool';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: FzColors.primary,
          onRefresh: () async {
            ref.invalidate(matchesByDateProvider(_today));
            await ref.read(matchesByDateProvider(_today).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Predictions',
                      style: FzTypography.display(
                        size: 36,
                        color: textColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  _RoundActionButton(
                    tooltip: 'Create pool',
                    backgroundColor: FzColors.coral,
                    foregroundColor: FzColors.darkBg,
                    icon: LucideIcons.plusCircle,
                    onTap: () => context.go('/pools/create'),
                  ),
                  const SizedBox(width: 8),
                  _RoundActionButton(
                    tooltip: 'Open registry',
                    icon: LucideIcons.shield,
                    onTap: () => context.go('/registry'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              matchesAsync.when(
                data: (matches) {
                  final liveMatches =
                      matches.where((match) => match.isLive).toList()
                        ..sort((a, b) => a.date.compareTo(b.date));
                  final upcomingMatches =
                      matches.where((match) => match.isUpcoming).toList()
                        ..sort((a, b) => a.date.compareTo(b.date));
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DailyInsightCard(
                        muted: muted,
                        teamId: insightTeamId,
                        teamName: insightTeamName,
                      ),
                      const SizedBox(height: 24),
                      _HomeSectionHeader(
                        icon: LucideIcons.activity,
                        iconColor: FzColors.danger,
                        title: 'Live Action',
                        trailing: FzBadge(
                          label: '${liveMatches.length}',
                          variant: FzBadgeVariant.danger,
                          pulse: liveMatches.isNotEmpty,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (liveMatches.isEmpty)
                        _CompactEmptyCard(
                          icon: LucideIcons.trophy,
                          title: 'No Live Matches',
                          subtitle: 'Check upcoming.',
                          muted: muted,
                        )
                      else
                        _MatchGrid(
                          matches: liveMatches,
                          competitionLabels: competitionLabels,
                          onPredict: (match) =>
                              context.push('/match/${match.id}'),
                          onPool: () => context.push('/pools/create'),
                        ),
                      const SizedBox(height: 24),
                      _HomeSectionHeader(
                        icon: LucideIcons.calendar,
                        iconColor: muted,
                        title: 'Upcoming',
                        trailing: IconButton(
                          onPressed: () => context.go('/fixtures'),
                          tooltip: 'Open fixtures',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            LucideIcons.chevronRight,
                            size: 18,
                            color: muted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (upcomingMatches.isEmpty)
                        _CompactEmptyCard(
                          icon: LucideIcons.calendar,
                          title: 'No Upcoming',
                          subtitle: 'None left.',
                          muted: muted,
                        )
                      else
                        _MatchGrid(
                          matches: upcomingMatches,
                          competitionLabels: competitionLabels,
                          onPredict: (match) =>
                              context.push('/match/${match.id}'),
                          onPool: () => context.push('/pools/create'),
                        ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: ScoresPageSkeleton(),
                ),
                error: (error, stackTrace) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: StateView.error(
                    title: 'Could not load predictions',
                    subtitle: 'Pull to refresh and try again.',
                    onRetry: () =>
                        ref.invalidate(matchesByDateProvider(_today)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  OnboardingTeam? _resolveInsightTeam(Set<String> supportedIds) {
    for (final team in allTeams) {
      if (supportedIds.contains(team.id)) return team;
    }
    return null;
  }
}

class _MatchGrid extends StatelessWidget {
  const _MatchGrid({
    required this.matches,
    required this.competitionLabels,
    required this.onPredict,
    required this.onPool,
  });

  final List<MatchModel> matches;
  final Map<String, String> competitionLabels;
  final ValueChanged<MatchModel> onPredict;
  final VoidCallback onPool;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final columns = constraints.maxWidth >= 720 ? 2 : 1;
        final cardWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final match in matches)
              SizedBox(
                width: cardWidth,
                child: _HomeMatchCard(
                  match: match,
                  competitionLabel:
                      competitionLabels[match.competitionId] ??
                      match.competitionId.toUpperCase(),
                  onPredict: () => onPredict(match),
                  onPool: onPool,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HomeMatchCard extends StatelessWidget {
  const _HomeMatchCard({
    required this.match,
    required this.competitionLabel,
    required this.onPredict,
    required this.onPool,
  });

  final MatchModel match;
  final String competitionLabel;
  final VoidCallback onPredict;
  final VoidCallback onPool;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final surface = isDark ? FzColors.darkSurface : FzColors.lightSurface;
    final surface2 = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    const accent2 = FzColors.coral;
    final scoreText = match.isLive ? (match.scoreDisplay ?? 'LIVE') : 'VS';

    return Container(
      key: ValueKey('home-match-card-${match.id}'),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: FzRadii.cardRadius,
        border: Border.all(
          color: match.isLive
              ? FzColors.danger.withValues(alpha: 0.30)
              : border,
        ),
        boxShadow: [
          if (match.isLive)
            BoxShadow(
              color: FzColors.danger.withValues(alpha: 0.08),
              blurRadius: 24,
              spreadRadius: -10,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Stack(
        children: [
          if (match.isLive)
            Positioned(
              top: -40,
              right: 0,
              left: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    width: 192,
                    height: 192,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: FzColors.danger.withValues(alpha: 0.05),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FzBadge(
                          label: '$competitionLabel · ${match.kickoffLabel}',
                          variant: FzBadgeVariant.ghost,
                          fontSize: 9,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                      ),
                    ),
                    if (match.isLive) FzBadge.live(),
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: onPredict,
                  borderRadius: BorderRadius.circular(FzRadii.compact),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TeamColumn(
                            name: match.homeTeam,
                            logoUrl: match.homeLogoUrl,
                          ),
                        ),
                        SizedBox(
                          width: 72,
                          child: Center(
                            child: Text(
                              scoreText,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: match.isLive
                                    ? FzColors.danger
                                    : textColor,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: _TeamColumn(
                            name: match.awayTeam,
                            logoUrl: match.awayLogoUrl,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _HomeMatchButton(
                        label: 'PREDICT',
                        icon: LucideIcons.target,
                        backgroundColor: match.isLive
                            ? FzColors.danger
                            : accent2.withValues(alpha: 0.10),
                        foregroundColor: match.isLive
                            ? FzColors.darkBg
                            : accent2,
                        borderColor: match.isLive
                            ? FzColors.danger
                            : accent2.withValues(alpha: 0.20),
                        onTap: onPredict,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HomeMatchButton(
                        label: 'POOL',
                        icon: LucideIcons.swords,
                        backgroundColor: surface2,
                        foregroundColor: FzColors.primary,
                        borderColor: FzColors.primary.withValues(alpha: 0.20),
                        onTap: onPool,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn({required this.name, required this.logoUrl});

  final String name;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkText
        : FzColors.lightText;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TeamAvatar(name: name, logoUrl: logoUrl, size: 40),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

class _HomeMatchButton extends StatelessWidget {
  const _HomeMatchButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: foregroundColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: foregroundColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyInsightCard extends ConsumerWidget {
  const _DailyInsightCard({
    required this.muted,
    required this.teamId,
    required this.teamName,
  });

  final Color muted;
  final String teamId;
  final String? teamName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final teamNewsAsync = ref.watch(teamNewsProvider(teamId, limit: 1));

    return teamNewsAsync.when(
      data: (articles) {
        final article = articles.firstOrNull;
        final insight = _resolveInsightText(article);
        if (insight == null || insight.isEmpty) {
          return _InsightCardShell(
            muted: muted,
            child: _InsightMessage(
              title: 'Insights syncing',
              message:
                  'Club insights will appear here once the latest update lands.',
              muted: muted,
            ),
          );
        }

        return _InsightCardShell(
          muted: muted,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                insight,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, height: 1.38, color: textColor),
              ),
              const SizedBox(height: 8),
              Text(
                _sourceLabel(
                  teamName: teamName,
                  sourceName: article?.sourceName,
                ),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: muted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => _InsightCardShell(
        muted: muted,
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CupertinoActivityIndicator(
                color: FzColors.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Syncing Insights...',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: muted,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
      error: (_, _) => _InsightCardShell(
        muted: muted,
        child: _InsightMessage(
          title: 'Insights unavailable',
          message: 'We could not load the latest club signal right now.',
          muted: muted,
        ),
      ),
    );
  }

  String? _resolveInsightText(dynamic article) {
    if (article == null) return null;
    final summary = article.summary?.toString().trim();
    if (summary != null && summary.isNotEmpty) return summary;
    final content = article.content?.toString().trim();
    if (content != null && content.isNotEmpty) return content;
    final title = article.title?.toString().trim();
    if (title != null && title.isNotEmpty) return title;
    return null;
  }

  String _sourceLabel({String? teamName, String? sourceName}) {
    final club = teamName?.trim();
    final source = sourceName?.trim();
    if (club != null &&
        club.isNotEmpty &&
        source != null &&
        source.isNotEmpty) {
      return '$club · $source';
    }
    if (club != null && club.isNotEmpty) return club;
    return source ?? 'AI-curated club update';
  }
}

class _InsightMessage extends StatelessWidget {
  const _InsightMessage({
    required this.title,
    required this.message,
    required this.muted,
  });

  final String title;
  final String message;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: muted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: TextStyle(fontSize: 12, height: 1.38, color: textColor),
        ),
      ],
    );
  }
}

class _InsightCardShell extends StatelessWidget {
  const _InsightCardShell({required this.muted, required this.child});

  final Color muted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? FzColors.darkSurface : FzColors.lightSurface,
            isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
          ],
        ),
        borderRadius: FzRadii.cardRadius,
        border: Border.all(color: FzColors.success.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: FzColors.success.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 30,
            spreadRadius: -12,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -28,
            right: -18,
            child: IgnorePointer(
              child: Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FzColors.success.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: FzColors.success.withValues(alpha: 0.1),
                  borderRadius: FzRadii.fullRadius,
                  border: Border.all(
                    color: FzColors.success.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  LucideIcons.sparkles,
                  size: 16,
                  color: FzColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: child),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeSectionHeader extends StatelessWidget {
  const _HomeSectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkText
        : FzColors.lightText;

    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
        trailing,
      ],
    );
  }
}

class _CompactEmptyCard extends StatelessWidget {
  const _CompactEmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.muted,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: FzColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 18, color: FzColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: muted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasCustomBackground = backgroundColor != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: FzRadii.fullRadius,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color:
                backgroundColor ??
                (isDark ? FzColors.darkSurface2 : FzColors.lightSurface2),
            borderRadius: FzRadii.fullRadius,
            border: Border.all(
              color: hasCustomBackground
                  ? Colors.transparent
                  : (isDark ? FzColors.darkBorder : FzColors.lightBorder),
            ),
            boxShadow: hasCustomBackground
                ? [
                    BoxShadow(
                      color: backgroundColor!.withValues(alpha: 0.28),
                      blurRadius: 18,
                      spreadRadius: -8,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 18,
            color:
                foregroundColor ??
                (isDark ? FzColors.darkText : FzColors.lightText),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/config/platform_feature_access.dart';
import '../../../models/match_model.dart';
import '../../../providers/competitions_provider.dart';
import '../../../providers/home_feed_provider.dart';
import '../../../providers/matches_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_badge.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/match/match_list_widgets.dart';
import '../../../widgets/common/fz_shimmer.dart';
import '../../../widgets/home/fz_promo_banner.dart';

class HomeFeedScreen extends ConsumerWidget {
  const HomeFeedScreen({super.key});

  /// Prediction feed uses a 7-day forward window so upcoming matches always
  /// appear, even on days without scheduled fixtures.
  static const _feedWindowDays = 7;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    final featureAccess = ref.watch(platformFeatureAccessProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final homeBlocks = featureAccess.homeBlocks();
    final canOpenPredictions = featureAccess.isVisible(
      'predictions',
      surface: PlatformSurface.action,
    );
    final canOpenLeaderboard = featureAccess.isVisible(
      'leaderboard',
      surface: PlatformSurface.route,
    );

    // Fetch a 7-day window: today through today + 6 days
    final feedFilter = MatchesFilter(
      dateFrom: _today.toIso8601String(),
      dateTo: _today
          .add(const Duration(days: _feedWindowDays))
          .toIso8601String(),
      limit: 200,
      ascending: true,
    );
    final matchesAsync = ref.watch(homeFeedMatchesProvider(feedFilter));
    final competitions =
        ref.watch(competitionsProvider).valueOrNull ?? const [];
    final competitionLabels = {
      for (final competition in competitions)
        competition.id: competition.shortName.isNotEmpty
            ? competition.shortName
            : competition.name,
    };

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: FzColors.primary,
          onRefresh: () async {
            ref.invalidate(matchesProvider(feedFilter));
            ref.invalidate(homeFeedMatchesProvider(feedFilter));
            await ref.read(homeFeedMatchesProvider(feedFilter).future);
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, isDesktop ? 16 : 8, 16, 120),
            children: [
              if (isDesktop) ...[
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
                      tooltip: 'Open predict',
                      backgroundColor: FzColors.accent2,
                      foregroundColor: FzColors.darkBg,
                      icon: LucideIcons.target,
                      onTap: canOpenPredictions
                          ? () => context.go('/predict')
                          : () => context.go('/fixtures'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              matchesAsync.when(
                data: (selection) {
                  final liveMatches = selection.liveMatches;
                  final upcomingMatches = selection.upcomingMatches;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: homeBlocks
                        .map<Widget>((block) {
                          if (block.blockType == 'promo_banner') {
                            return FzPromoBanner(
                              key: ValueKey(block.blockKey),
                              badgeLabel:
                                  block.content['badge']?.toString() ??
                                  'DERBY DAY',
                              kickerLabel:
                                  block.content['kicker']?.toString() ??
                                  'GLOBAL',
                              title: block.title,
                              subtitle:
                                  block.content['subtitle']?.toString() ??
                                  'Fresh free picks are live now.',
                              ctaLabel:
                                  block.content['cta_label']?.toString() ??
                                  'OPEN',
                              ctaRoute: canOpenPredictions
                                  ? block.content['cta_route']?.toString() ??
                                        '/predict'
                                  : '/fixtures',
                            );
                          }

                          if (block.blockType == 'daily_insight') {
                            return _DailyInsightCard(
                              key: ValueKey(block.blockKey),
                              muted: muted,
                              subtitle:
                                  block.content['subtitle']?.toString() ??
                                  'Track live fixtures, lock free picks, and follow the leaderboard from one place.',
                            );
                          }

                          if (block.blockType == 'live_matches') {
                            return Column(
                              key: ValueKey(block.blockKey),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _HomeSectionHeader(
                                  icon: LucideIcons.activity,
                                  iconColor: FzColors.danger,
                                  title: block.title,
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
                                    title:
                                        block.content['empty_title']
                                            ?.toString() ??
                                        'No Live Matches',
                                    subtitle:
                                        block.content['empty_description']
                                            ?.toString() ??
                                        'Check upcoming.',
                                    muted: muted,
                                  )
                                else
                                  _MatchGrid(
                                    matches: liveMatches,
                                    competitionLabels: competitionLabels,
                                    onOpenMatch: (match) =>
                                        context.push('/match/${match.id}'),
                                    onOpenPredict: canOpenPredictions
                                        ? () => context.push('/predict')
                                        : null,
                                  ),
                                const SizedBox(height: 24),
                              ],
                            );
                          }

                          if (block.blockType == 'upcoming_matches') {
                            return Column(
                              key: ValueKey(block.blockKey),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _HomeSectionHeader(
                                  icon: LucideIcons.calendar,
                                  iconColor: muted,
                                  title: block.title,
                                  trailing: IconButton(
                                    onPressed: () => context.go(
                                      block.content['cta_route']?.toString() ??
                                          '/fixtures',
                                    ),
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
                                    title:
                                        block.content['empty_title']
                                            ?.toString() ??
                                        'No Upcoming',
                                    subtitle:
                                        block.content['empty_description']
                                            ?.toString() ??
                                        'None left.',
                                    muted: muted,
                                  )
                                else
                                  _MatchGrid(
                                    matches: upcomingMatches,
                                    competitionLabels: competitionLabels,
                                    onOpenMatch: (match) =>
                                        context.push('/match/${match.id}'),
                                    onOpenPredict: canOpenPredictions
                                        ? () => context.push('/predict')
                                        : null,
                                  ),
                                if (canOpenLeaderboard)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: TextButton.icon(
                                      onPressed: () =>
                                          context.push('/leaderboard'),
                                      icon: const Icon(
                                        LucideIcons.trophy,
                                        size: 14,
                                      ),
                                      label: const Text('Open leaderboard'),
                                    ),
                                  ),
                              ],
                            );
                          }

                          return const SizedBox.shrink();
                        })
                        .toList(growable: false),
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
                        ref.invalidate(homeFeedMatchesProvider(feedFilter)),
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

class _MatchGrid extends StatelessWidget {
  const _MatchGrid({
    required this.matches,
    required this.competitionLabels,
    required this.onOpenMatch,
    required this.onOpenPredict,
  });

  final List<MatchModel> matches;
  final Map<String, String> competitionLabels;
  final ValueChanged<MatchModel> onOpenMatch;
  final VoidCallback? onOpenPredict;

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
                  onOpenMatch: () => onOpenMatch(match),
                  onOpenPredict: onOpenPredict,
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
    required this.onOpenMatch,
    required this.onOpenPredict,
  });

  final MatchModel match;
  final String competitionLabel;
  final VoidCallback onOpenMatch;
  final VoidCallback? onOpenPredict;

  /// Builds the badge label: "COMPETITION · 21:30" for today,
  /// "COMPETITION · TOMORROW" for tomorrow, "COMPETITION · Sat 15:00" for later.
  String get _badgeLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final matchDay = DateTime(
      match.date.year,
      match.date.month,
      match.date.day,
    );
    final time = match.kickoffTimeLocalLabel;

    if (match.isLive) return '$competitionLabel · LIVE';
    if (match.isFinished) return '$competitionLabel · FT';

    if (matchDay == today) {
      return '$competitionLabel · $time';
    } else if (matchDay == tomorrow) {
      return '$competitionLabel · TOMORROW';
    } else {
      final dayName = _shortDayName(matchDay.weekday);
      return '$competitionLabel · $dayName $time';
    }
  }

  static String _shortDayName(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(weekday - 1) % 7];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final surface = isDark ? FzColors.darkSurface : FzColors.lightSurface;
    final surface2 = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    const ctaColor = FzColors.accent2;
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
                          label: _badgeLabel,
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
                  onTap: onOpenMatch,
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
                    if (onOpenPredict != null) ...[
                      Expanded(
                        child: _HomeMatchButton(
                          label: 'PREDICT',
                          icon: LucideIcons.target,
                          backgroundColor: match.isLive
                              ? FzColors.danger
                              : ctaColor,
                          foregroundColor: match.isLive
                              ? FzColors.darkBg
                              : FzColors.darkText,
                          borderColor: match.isLive
                              ? FzColors.danger
                              : ctaColor,
                          onTap: onOpenPredict!,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: _HomeMatchButton(
                        label: 'MATCH',
                        icon: LucideIcons.lineChart,
                        backgroundColor: surface2,
                        foregroundColor: FzColors.accent,
                        borderColor: FzColors.accent.withValues(alpha: 0.20),
                        onTap: onOpenMatch,
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

class _DailyInsightCard extends StatelessWidget {
  const _DailyInsightCard({
    super.key,
    required this.muted,
    required this.subtitle,
  });

  final Color muted;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: _InsightCardShell(
        muted: muted,
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: Center(
                child: CupertinoActivityIndicator(color: FzColors.success),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, height: 1.38, color: textColor),
              ),
            ),
          ],
        ),
      ),
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
                    fontSize: 14,
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
    return Semantics(
      button: true,
      label: tooltip,
      onTap: onTap,
      child: ExcludeSemantics(
        child: IconButton(
          onPressed: onTap,
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          style: IconButton.styleFrom(
            backgroundColor:
                backgroundColor ??
                (isDark ? FzColors.darkSurface2 : FzColors.lightSurface2),
            foregroundColor:
                foregroundColor ??
                (isDark ? FzColors.darkText : FzColors.lightText),
            shape: const RoundedRectangleBorder(
              borderRadius: FzRadii.fullRadius,
            ),
            side: BorderSide(
              color: hasCustomBackground
                  ? Colors.transparent
                  : (isDark ? FzColors.darkBorder : FzColors.lightBorder),
            ),
            shadowColor: hasCustomBackground
                ? backgroundColor!.withValues(alpha: 0.28)
                : null,
            elevation: hasCustomBackground ? 6 : 0,
          ),
          icon: Icon(icon, size: 18),
        ),
      ),
    );
  }
}

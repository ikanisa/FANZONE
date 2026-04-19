import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/market/launch_market.dart';
import '../../../models/featured_event_model.dart';
import '../../../models/global_challenge_model.dart';
import '../../../providers/featured_events_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import 'package:go_router/go_router.dart';
import '../../../widgets/common/fz_shimmer.dart';

/// Screen for a featured event (World Cup, UCL Final, etc.).
///
/// Sections:
/// - Event banner header
/// - Event matches
/// - Event challenges (if enabled)
/// - Event leaderboard CTA
class EventHubScreen extends ConsumerWidget {
  const EventHubScreen({super.key, required this.eventTag});

  final String eventTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    final eventAsync = ref.watch(featuredEventByTagProvider(eventTag));
    final challengesAsync = ref.watch(globalChallengesProvider(eventTag));

    return Scaffold(
      body: SafeArea(
        child: eventAsync.when(
          data: (event) {
            if (event == null) {
              return StateView.error(
                title: 'Event not found',
                subtitle: 'This event may have ended or been removed.',
              );
            }
            return _EventContent(
              event: event,
              challengesAsync: challengesAsync,
              muted: muted,
              isDark: isDark,
              showGlobalChallenges: ref.watch(featureFlagsProvider).globalChallenges,
            );
          },
          loading: () => const ScoresPageSkeleton(),
          error: (error, _) => StateView.error(
            title: 'Could not load event',
            onRetry: () => ref.invalidate(featuredEventByTagProvider(eventTag)),
          ),
        ),
      ),
    );
  }
}

class _EventContent extends StatelessWidget {
  const _EventContent({
    required this.event,
    required this.challengesAsync,
    required this.muted,
    required this.isDark,
    required this.showGlobalChallenges,
  });

  final FeaturedEventModel event;
  final AsyncValue<List<GlobalChallengeModel>> challengesAsync;
  final Color muted;
  final bool isDark;
  final bool showGlobalChallenges;

  @override
  Widget build(BuildContext context) {
    final bannerColor = _parseBannerColor(event.bannerColor);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        // Back button + title
        Row(
          children: [
            IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: Text(
                event.shortName,
                style: FzTypography.display(
                  size: 24,
                  color: isDark ? FzColors.darkText : FzColors.lightText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Event hero card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                bannerColor.withValues(alpha: 0.85),
                bannerColor.withValues(alpha: 0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Region pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  launchRegionLabel(event.region).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                event.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              if (event.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  event.description!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Date range
              Row(
                children: [
                  Icon(
                    LucideIcons.calendar,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDateRange(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Event Challenges section
        if (showGlobalChallenges) ...[
          _SectionHeader(title: 'EVENT CHALLENGES', isDark: isDark),
          const SizedBox(height: 10),
          challengesAsync.when(
            data: (challenges) {
              if (challenges.isEmpty) {
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
                          'No challenges available yet for this event. Check back closer to match day.',
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
              return Column(
                children: challenges
                    .take(5)
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ChallengeCard(challenge: c, isDark: isDark),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: const ScoresPageSkeleton(),
            ),
            error: (_, _) =>
                StateView.error(title: 'Could not load challenges'),
          ),
          const SizedBox(height: 24),
        ],

        // Event Info card
        FzCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    LucideIcons.info,
                    size: 18,
                    color: FzColors.accent,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'About This Event',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? FzColors.darkText : FzColors.lightText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Predictions, pools, and challenges for this event will appear here once matches are scheduled. Follow your favorite teams to get notified.',
                style: TextStyle(fontSize: 12, color: muted, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDateRange() {
    final start = event.startDate;
    final end = event.endDate;
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[start.month - 1]} ${start.day}, ${start.year} – '
        '${months[end.month - 1]} ${end.day}, ${end.year}';
  }

  Color _parseBannerColor(String? hex) {
    if (hex == null || hex.isEmpty) return FzColors.accent;
    try {
      final cleaned = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return FzColors.accent;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.isDark});

  final String title;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: FzTypography.sectionLabel(
        isDark ? Brightness.dark : Brightness.light,
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.challenge, required this.isDark});

  final GlobalChallengeModel challenge;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    return FzCard(
      padding: const EdgeInsets.all(16),
      borderColor: FzColors.accent.withValues(alpha: 0.2),
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
                  challenge.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (challenge.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    challenge.description!,
                    style: TextStyle(fontSize: 12, color: muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    if (challenge.entryFeeFet > 0)
                      _Chip('${challenge.entryFeeFet} FET entry', isDark),
                    _Chip('${challenge.currentParticipants} joined', isDark),
                    _Chip(challenge.status.toUpperCase(), isDark),
                  ],
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight, size: 18),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.isDark);

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

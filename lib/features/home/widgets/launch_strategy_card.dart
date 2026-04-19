import 'package:flutter/material.dart';

import '../../../core/market/launch_market.dart';
import '../../../models/featured_event_model.dart';
import '../../../theme/colors.dart';
import '../../../widgets/common/fz_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Launch strategy card showing the user's regional priority and top moments.
class LaunchStrategyCard extends StatelessWidget {
  const LaunchStrategyCard({
    super.key,
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
                  Icons.public_rounded,
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

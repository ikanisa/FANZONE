import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/feature_flags.dart';
import '../../core/market/launch_market.dart';
import '../../models/featured_event_model.dart';
import '../../providers/market_preferences_provider.dart';
import '../../theme/colors.dart';
import '../common/fz_card.dart';

/// Animated banner for displaying active featured events.
///
/// Shows the topmost active event with a gradient background,
/// countdown, and tap-through to the event hub.
class FeaturedEventBanner extends ConsumerWidget {
  const FeaturedEventBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(featureFlagsProvider).featuredEvents) return const SizedBox.shrink();

    final eventsAsync = ref.watch(homeLaunchEventsProvider);
    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) return const SizedBox.shrink();
        final event = events.first;
        return _FeaturedBannerCard(event: event);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const FzCard(
        padding: EdgeInsets.all(14),
        child: Text('Featured event unavailable right now.'),
      ),
    );
  }
}

class _FeaturedBannerCard extends StatelessWidget {
  const _FeaturedBannerCard({required this.event});

  final FeaturedEventModel event;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bannerColor = _parseBannerColor(event.bannerColor);
    final daysText = _buildCountdownText();

    return GestureDetector(
      onTap: () => context.push('/event/${event.eventTag}'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              bannerColor.withValues(alpha: 0.9),
              bannerColor.withValues(alpha: 0.6),
              isDark
                  ? FzColors.darkSurface2.withValues(alpha: 0.8)
                  : FzColors.lightSurface2.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: bannerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Event icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(_eventEmoji, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 14),
            // Event info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Region badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      launchRegionLabel(event.region).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    event.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    daysText,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Arrow
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildCountdownText() {
    final now = DateTime.now();
    if (now.isBefore(event.startDate)) {
      final days = event.daysUntilStart;
      if (days <= 0) return 'Starting today!';
      if (days == 1) return 'Starts tomorrow';
      return 'Starts in $days days';
    } else {
      final remaining = event.daysRemaining;
      if (remaining <= 0) return 'Final day!';
      if (remaining == 1) return '1 day remaining';
      return '$remaining days remaining';
    }
  }

  Color _parseBannerColor(String? hex) {
    if (hex == null || hex.isEmpty) return FzColors.primary;
    try {
      final cleaned = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return FzColors.primary;
    }
  }

  String get _eventEmoji {
    final tag = event.eventTag.toLowerCase();
    if (tag.contains('worldcup') || tag.contains('world')) return '🏆';
    if (tag.contains('ucl') || tag.contains('champions')) return '⭐';
    if (tag.contains('afcon') || tag.contains('africa')) return '🌍';
    if (tag.contains('copa')) return '🏅';
    if (tag.contains('gold')) return '🥇';
    if (tag.contains('caf')) return '🌍';
    return '⚽';
  }
}

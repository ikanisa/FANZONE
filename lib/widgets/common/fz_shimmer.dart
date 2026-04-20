import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/colors.dart';

/// Shimmer loading placeholder — matches the layout of real content.
class FzShimmer extends StatelessWidget {
  const FzShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
      highlightColor: isDark ? FzColors.darkSurface3 : FzColors.lightSurface3,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Skeleton for a single compact score row (~56px).
class MatchRowSkeleton extends StatelessWidget {
  const MatchRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Score/time column
          const FzShimmer(width: 36, height: 14, borderRadius: 4),
          const SizedBox(width: 16),
          // Teams column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const FzShimmer(width: 18, height: 18, borderRadius: 9),
                    const SizedBox(width: 8),
                    FzShimmer(
                      width: 100 + (hashCode % 40).toDouble(),
                      height: 12,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const FzShimmer(width: 18, height: 18, borderRadius: 9),
                    const SizedBox(width: 8),
                    FzShimmer(
                      width: 90 + (hashCode % 30).toDouble(),
                      height: 12,
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

/// Skeleton for a group of matches with a league header.
class FixtureGroupSkeleton extends StatelessWidget {
  const FixtureGroupSkeleton({super.key, this.count = 4});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16, bottom: 8),
          child: FzShimmer(width: 100, height: 10, borderRadius: 4),
        ),
        ...List.generate(count, (_) => const MatchRowSkeleton()),
      ],
    );
  }
}

/// Full-page loading skeleton for scores screen.
class ScoresPageSkeleton extends StatelessWidget {
  const ScoresPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 16),
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        FixtureGroupSkeleton(count: 3),
        SizedBox(height: 20),
        FixtureGroupSkeleton(count: 5),
        SizedBox(height: 20),
        FixtureGroupSkeleton(count: 2),
      ],
    );
  }
}

part of '../../screens/match_detail_screen.dart';

/// Crowd prediction distribution bar.
///
/// Shows the percentage of users predicting Home / Draw / Away
/// for the current match. Follows the reference MarketGroup card
/// pattern (bg-surface2, rounded-2xl, border-border).
class _CrowdPredictionBar extends ConsumerWidget {
  const _CrowdPredictionBar({required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    final crowdAsync = ref.watch(crowdPredictionProvider(matchId));

    return crowdAsync.when(
      loading: () => _buildBar(
        surface: surface,
        border: border,
        textColor: textColor,
        muted: muted,
        homePercent: 34,
        drawPercent: 33,
        awayPercent: 33,
        totalVotes: 0,
        isLoading: true,
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (crowd) {
        if (crowd == null || crowd.total == 0) {
          return _buildBar(
            surface: surface,
            border: border,
            textColor: textColor,
            muted: muted,
            homePercent: 34,
            drawPercent: 33,
            awayPercent: 33,
            totalVotes: 0,
            isLoading: false,
          );
        }

        final (h, d, a) = crowd.normalized;
        return _buildBar(
          surface: surface,
          border: border,
          textColor: textColor,
          muted: muted,
          homePercent: h,
          drawPercent: d,
          awayPercent: a,
          totalVotes: crowd.total,
          isLoading: false,
        );
      },
    );
  }

  Widget _buildBar({
    required Color surface,
    required Color border,
    required Color textColor,
    required Color muted,
    required int homePercent,
    required int drawPercent,
    required int awayPercent,
    required int totalVotes,
    required bool isLoading,
  }) {
    return AnimatedOpacity(
      opacity: isLoading ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'CROWD PREDICTION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: muted,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                if (totalVotes > 0)
                  Text(
                    '$totalVotes votes',
                    style: TextStyle(
                      fontSize: 9,
                      color: muted.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Distribution bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Expanded(
                      flex: homePercent.clamp(1, 98),
                      child: Container(color: FzColors.accent),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      flex: drawPercent.clamp(1, 98),
                      child: Container(color: FzColors.coral),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      flex: awayPercent.clamp(1, 98),
                      child: Container(color: FzColors.blue),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Labels
            Row(
              children: [
                _CrowdLabel(
                  color: FzColors.accent,
                  label: 'HOME',
                  percent: homePercent,
                  textColor: textColor,
                  muted: muted,
                ),
                const Spacer(),
                _CrowdLabel(
                  color: FzColors.coral,
                  label: 'DRAW',
                  percent: drawPercent,
                  textColor: textColor,
                  muted: muted,
                ),
                const Spacer(),
                _CrowdLabel(
                  color: FzColors.blue,
                  label: 'AWAY',
                  percent: awayPercent,
                  textColor: textColor,
                  muted: muted,
                  alignEnd: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CrowdLabel extends StatelessWidget {
  const _CrowdLabel({
    required this.color,
    required this.label,
    required this.percent,
    required this.textColor,
    required this.muted,
    this.alignEnd = false,
  });

  final Color color;
  final String label;
  final int percent;
  final Color textColor;
  final Color muted;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: muted,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '$percent%',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
            color: textColor,
          ),
        ),
      ],
    );
  }
}

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

    // TODO: Replace with actual crowd prediction data from Supabase aggregate
    // For now, simulate realistic distribution
    const homePercent = 42;
    const drawPercent = 26;
    const awayPercent = 32;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 14),

          // Distribution bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: homePercent,
                    child: Container(color: FzColors.accent),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: drawPercent,
                    child: Container(color: FzColors.coral),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: awayPercent,
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

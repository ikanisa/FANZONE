part of '../../screens/match_detail_screen.dart';

class _BasicStatsView extends StatelessWidget {
  const _BasicStatsView({
    required this.match,
    required this.isDark,
    required this.muted,
    required this.totalHome,
    required this.totalAway,
  });

  final MatchModel match;
  final bool isDark;
  final Color muted;
  final int totalHome;
  final int totalAway;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Match Statistics',
          style: FzTypography.sectionLabel(Theme.of(context).brightness),
        ),
        const SizedBox(height: 12),
        FzCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _DualStatBar(
                label: 'Goals',
                leftValue: totalHome.toDouble(),
                rightValue: totalAway.toDouble(),
                leftLabel: '$totalHome',
                rightLabel: '$totalAway',
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              _DualStatBar(
                label: 'Half-Time',
                leftValue: (match.htHome ?? 0).toDouble(),
                rightValue: (match.htAway ?? 0).toDouble(),
                leftLabel: '${match.htHome ?? 0}',
                rightLabel: '${match.htAway ?? 0}',
                isDark: isDark,
              ),
              if (match.etHome != null) ...[
                const SizedBox(height: 16),
                _DualStatBar(
                  label: 'Extra Time',
                  leftValue: match.etHome!.toDouble(),
                  rightValue: (match.etAway ?? 0).toDouble(),
                  leftLabel: '${match.etHome}',
                  rightLabel: '${match.etAway ?? 0}',
                  isDark: isDark,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        FzCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Match Info',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: muted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              _InfoRow(label: 'Season', value: match.season, muted: muted),
              _InfoRow(label: 'Source', value: match.dataSource, muted: muted),
              if (match.venue != null)
                _InfoRow(label: 'Venue', value: match.venue!, muted: muted),
            ],
          ),
        ),
      ],
    );
  }
}

class _PossessionRingPainter extends CustomPainter {
  _PossessionRingPainter({required this.homePercent, required this.isDark});

  final int homePercent;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 8.0;
    final bgPaint = Paint()
      ..color = isDark ? FzColors.darkBorder : FzColors.lightBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final homePaint = Paint()
      ..color = FzColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    final sweepAngle = (homePercent / 100) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      homePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PossessionRingPainter oldDelegate) =>
      oldDelegate.homePercent != homePercent || oldDelegate.isDark != isDark;
}

class _DualStatBar extends StatelessWidget {
  const _DualStatBar({
    required this.label,
    required this.leftValue,
    required this.rightValue,
    required this.leftLabel,
    required this.rightLabel,
    required this.isDark,
  });

  final String label;
  final double leftValue;
  final double rightValue;
  final String leftLabel;
  final String rightLabel;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final total = leftValue + rightValue;
    final leftFraction = total > 0 ? leftValue / total : 0.5;
    final rightFraction = total > 0 ? rightValue / total : 0.5;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final leftWins = leftValue > rightValue;
    final rightWins = rightValue > leftValue;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              leftLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: leftWins
                    ? FzColors.primary
                    : (isDark ? FzColors.darkText : FzColors.lightText),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
            Text(
              rightLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: rightWins
                    ? FzColors.primary
                    : (isDark ? FzColors.darkText : FzColors.lightText),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              flex: (leftFraction * 100).round().clamp(5, 95),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: leftWins
                      ? FzColors.primary
                      : muted.withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(3),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              flex: (rightFraction * 100).round().clamp(5, 95),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: rightWins
                      ? FzColors.primary
                      : muted.withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.muted,
  });

  final String label;
  final String value;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: muted)),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

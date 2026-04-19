import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../services/daily_challenge_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';

/// Prediction history screen — shows the user's past predictions,
/// accuracy stats, and daily challenge history.
///
/// Design follows reference Profile.tsx patterns: sections with bold
/// headers, surface2 cards, muted labels, monospace FET amounts.
class PredictionHistoryScreen extends ConsumerWidget {
  const PredictionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final historyAsync = ref.watch(dailyChallengeHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'PREDICTION HISTORY',
          style: FzTypography.display(size: 20, color: textColor),
        ),
        centerTitle: true,
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => StateView.error(
          title: 'Cannot load history',
          subtitle: e.toString(),
          onRetry: () => ref.invalidate(dailyChallengeHistoryProvider),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return StateView.empty(
              title: 'No Predictions Yet',
              subtitle: 'Your prediction history will appear here.',
              icon: LucideIcons.target,
            );
          }

          // Calculate stats
          final total = entries.length;
          final correct = entries
              .where(
                (e) =>
                    e.result == 'correct_result' || e.result == 'exact_score',
              )
              .length;
          final exactScores =
              entries.where((e) => e.result == 'exact_score').length;
          final accuracy = total > 0 ? (correct / total * 100).round() : 0;
          final totalFet =
              entries.fold<int>(0, (sum, e) => sum + e.payoutFet);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              // Stats grid
              _StatsGrid(
                total: total,
                correct: correct,
                exactScores: exactScores,
                accuracy: accuracy,
                totalFet: totalFet,
                isDark: isDark,
                textColor: textColor,
                muted: muted,
              ),
              const SizedBox(height: 24),

              // History list
              Text(
                'Recent',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              ...entries.take(50).map(
                    (entry) => _HistoryRow(
                      entry: entry,
                      isDark: isDark,
                      textColor: textColor,
                      muted: muted,
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.total,
    required this.correct,
    required this.exactScores,
    required this.accuracy,
    required this.totalFet,
    required this.isDark,
    required this.textColor,
    required this.muted,
  });

  final int total;
  final int correct;
  final int exactScores;
  final int accuracy;
  final int totalFet;
  final bool isDark;
  final Color textColor;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'TOTAL',
                  value: '$total',
                  color: textColor,
                  muted: muted,
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'CORRECT',
                  value: '$correct',
                  color: FzColors.success,
                  muted: muted,
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'ACCURACY',
                  value: '$accuracy%',
                  color: FzColors.accent,
                  muted: muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'EXACT SCORE',
                  value: '$exactScores',
                  color: FzColors.coral,
                  muted: muted,
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'FET EARNED',
                  value: '+$totalFet',
                  color: FzColors.success,
                  muted: muted,
                  isMono: true,
                ),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.muted,
    this.isMono = false,
  });

  final String label;
  final String value;
  final Color color;
  final Color muted;
  final bool isMono;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: muted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: isMono ? 'monospace' : null,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.entry,
    required this.isDark,
    required this.textColor,
    required this.muted,
  });

  final dynamic entry;
  final bool isDark;
  final Color textColor;
  final Color muted;

  Color _resultColor(String result) {
    switch (result) {
      case 'exact_score':
        return FzColors.coral;
      case 'correct_result':
        return FzColors.success;
      case 'wrong':
        return FzColors.danger;
      default:
        return muted;
    }
  }

  String _resultLabel(String result) {
    switch (result) {
      case 'exact_score':
        return '🎯 EXACT';
      case 'correct_result':
        return '✅ CORRECT';
      case 'wrong':
        return '❌ WRONG';
      default:
        return '⏳ PENDING';
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface2 = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final resultColor = _resultColor(entry.result);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface2,
        borderRadius: FzRadii.cardRadius,
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: resultColor.withValues(alpha: 0.1),
              borderRadius: FzRadii.fullRadius,
              border: Border.all(
                color: resultColor.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(
              LucideIcons.target,
              size: 16,
              color: resultColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.predictedHomeScore} - ${entry.predictedAwayScore}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _resultLabel(entry.result),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: resultColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          if (entry.payoutFet > 0)
            Text(
              '+${entry.payoutFet} FET',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                color: FzColors.success,
              ),
            ),
        ],
      ),
    );
  }
}

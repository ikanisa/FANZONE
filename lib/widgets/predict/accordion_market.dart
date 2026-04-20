import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/match_model.dart';
import '../../providers/matches_provider.dart';
import '../../providers/prediction_slip_provider.dart';
import '../../theme/colors.dart';

class MatchResultMarket extends ConsumerWidget {
  const MatchResultMarket({super.key, required this.match});
  final MatchModel match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (match.isFinished) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? FzColors.darkSurface : FzColors.lightSurface;
    final text = isDark ? FzColors.darkText : FzColors.lightText;
    final oddsAsync = ref.watch(matchOddsProvider(match.id));
    final odds = oddsAsync.valueOrNull;

    final selections = ref.watch(predictionSlipProvider);
    final isHomeSelected = selections.any(
      (s) =>
          s.match.id == match.id &&
          s.type == PredictionType.matchResult &&
          s.selection == '1',
    );
    final isDrawSelected = selections.any(
      (s) =>
          s.match.id == match.id &&
          s.type == PredictionType.matchResult &&
          s.selection == 'X',
    );
    final isAwaySelected = selections.any(
      (s) =>
          s.match.id == match.id &&
          s.type == PredictionType.matchResult &&
          s.selection == '2',
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          'Match Result (1X2)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: text,
          ),
        ),
        subtitle: const Text(
          'Predict the outcome after 90 mins',
          style: TextStyle(fontSize: 12, color: FzColors.lightMuted),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _MarketButton(
                    label: '1',
                    secondaryLabel: match.homeTeam,
                    oddsLabel: _formatOdds(odds?.homeMultiplier),
                    isSelected: isHomeSelected,
                    onTap: () => ref
                        .read(predictionSlipProvider.notifier)
                        .toggleMatchResult(
                          match,
                          '1',
                          multiplier: odds?.multiplierForSelection('1'),
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MarketButton(
                    label: 'X',
                    secondaryLabel: 'Draw',
                    oddsLabel: _formatOdds(odds?.drawMultiplier),
                    isSelected: isDrawSelected,
                    onTap: () => ref
                        .read(predictionSlipProvider.notifier)
                        .toggleMatchResult(
                          match,
                          'X',
                          multiplier: odds?.multiplierForSelection('X'),
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MarketButton(
                    label: '2',
                    secondaryLabel: match.awayTeam,
                    oddsLabel: _formatOdds(odds?.awayMultiplier),
                    isSelected: isAwaySelected,
                    onTap: () => ref
                        .read(predictionSlipProvider.notifier)
                        .toggleMatchResult(
                          match,
                          '2',
                          multiplier: odds?.multiplierForSelection('2'),
                        ),
                  ),
                ),
              ],
            ),
          ),
          if (oddsAsync.isLoading)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Loading live multipliers…',
                  style: TextStyle(fontSize: 11, color: FzColors.lightMuted),
                ),
              ),
            )
          else if (odds == null)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Live multipliers unavailable. You can still save the pick.',
                  style: TextStyle(fontSize: 11, color: FzColors.lightMuted),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String? _formatOdds(double? value) {
    if (value == null || value <= 0) return null;
    return 'x${value.toStringAsFixed(2)}';
  }
}

class CorrectScoreMarket extends ConsumerStatefulWidget {
  const CorrectScoreMarket({super.key, required this.match});
  final MatchModel match;

  @override
  ConsumerState<CorrectScoreMarket> createState() => _CorrectScoreMarketState();
}

class _CorrectScoreMarketState extends ConsumerState<CorrectScoreMarket> {
  int _home = 0;
  int _away = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.match.isFinished) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? FzColors.darkSurface : FzColors.lightSurface;
    final text = isDark ? FzColors.darkText : FzColors.lightText;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;

    final selections = ref.watch(predictionSlipProvider);
    final isSelected = selections.any(
      (s) =>
          s.match.id == widget.match.id &&
          s.type == PredictionType.exactScore &&
          s.selection == '$_home-$_away',
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: ExpansionTile(
        title: Text(
          'Correct Score',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: text,
          ),
        ),
        subtitle: const Text(
          'Predict the exact goals scored',
          style: TextStyle(fontSize: 12, color: FzColors.lightMuted),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ScoreStepper(
                      teamName: widget.match.homeTeam,
                      value: _home,
                      onChanged: (val) => setState(() => _home = val),
                    ),
                    const Text(
                      'vs',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: FzColors.primary,
                      ),
                    ),
                    _ScoreStepper(
                      teamName: widget.match.awayTeam,
                      value: _away,
                      onChanged: (val) => setState(() => _away = val),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => ref
                        .read(predictionSlipProvider.notifier)
                        .toggleExactScore(widget.match, _home, _away),
                    style: FilledButton.styleFrom(
                      backgroundColor: isSelected
                          ? FzColors.danger
                          : (isDark
                                ? FzColors.darkSurface3
                                : FzColors.lightSurface3),
                      foregroundColor: isSelected ? Colors.white : text,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      isSelected
                          ? 'Remove from Slip'
                          : 'Add Exact Score $_home-$_away',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Exact-score multipliers are not live yet. This pick will save without projected points.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? FzColors.darkMuted : FzColors.lightMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketButton extends StatelessWidget {
  const _MarketButton({
    required this.label,
    required this.secondaryLabel,
    required this.isSelected,
    required this.onTap,
    this.oddsLabel,
  });

  final String label;
  final String secondaryLabel;
  final bool isSelected;
  final VoidCallback onTap;
  final String? oddsLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isSelected
        ? FzColors.danger
        : (isDark ? FzColors.darkSurface2 : FzColors.lightSurface2);
    final textColor = isSelected
        ? Colors.white
        : (isDark ? FzColors.darkText : FzColors.lightText);
    final secondaryColor = isSelected
        ? Colors.white.withValues(alpha: 0.8)
        : (isDark ? FzColors.darkMuted : FzColors.lightMuted);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? FzColors.danger
                : (isDark ? FzColors.darkBorder : FzColors.lightBorder),
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              secondaryLabel,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: secondaryColor,
              ),
            ),
            if (oddsLabel != null) ...[
              const SizedBox(height: 6),
              Text(
                oddsLabel!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : FzColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScoreStepper extends StatelessWidget {
  const _ScoreStepper({
    required this.teamName,
    required this.value,
    required this.onChanged,
  });

  final String teamName;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? FzColors.darkText : FzColors.lightText;
    final btnBg = isDark ? FzColors.darkSurface3 : FzColors.lightSurface2;

    return Column(
      children: [
        Text(
          teamName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () {
                if (value > 0) onChanged(value - 1);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: btnBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.remove, size: 20, color: iconColor),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              '$value',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 16),
            InkWell(
              onTap: () => onChanged(value + 1),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: btnBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add, size: 20, color: iconColor),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

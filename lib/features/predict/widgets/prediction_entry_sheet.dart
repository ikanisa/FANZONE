import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/match_model.dart';
import '../../../models/prediction_engine_output_model.dart';
import '../../../models/user_prediction_model.dart';
import '../data/prediction_hub_gateway.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/crowd_prediction_provider.dart';
import '../../../services/prediction_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../auth/widgets/sign_in_required_sheet.dart';

Future<void> showPredictionEntrySheet(
  BuildContext context, {
  required MatchModel match,
  PredictionEngineOutputModel? engineOutput,
  UserPredictionModel? existingPrediction,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: PredictionEntrySheet(
        match: match,
        engineOutput: engineOutput,
        existingPrediction: existingPrediction,
      ),
    ),
  );
}

class PredictionEntrySheet extends ConsumerStatefulWidget {
  const PredictionEntrySheet({
    super.key,
    required this.match,
    this.engineOutput,
    this.existingPrediction,
  });

  final MatchModel match;
  final PredictionEngineOutputModel? engineOutput;
  final UserPredictionModel? existingPrediction;

  @override
  ConsumerState<PredictionEntrySheet> createState() =>
      _PredictionEntrySheetState();
}

class _PredictionEntrySheetState extends ConsumerState<PredictionEntrySheet> {
  late String? _resultCode;
  late bool _over25;
  late bool _btts;
  late int _homeGoals;
  late int _awayGoals;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingPrediction;
    _resultCode =
        existing?.predictedResultCode ?? widget.engineOutput?.topResultCode;
    _over25 = existing?.predictedOver25 ?? false;
    _btts = existing?.predictedBtts ?? false;
    _homeGoals =
        existing?.predictedHomeGoals ??
        widget.engineOutput?.predictedHomeGoals ??
        1;
    _awayGoals =
        existing?.predictedAwayGoals ??
        widget.engineOutput?.predictedAwayGoals ??
        0;
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final isSignedIn = ref.read(isFullyAuthenticatedProvider);
    if (!isSignedIn) {
      await showSignInRequiredSheet(
        context,
        title: 'Sign in to save your pick',
        message:
            'Create a free account to lock predictions, earn rewards, and track your record.',
        from: '/predict',
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await ref
          .read(predictionServiceProvider)
          .submitPrediction(
            PredictionSubmissionRequest(
              matchId: widget.match.id,
              predictedResultCode: _resultCode,
              predictedOver25: _over25,
              predictedBtts: _btts,
              predictedHomeGoals: _homeGoals,
              predictedAwayGoals: _awayGoals,
            ),
          );

      ref.invalidate(myPredictionsProvider);
      ref.invalidate(myPredictionForMatchProvider(widget.match.id));
      ref.invalidate(crowdPredictionProvider(widget.match.id));

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prediction saved.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save prediction: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkMuted
        : FzColors.lightMuted;
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkText
        : FzColors.lightText;
    final sheetColor = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkSurface
        : FzColors.lightSurface;

    return Container(
      decoration: BoxDecoration(
        color: sheetColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: FzColors.darkBorder),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: FzColors.darkBorder,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Your Pick',
              style: FzTypography.display(
                size: 28,
                color: textColor,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.match.homeTeam} vs ${widget.match.awayTeam}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 18),
            Text('RESULT', style: FzTypography.metaLabel(color: muted)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ResultChip(
                    label: widget.match.homeTeam,
                    shortLabel: 'Home',
                    selected: _resultCode == 'H',
                    onTap: () => setState(() => _resultCode = 'H'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ResultChip(
                    label: 'Draw',
                    shortLabel: 'Draw',
                    selected: _resultCode == 'D',
                    onTap: () => setState(() => _resultCode = 'D'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ResultChip(
                    label: widget.match.awayTeam,
                    shortLabel: 'Away',
                    selected: _resultCode == 'A',
                    onTap: () => setState(() => _resultCode = 'A'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FzCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _ToggleRow(
                    label: 'Over 2.5 goals',
                    value: _over25,
                    onChanged: (value) => setState(() => _over25 = value),
                  ),
                  const Divider(color: FzColors.darkBorder, height: 20),
                  _ToggleRow(
                    label: 'Both teams to score',
                    value: _btts,
                    onChanged: (value) => setState(() => _btts = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('SCORELINE', style: FzTypography.metaLabel(color: muted)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _GoalStepper(
                    label: widget.match.homeTeam,
                    value: _homeGoals,
                    onChanged: (value) => setState(() => _homeGoals = value),
                  ),
                ),
                const SizedBox(width: 12),
                Text(':', style: FzTypography.scoreLarge(color: muted)),
                const SizedBox(width: 12),
                Expanded(
                  child: _GoalStepper(
                    label: widget.match.awayTeam,
                    value: _awayGoals,
                    onChanged: (value) => setState(() => _awayGoals = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FzColors.accent2,
                  foregroundColor: FzColors.darkText,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _submitting ? 'Saving...' : 'Save prediction',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({
    required this.label,
    required this.shortLabel,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String shortLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? FzColors.accent2 : FzColors.darkSurface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? FzColors.accent2 : FzColors.darkBorder,
          ),
        ),
        child: Column(
          children: [
            Text(
              shortLabel.toUpperCase(),
              style: FzTypography.metaLabel(
                color: selected ? FzColors.darkBg : FzColors.darkMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? FzColors.darkBg : FzColors.darkText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: FzColors.darkText,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: FzColors.accent,
        ),
      ],
    );
  }
}

class _GoalStepper extends StatelessWidget {
  const _GoalStepper({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: FzColors.darkText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: FzTypography.scoreLarge(color: FzColors.accent),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: IconButton(
                  onPressed: value == 0 ? null : () => onChanged(value - 1),
                  icon: const Icon(Icons.remove_rounded),
                ),
              ),
              Expanded(
                child: IconButton(
                  onPressed: () => onChanged(value + 1),
                  icon: const Icon(Icons.add_rounded),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

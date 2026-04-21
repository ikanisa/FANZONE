import 'package:flutter/cupertino.dart';
import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../providers/prediction_slip_provider.dart';
import '../../services/prediction_slip_service.dart';
import '../../theme/colors.dart';
import 'share_prediction_modal.dart';

class PredictionSlipDock extends ConsumerWidget {
  const PredictionSlipDock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selections = ref.watch(predictionSlipProvider);
    if (selections.isEmpty) return const SizedBox.shrink();

    return Material(
      color: FzColors.primary,
      borderRadius: BorderRadius.circular(12),
      elevation: 8,
      shadowColor: Colors.black45,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const _PredictionSlipModal(),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${selections.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Free Prediction Slip',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              const Icon(LucideIcons.arrowUp, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _PredictionSlipModal extends ConsumerStatefulWidget {
  const _PredictionSlipModal();

  @override
  ConsumerState<_PredictionSlipModal> createState() =>
      _PredictionSlipModalState();
}

class _PredictionSlipModalState extends ConsumerState<_PredictionSlipModal> {
  bool _submitting = false;

  Future<void> _submitPredictions(List<PredictionSelection> selections) async {
    unawaited(HapticFeedback.mediumImpact());
    setState(() => _submitting = true);

    try {
      await ref
          .read(predictionSlipServiceProvider)
          .submitSlip(selections: selections);

      if (!mounted) return;
      final matchTitles = selections.map((s) => s.title).toList();
      final count = matchTitles.length;
      ref.read(predictionSlipProvider.notifier).clear();
      ref.invalidate(myPredictionSlipsProvider);
      Navigator.of(context).pop();
      if (!context.mounted) return;
      showSharePredictionModal(
        context,
        selectionCount: count,
        matchNames: matchTitles,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _errorMessage(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    if (message.contains('Not authenticated')) {
      return 'Sign in to submit free predictions.';
    }
    return message == 'StateError: Bad state: Not authenticated'
        ? 'Sign in to submit free predictions.'
        : (message.isEmpty
              ? 'Failed to submit predictions. Try again.'
              : message);
  }

  @override
  Widget build(BuildContext context) {
    final selections = ref.watch(predictionSlipProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? FzColors.darkSurface2 : FzColors.lightSurface;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final text = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Free Matchday Slip',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No stake required. Free slips build your streak, badges, and fan identity.',
                      style: TextStyle(
                        fontSize: 12,
                        color: muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(LucideIcons.x, color: muted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (selections.isEmpty) ...[
            const SizedBox(height: 16),
            Center(
              child: Text('Slip is empty', style: TextStyle(color: muted)),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? FzColors.darkSurface : FzColors.lightSurface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.sparkles,
                    size: 18,
                    color: FzColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pool stakes still happen inside dedicated pool and challenge flows. This slip is always free.',
                      style: TextStyle(
                        fontSize: 12,
                        color: muted,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: selections.length,
                separatorBuilder: (_, _) => Divider(color: border, height: 16),
                itemBuilder: (context, index) {
                  final selection = selections[index];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selection.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              selection.subtitle,
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              selection.multiplier != null
                                  ? 'Confidence market x${selection.multiplier!.toStringAsFixed(2)}'
                                  : selection.baseFet != null &&
                                        selection.baseFet! > 0
                                  ? 'Earn ${selection.baseFet} FET if correct'
                                  : 'Market added to free slip',
                              style: TextStyle(
                                fontSize: 10,
                                color:
                                    selection.multiplier != null ||
                                        (selection.baseFet != null &&
                                            selection.baseFet! > 0)
                                    ? FzColors.primary
                                    : muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(LucideIcons.trash2, color: muted, size: 20),
                        onPressed: () => ref
                            .read(predictionSlipProvider.notifier)
                            .removeSelection(selection.id),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting
                  ? null
                  : () => _submitPredictions(selections),
              style: FilledButton.styleFrom(
                backgroundColor: FzColors.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CupertinoActivityIndicator(color: Colors.white),
                    )
                  : Text(
                      'Lock Free Prediction${selections.length > 1 ? 's' : ''}',
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../theme/colors.dart';
import '../../theme/typography.dart';

Future<bool?> showContributionConfirmModal(
  BuildContext context, {
  required String tier,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _ContributionConfirmDialog(tier: tier),
  );
}

class _ContributionConfirmDialog extends StatefulWidget {
  const _ContributionConfirmDialog({required this.tier});

  final String tier;

  @override
  State<_ContributionConfirmDialog> createState() =>
      _ContributionConfirmDialogState();
}

class _ContributionConfirmDialogState
    extends State<_ContributionConfirmDialog> {
  bool _confirming = false;

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;
    final panel = isDark ? FzColors.darkSurface3 : FzColors.lightSurface3;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Dialog(
      backgroundColor: surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFCC00).withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFCC00).withValues(alpha: 0.30),
                      ),
                    ),
                    child: const Icon(
                      LucideIcons.checkCircle2,
                      size: 30,
                      color: Color(0xFFFFCC00),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'CONFIRM CONTRIBUTION',
                    textAlign: TextAlign.center,
                    style: FzTypography.display(
                      size: 24,
                      color: textColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Did you complete the MoMo USSD payment for the ${widget.tier} tier?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: muted, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: panel,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      children: [
                        _InfoRow(
                          label: 'Selected Tier',
                          value: widget.tier,
                          valueColor: textColor,
                          muted: muted,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Status',
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFFFCC00,
                                ).withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'PENDING VERIFICATION',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFFCC00),
                                  letterSpacing: 0.9,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _confirming
                              ? null
                              : () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textColor,
                            side: BorderSide(color: border),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Not Yet',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _confirming ? null : _confirm,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFFCC00),
                            foregroundColor: const Color(0xFF1A1400),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _confirming ? 'Confirming...' : 'Yes, I Paid',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Contributions are verified anonymously via Fan ID.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: muted,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: InkWell(
                onTap: _confirming ? null : () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: panel,
                    shape: BoxShape.circle,
                    border: Border.all(color: border),
                  ),
                  child: Icon(LucideIcons.x, size: 16, color: muted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.muted,
  });

  final String label;
  final String value;
  final Color valueColor;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: muted)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

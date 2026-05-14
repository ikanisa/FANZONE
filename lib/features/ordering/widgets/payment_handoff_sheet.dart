import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/hospitality/order_model.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../data/order_gateway.dart';

Future<void> showPaymentHandoffSheet(
  BuildContext context, {
  required PaymentHandoff handoff,
}) {
  final isMomo = handoff.method == PaymentMethod.momo;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: FzColors.darkSurface,
          borderRadius: FzRadii.bottomSheetRadius,
          border: Border.all(color: FzColors.darkBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: FzColors.darkSurface4,
                      borderRadius: FzRadii.fullRadius,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: FzColors.primary.withValues(alpha: 0.14),
                        borderRadius: FzRadii.compactRadius,
                        border: Border.all(
                          color: FzColors.primary.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Icon(
                        isMomo ? LucideIcons.phoneCall : LucideIcons.creditCard,
                        color: FzColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isMomo ? 'MoMo' : 'Revolut',
                            style: const TextStyle(
                              color: FzColors.darkText,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (handoff.requiresStaffConfirmation) ...[
                            const SizedBox(height: 5),
                            const Text(
                              'Staff confirms payment.',
                              style: TextStyle(
                                color: FzColors.darkMuted,
                                fontSize: 12,
                                height: 1.3,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _PaymentMetric(
                  label: 'Amount',
                  value: '${handoff.currency} ${handoff.amount}'.trim(),
                ),
                if (handoff.instructions.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  ...handoff.instructions.map(
                    (instruction) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            LucideIcons.checkCircle2,
                            size: 17,
                            color: FzColors.success,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              instruction,
                              style: const TextStyle(
                                color: FzColors.darkText,
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: Icon(
                      isMomo ? LucideIcons.phoneCall : LucideIcons.creditCard,
                      size: 17,
                    ),
                    label: Text(isMomo ? 'Open USSD' : 'Open Revolut'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PaymentMetric extends StatelessWidget {
  const _PaymentMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FzColors.darkSurface2,
        borderRadius: FzRadii.cardAltRadius,
        border: Border.all(color: FzColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: FzColors.darkMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value.isEmpty ? '-' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FzColors.darkText,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

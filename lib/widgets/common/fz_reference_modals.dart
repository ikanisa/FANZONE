import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../theme/colors.dart';
import '../../theme/radii.dart';

Future<void> showFzInsufficientFetSheet(
  BuildContext context, {
  required int requiredFet,
  required int availableFet,
  VoidCallback? onOpenWallet,
}) {
  final shortfall = requiredFet > availableFet ? requiredFet - availableFet : 0;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _FzActionSheet(
      icon: LucideIcons.wallet,
      iconColor: FzColors.accent2,
      title: 'Not enough FET',
      subtitle:
          'You need $requiredFet FET to continue. Your available balance is $availableFet FET.',
      metrics: [
        _SheetMetric(label: 'Required', value: '$requiredFet FET'),
        _SheetMetric(label: 'Shortfall', value: '$shortfall FET'),
      ],
      primaryLabel: 'Open Wallet',
      primaryIcon: LucideIcons.wallet,
      onPrimary: onOpenWallet == null
          ? null
          : () {
              Navigator.of(sheetContext).pop();
              onOpenWallet();
            },
      secondaryLabel: 'Keep Editing',
      onSecondary: () => Navigator.of(sheetContext).pop(),
    ),
  );
}

Future<void> showFzInviteFriendsSheet(
  BuildContext context, {
  required String title,
  required String shareUrl,
  required FutureOr<void> Function() onShare,
  FutureOr<void> Function()? onCopy,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _FzActionSheet(
      icon: LucideIcons.send,
      iconColor: FzColors.primary,
      title: 'Invite Friends',
      subtitle: title,
      detail: shareUrl,
      primaryLabel: 'Share Invite',
      primaryIcon: LucideIcons.share2,
      onPrimary: () async {
        Navigator.of(sheetContext).pop();
        await onShare();
      },
      secondaryLabel: onCopy == null ? 'Close' : 'Copy Link',
      secondaryIcon: onCopy == null ? LucideIcons.x : LucideIcons.copy,
      onSecondary: () async {
        Navigator.of(sheetContext).pop();
        await onCopy?.call();
      },
    ),
  );
}

Future<void> showFzWinnerCelebrationSheet(
  BuildContext context, {
  required String title,
  required int amountFet,
  VoidCallback? onOpenWallet,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _FzActionSheet(
      icon: LucideIcons.crown,
      iconColor: FzColors.success,
      title: 'Winner Reward',
      subtitle: title,
      metrics: [
        _SheetMetric(label: 'Credited', value: '+$amountFet FET'),
        const _SheetMetric(label: 'Status', value: 'Settled'),
      ],
      primaryLabel: 'Open Wallet',
      primaryIcon: LucideIcons.wallet,
      onPrimary: onOpenWallet == null
          ? null
          : () {
              Navigator.of(sheetContext).pop();
              onOpenWallet();
            },
      secondaryLabel: 'Done',
      onSecondary: () => Navigator.of(sheetContext).pop(),
    ),
  );
}

Future<void> showFzNoticeSheet(
  BuildContext context, {
  required String title,
  required String message,
  IconData icon = LucideIcons.info,
  Color iconColor = FzColors.primary,
  String primaryLabel = 'Done',
  VoidCallback? onPrimary,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _FzActionSheet(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: message,
      primaryLabel: primaryLabel,
      primaryIcon: LucideIcons.checkCircle2,
      onPrimary: () {
        Navigator.of(sheetContext).pop();
        onPrimary?.call();
      },
    ),
  );
}

class _FzActionSheet extends StatelessWidget {
  const _FzActionSheet({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryIcon,
    this.secondaryLabel,
    this.secondaryIcon,
    this.onSecondary,
    this.detail,
    this.metrics = const [],
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final IconData? primaryIcon;
  final FutureOr<void> Function()? onPrimary;
  final String? secondaryLabel;
  final IconData? secondaryIcon;
  final FutureOr<void> Function()? onSecondary;
  final String? detail;
  final List<_SheetMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, bottomPadding + 14),
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
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.14),
                        borderRadius: FzRadii.compactRadius,
                        border: Border.all(
                          color: iconColor.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Icon(icon, color: iconColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: FzColors.darkText,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: FzColors.darkMuted,
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (metrics.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      for (var index = 0; index < metrics.length; index++) ...[
                        if (index > 0) const SizedBox(width: 10),
                        Expanded(child: metrics[index]),
                      ],
                    ],
                  ),
                ],
                if (detail != null && detail!.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FzColors.darkSurface2,
                      borderRadius: FzRadii.cardAltRadius,
                      border: Border.all(color: FzColors.darkBorder),
                    ),
                    child: Text(
                      detail!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FzColors.darkText,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onPrimary == null
                        ? null
                        : () async => onPrimary!(),
                    icon: Icon(primaryIcon ?? LucideIcons.arrowRight, size: 17),
                    label: Text(primaryLabel),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                if (secondaryLabel != null && onSecondary != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onSecondary == null
                          ? null
                          : () async => onSecondary!(),
                      icon: Icon(secondaryIcon ?? LucideIcons.x, size: 17),
                      label: Text(secondaryLabel!),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetMetric extends StatelessWidget {
  const _SheetMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FzColors.darkMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FzColors.darkText,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../theme/colors.dart';
import '../../widgets/common/fz_card.dart';

/// Post-prediction share modal — encourages virality after locking a prediction.
///
/// Matches the original design reference (SharePredictionModal.tsx):
/// - Prediction summary card
/// - Share to socials + copy link actions
/// - Animated celebration header
void showSharePredictionModal(
  BuildContext context, {
  required int selectionCount,
  List<String> matchNames = const [],
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _SharePredictionSheet(
      selectionCount: selectionCount,
      matchNames: matchNames,
    ),
  );
}

class _SharePredictionSheet extends StatelessWidget {
  const _SharePredictionSheet({
    required this.selectionCount,
    required this.matchNames,
  });

  final int selectionCount;
  final List<String> matchNames;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    final shareText = _buildShareText();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface : FzColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 20),

              // Celebration icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      FzColors.primary.withValues(alpha: 0.15),
                      FzColors.secondary.withValues(alpha: 0.15),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.sparkles,
                  color: FzColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Predictions Locked! 🔒',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$selectionCount prediction${selectionCount > 1 ? 's' : ''} added to your free matchday slip.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: muted, height: 1.4),
              ),

              if (matchNames.isNotEmpty) ...[
                const SizedBox(height: 16),
                FzCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR PICKS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: muted,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final match in matchNames.take(5))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.chevronRight,
                                size: 14,
                                color: FzColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  match,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (matchNames.length > 5)
                        Text(
                          '+${matchNames.length - 5} more',
                          style: TextStyle(
                            fontSize: 10,
                            color: muted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Share actions
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        unawaited(HapticFeedback.selectionClick());
                        await SharePlus.instance.share(
                          ShareParams(text: shareText),
                        );
                      },
                      icon: const Icon(LucideIcons.share2, size: 16),
                      label: const Text('Share'),
                      style: FilledButton.styleFrom(
                        backgroundColor: FzColors.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      unawaited(HapticFeedback.selectionClick());
                      await Clipboard.setData(ClipboardData(text: shareText));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                    icon: const Icon(LucideIcons.copy, size: 16),
                    label: const Text('Copy'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(
                        color: isDark
                            ? FzColors.darkBorder
                            : FzColors.lightBorder,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Maybe Later',
                  style: TextStyle(
                    fontSize: 14,
                    color: muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildShareText() {
    final buffer = StringBuffer();
    buffer.writeln(
      '🔮 Just locked $selectionCount prediction${selectionCount > 1 ? 's' : ''} on FANZONE!',
    );
    if (matchNames.isNotEmpty) {
      buffer.writeln();
      for (final match in matchNames.take(3)) {
        buffer.writeln('⚽ $match');
      }
      if (matchNames.length > 3) {
        buffer.writeln('...and ${matchNames.length - 3} more');
      }
    }
    buffer.writeln();
    buffer.writeln('Think you can beat me? 🏆');
    buffer.write(
      'https://play.google.com/store/apps/details?id=app.fanzone.football',
    );
    return buffer.toString();
  }
}

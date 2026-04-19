import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/daily_challenge_model.dart';
import '../../../services/daily_challenge_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/radii.dart';


/// Daily challenge card shown on the home feed.
///
/// Displays today's free prediction challenge with match name,
/// FET reward, and entry status. Follows the reference design's
/// card patterns: surface2 background, border-border, rounded-[20px].
class DailyChallengeCard extends ConsumerWidget {
  const DailyChallengeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengeAsync = ref.watch(dailyChallengeServiceProvider);
    final entryAsync = ref.watch(myDailyEntryProvider);

    return challengeAsync.when(
      data: (challenge) {
        if (challenge == null) return const SizedBox.shrink();
        final entry = entryAsync.valueOrNull;
        return _DailyChallengeBody(challenge: challenge, entry: entry);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _DailyChallengeBody extends StatelessWidget {
  const _DailyChallengeBody({
    required this.challenge,
    this.entry,
  });

  final DailyChallenge challenge;
  final DailyChallengeEntry? entry;

  bool get _hasEntered => entry != null;
  bool get _isSettled => challenge.status == 'settled';

  String get _statusLabel {
    if (_isSettled) {
      final result = entry?.result ?? 'pending';
      if (result == 'exact_score') return '🎯 EXACT SCORE';
      if (result == 'correct_result') return '✅ CORRECT';
      if (result == 'wrong') return '❌ MISSED';
      return 'SETTLED';
    }
    if (_hasEntered) return 'ENTERED';
    return 'FREE ENTRY';
  }

  Color _statusColor() {
    if (_isSettled) {
      final result = entry?.result ?? 'pending';
      if (result == 'exact_score' || result == 'correct_result') {
        return FzColors.success;
      }
      return FzColors.danger;
    }
    if (_hasEntered) return FzColors.accent;
    return FzColors.coral;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final surface = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;

    final statusColor = _statusColor();

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        // Navigate to the pool/match for this challenge
        context.push('/match/${challenge.matchId}');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: FzRadii.cardRadius,
          border: Border.all(
            color: statusColor.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: isDark ? 0.08 : 0.04),
              blurRadius: 20,
              spreadRadius: -8,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: FzRadii.fullRadius,
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(
                _hasEntered ? LucideIcons.checkCircle : LucideIcons.target,
                size: 20,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _statusLabel,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '+${challenge.rewardFet} FET',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          color: FzColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    challenge.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    challenge.matchName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: muted.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

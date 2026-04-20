import 'package:flutter/cupertino.dart';
import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../models/pool.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../services/pool_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../auth/widgets/sign_in_required_sheet.dart';

/// Shows the pool join bottom sheet.
Future<void> showPoolJoinSheet(
  BuildContext context, {
  required ScorePool pool,
  required bool isDark,
  required Color textColor,
  required Color muted,
}) async {
  unawaited(HapticFeedback.mediumImpact());
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? FzColors.darkSurface : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => PoolJoinSheet(
      pool: pool,
      isDark: isDark,
      textColor: textColor,
      muted: muted,
    ),
  );
}

class PoolJoinSheet extends ConsumerStatefulWidget {
  const PoolJoinSheet({
    super.key,
    required this.pool,
    required this.isDark,
    required this.textColor,
    required this.muted,
  });

  final ScorePool pool;
  final bool isDark;
  final Color textColor;
  final Color muted;

  @override
  ConsumerState<PoolJoinSheet> createState() => _PoolJoinSheetState();
}

class _PoolJoinSheetState extends ConsumerState<PoolJoinSheet> {
  int _homeScore = 0;
  int _awayScore = 0;
  bool _submitting = false;
  String? _error;

  Future<void> _submitJoin() async {
    if (!ref.read(isAuthenticatedProvider)) {
      await showSignInRequiredSheet(
        context,
        title: 'Sign in to join this pool',
        message:
            'Phone verification is required before you can stake FET in a pool.',
        from: '/pool/${widget.pool.id}',
      );
      return;
    }

    if (widget.pool.status != 'open') {
      setState(() => _error = 'This pool is no longer open to join.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(poolServiceProvider.notifier)
          .joinPool(
            poolId: widget.pool.id,
            homeScore: _homeScore,
            awayScore: _awayScore,
            stake: widget.pool.stake,
          );
      ref.invalidate(poolDetailProvider(widget.pool.id));
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pool joined successfully.')),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } on ArgumentError catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message.toString());
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not join this pool. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';
    final teams = widget.pool.matchName.split(' vs ');
    final homeTeam = teams.isNotEmpty ? teams[0].trim() : 'Home';
    final awayTeam = teams.length > 1 ? teams[1].trim() : 'Away';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: widget.isDark
                    ? FzColors.darkSurface3
                    : FzColors.lightSurface3,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'JOIN POOL',
              style: FzTypography.display(size: 24, color: widget.textColor),
            ),
            const SizedBox(height: 4),
            Text(
              widget.pool.matchName,
              style: TextStyle(fontSize: 13, color: widget.muted),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScorePicker(
                  label: homeTeam,
                  score: _homeScore,
                  isDark: widget.isDark,
                  textColor: widget.textColor,
                  muted: widget.muted,
                  onIncrement: () => setState(() => _homeScore++),
                  onDecrement: () => setState(() {
                    if (_homeScore > 0) _homeScore--;
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    ':',
                    style: FzTypography.score(size: 28, color: widget.muted),
                  ),
                ),
                ScorePicker(
                  label: awayTeam,
                  score: _awayScore,
                  isDark: widget.isDark,
                  textColor: widget.textColor,
                  muted: widget.muted,
                  onIncrement: () => setState(() => _awayScore++),
                  onDecrement: () => setState(() {
                    if (_awayScore > 0) _awayScore--;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? FzColors.darkSurface2
                    : FzColors.lightSurface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isDark
                      ? FzColors.darkBorder
                      : FzColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'REQUIRED STAKE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: widget.muted,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatFET(widget.pool.stake, currency),
                        style: FzTypography.score(
                          size: 14,
                          weight: FontWeight.w700,
                          color: FzColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if ((_error ?? '').isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FzColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: FzColors.error,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        _submitJoin();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isDark
                      ? FzColors.darkText
                      : FzColors.lightText,
                  foregroundColor: widget.isDark
                      ? FzColors.darkBg
                      : FzColors.lightBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: _submitting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CupertinoActivityIndicator(
                          color: widget.isDark
                              ? FzColors.darkBg
                              : FzColors.lightBg,
                        ),
                      )
                    : const Text(
                        'Confirm & Stake',
                        style: TextStyle(
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

class ScorePicker extends StatelessWidget {
  const ScorePicker({
    super.key,
    required this.label,
    required this.score,
    required this.isDark,
    required this.textColor,
    required this.muted,
    required this.onIncrement,
    required this.onDecrement,
  });

  final String label;
  final int score;
  final bool isDark;
  final Color textColor;
  final Color muted;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label.length > 8 ? '${label.substring(0, 8)}...' : label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: muted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onIncrement();
          },
          child: Container(
            width: 48,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(LucideIcons.plus, size: 18, color: textColor),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$score',
          style: FzTypography.score(
            size: 36,
            weight: FontWeight.w700,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onDecrement();
          },
          child: Container(
            width: 48,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(LucideIcons.minus, size: 18, color: textColor),
          ),
        ),
      ],
    );
  }
}

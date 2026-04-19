import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/pool.dart';
import '../../../core/utils/currency_utils.dart';
import '../../auth/widgets/sign_in_required_sheet.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../services/pool_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_badge.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../config/app_config.dart';
import '../../../widgets/social/feed_chat.dart';

/// Pool detail screen — full dedicated page matching the original design.
///
/// Shows: status hero, match name, stake, pool/participants grid,
/// creator info + prediction, join CTA with score picker bottom sheet.
class PoolDetailScreen extends ConsumerWidget {
  const PoolDetailScreen({super.key, required this.poolId});
  final String poolId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poolAsync = ref.watch(poolDetailProvider(poolId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'POOL',
          style: FzTypography.display(size: 24, color: textColor),
        ),
        centerTitle: true,
        actions: [
          if (AppConfig.enableDeepLinking)
            IconButton(
              icon: Icon(LucideIcons.share2, color: textColor, size: 20),
              tooltip: 'Share Pool',
              onPressed: () {
                final url = 'https://fanzone.mt/pool/$poolId';
                SharePlus.instance.share(
                  ShareParams(
                    text: 'Join my prediction pool on FANZONE! 🏆⚽\n$url',
                    subject: 'FANZONE Pool Invite',
                  ),
                );
              },
            ),
        ],
      ),
      body: poolAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => StateView.error(
          title: 'Cannot load pool',
          subtitle: e.toString(),
          onRetry: () => ref.invalidate(poolDetailProvider(poolId)),
        ),
        data: (pool) {
          if (pool == null) {
            return StateView.empty(
              title: 'Not Found',
              subtitle: 'This pool may have been removed.',
              icon: Icons.search_off_rounded,
            );
          }
          return _PoolContent(
            pool: pool,
            isDark: isDark,
            textColor: textColor,
            muted: muted,
          );
        },
      ),
    );
  }
}

class _PoolContent extends ConsumerWidget {
  const _PoolContent({
    required this.pool,
    required this.isDark,
    required this.textColor,
    required this.muted,
  });

  final ScorePool pool;
  final bool isDark;
  final Color textColor;
  final Color muted;

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return FzColors.accent;
      case 'locked':
        return FzColors.amber;
      case 'settled':
        return FzColors.success;
      case 'void':
        return FzColors.maltaRed;
      default:
        return muted;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _statusColor(pool.status);
    final lockTimeFormatted = DateFormat.Hm().format(pool.lockAt);
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Status Hero ──
        RepaintBoundary(
          child: FzCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Status badge + lock time
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FzBadge(
                      label: pool.status.toUpperCase(),
                      color: statusColor,
                      pulse: pool.status == 'open',
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'LOCK TIME',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: muted,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.clock, size: 12, color: muted),
                            const SizedBox(width: 4),
                            Text(
                              lockTimeFormatted,
                              style: FzTypography.scoreCompact(
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Match name
                Text(
                  pool.matchName,
                  style: FzTypography.display(size: 28, color: textColor),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Stake pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? FzColors.darkSurface3
                        : FzColors.lightSurface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? FzColors.darkBorder
                          : FzColors.lightBorder,
                    ),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.center,
                    children: [
                      Text(
                        'STAKE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: muted,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        formatFET(pool.stake, currency),
                        style: FzTypography.score(
                          size: 18,
                          weight: FontWeight.w700,
                          color: FzColors.amber,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Pool + Participants grid
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: LucideIcons.zap,
                        iconColor: FzColors.accent,
                        label: 'TOTAL POOL',
                        value: formatFET(pool.totalPool, currency),
                        isDark: isDark,
                        muted: muted,
                        textColor: textColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: LucideIcons.users,
                        iconColor: FzColors.violet,
                        label: 'PARTICIPANTS',
                        value: '${pool.participantsCount}',
                        isDark: isDark,
                        muted: muted,
                        textColor: textColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Creator Info ──
        RepaintBoundary(
          child: FzCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.swords, size: 14, color: muted),
                    const SizedBox(width: 6),
                    Text(
                      'CREATED BY',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: muted,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isDark
                          ? FzColors.darkSurface3
                          : FzColors.lightSurface3,
                      child: Text(
                        pool.creatorName.isNotEmpty
                            ? pool.creatorName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        pool.creatorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'PREDICTION',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: muted,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            pool.creatorPrediction,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: FzTypography.score(
                              size: 16,
                              weight: FontWeight.w700,
                              color: FzColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── Join CTA ──
        if (pool.status == 'open')
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => _showJoinSheet(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: FzColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Join for ${formatFET(pool.stake, currency)}'),
                    const SizedBox(width: 8),
                    const Icon(LucideIcons.arrowRight, size: 20),
                  ],
                ),
              ),
            ),
          ),

        if (pool.status != 'open')
          FzCard(
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: statusColor.withValues(alpha: 0.1),
            borderColor: statusColor.withValues(alpha: 0.3),
            child: Center(
              child: Text(
                'Pool is ${pool.status.toUpperCase()}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

        // Pool chat
        if (AppConfig.enableSocialFeed) ...[
          const SizedBox(height: 20),
          Text(
            'POOL CHAT',
            style: FzTypography.sectionLabel(Theme.of(context).brightness),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 300,
            child: RepaintBoundary(
              child: FzCard(
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FeedChat(channelType: 'pool', channelId: pool.id),
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 96),
      ],
    );
  }

  void _showJoinSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? FzColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _JoinSheet(
        pool: pool,
        isDark: isDark,
        textColor: textColor,
        muted: muted,
      ),
    );
  }
}

// ── Stat Card ──

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.isDark,
    required this.muted,
    required this.textColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool isDark;
  final Color muted;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface : FzColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: muted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: FzTypography.score(
              size: 18,
              weight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Join Sheet ──

class _JoinSheet extends ConsumerStatefulWidget {
  const _JoinSheet({
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
  ConsumerState<_JoinSheet> createState() => _JoinSheetState();
}

class _JoinSheetState extends ConsumerState<_JoinSheet> {
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
        from: '/predict/pool/${widget.pool.id}',
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
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.pool;
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';
    final teams = c.matchName.split(' vs ');
    final homeTeam = teams.isNotEmpty ? teams[0].trim() : 'Home';
    final awayTeam = teams.length > 1 ? teams[1].trim() : 'Away';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
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
              c.matchName,
              style: TextStyle(fontSize: 13, color: widget.muted),
            ),
            const SizedBox(height: 24),

            // Score pickers
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ScorePicker(
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
                _ScorePicker(
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

            // Stake info
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
                        formatFET(c.stake, currency),
                        style: FzTypography.score(
                          size: 14,
                          weight: FontWeight.w700,
                          color: FzColors.accent,
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

            // Confirm button
            Builder(
              builder: (_) {
                final buttonChild = _submitting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
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
                      );
                return SizedBox(
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
                    child: buttonChild,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ScorePicker extends StatelessWidget {
  const _ScorePicker({
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

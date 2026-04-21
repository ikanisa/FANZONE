import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/pool.dart';
import '../../../services/pool_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/state_view.dart';
import '../../../core/config/feature_flags.dart';
import '../widgets/pool_detail_sections.dart';
import '../../../widgets/common/fz_shimmer.dart';

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
    final entriesAsync = ref.watch(myEntriesProvider);
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
          if (ref.watch(featureFlagsProvider).deepLinking)
            IconButton(
              icon: Icon(LucideIcons.share2, color: textColor, size: 20),
              tooltip: 'Share Pool',
              onPressed: () {
                final url = 'https://fanzone.ikanisa.com/pool/$poolId';
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
        loading: () => const ScoresPageSkeleton(),
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
              icon: LucideIcons.searchX,
            );
          }
          return _PoolContent(
            pool: pool,
            entry: _matchEntry(entriesAsync.valueOrNull, pool.id),
            isDark: isDark,
            textColor: textColor,
            muted: muted,
          );
        },
      ),
    );
  }
}

PoolEntry? _matchEntry(List<PoolEntry>? entries, String poolId) {
  if (entries == null) return null;
  for (final entry in entries) {
    if (entry.poolId == poolId) return entry;
  }
  return null;
}

class _PoolContent extends ConsumerStatefulWidget {
  const _PoolContent({
    required this.pool,
    required this.entry,
    required this.isDark,
    required this.textColor,
    required this.muted,
  });

  final ScorePool pool;
  final PoolEntry? entry;
  final bool isDark;
  final Color textColor;
  final Color muted;

  @override
  ConsumerState<_PoolContent> createState() => _PoolContentState();
}

class _PoolContentState extends ConsumerState<_PoolContent> {
  bool _hasClaimed = false;

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return FzColors.primary;
      case 'locked':
        return FzColors.secondary;
      case 'settled':
        return FzColors.success;
      case 'void':
        return FzColors.danger;
      default:
        return widget.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pool = widget.pool;
    final entry = widget.entry;
    final statusColor = _statusColor(pool.status);
    final isWinner = pool.status == 'settled' && (entry?.payout ?? 0) > 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PoolStatusHeroCard(
          pool: pool,
          isDark: widget.isDark,
          textColor: widget.textColor,
          muted: widget.muted,
          statusColor: statusColor,
        ),
        const SizedBox(height: 16),
        PoolCreatorCard(
          pool: pool,
          isDark: widget.isDark,
          textColor: widget.textColor,
          muted: widget.muted,
        ),
        const SizedBox(height: 24),
        if (entry != null) ...[
          _PoolEntryStateCard(
            pool: pool,
            entry: entry,
            claimed: _hasClaimed,
            onClaim: isWinner && !_hasClaimed
                ? () async {
                    final claimed = await showDialog<bool>(
                      context: context,
                      builder: (_) =>
                          _ClaimWinningsDialog(payout: entry.payout),
                    );
                    if (claimed == true && mounted) {
                      setState(() => _hasClaimed = true);
                    }
                  }
                : null,
          ),
          const SizedBox(height: 20),
        ],
        if (entry == null)
          PoolJoinSection(
            pool: pool,
            statusColor: statusColor,
            isDark: widget.isDark,
            textColor: widget.textColor,
            muted: widget.muted,
          ),
        if (ref.watch(featureFlagsProvider).socialFeed && entry == null) ...[
          const SizedBox(height: 20),
          PoolChatSection(poolId: pool.id),
        ],
        const SizedBox(height: 96),
      ],
    );
  }
}

class _PoolEntryStateCard extends StatelessWidget {
  const _PoolEntryStateCard({
    required this.pool,
    required this.entry,
    required this.claimed,
    this.onClaim,
  });

  final ScorePool pool;
  final PoolEntry entry;
  final bool claimed;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final surface = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;

    late final IconData icon;
    late final Color tone;
    late final String title;
    late final String subtitle;

    if (pool.status == 'open') {
      icon = LucideIcons.shieldAlert;
      tone = const Color(0xFF25D366);
      title = 'You are in this Challenge!';
      subtitle =
          'Your prediction is locked at ${entry.predictedHomeScore} - ${entry.predictedAwayScore}.';
    } else if (pool.status == 'void') {
      icon = LucideIcons.alertTriangle;
      tone = FzColors.coral;
      title = 'Pool Voided';
      subtitle =
          'Your stake of ${entry.stake} FET has been returned automatically.';
    } else if ((entry.payout > 0)) {
      icon = LucideIcons.trophy;
      tone = FzColors.success;
      title = claimed ? 'Winnings Claimed' : 'You Won!';
      subtitle = claimed
          ? '${entry.payout} FET has been added to your wallet.'
          : 'Your prediction was correct.';
    } else {
      icon = LucideIcons.x;
      tone = FzColors.darkMuted;
      title = 'Better luck next time';
      subtitle =
          'Your prediction was ${entry.predictedHomeScore} - ${entry.predictedAwayScore}.';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: (entry.payout > 0 ? FzColors.success : tone).withValues(
            alpha: 0.28,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: tone),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: FzColors.darkText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: FzColors.darkMuted,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          if (entry.payout > 0 && !claimed && onClaim != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onClaim,
              style: FilledButton.styleFrom(
                backgroundColor: FzColors.success,
                foregroundColor: FzColors.darkBg,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              icon: const Icon(LucideIcons.gift, size: 18),
              label: Text(
                'Claim Winnings (${entry.payout} FET)',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
          if (pool.status == 'settled' && entry.payout <= 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: const Text(
                'Final result settled',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: FzColors.darkMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClaimWinningsDialog extends StatelessWidget {
  const _ClaimWinningsDialog({required this.payout});

  final int payout;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Victory!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your prediction was spot on.'),
          const SizedBox(height: 12),
          Text(
            '+$payout FET',
            style: FzTypography.score(
              size: 28,
              weight: FontWeight.w700,
              color: FzColors.success,
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Add to Wallet'),
        ),
      ],
    );
  }
}

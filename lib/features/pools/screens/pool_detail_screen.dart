import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../theme/colors.dart';
import '../../../theme/radii.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_eligibility_rule_card.dart';
import '../../../widgets/common/fz_reference_chrome.dart';
import '../../../widgets/common/fz_reference_modals.dart';
import '../../../widgets/common/state_view.dart';
import '../data/pools_repository.dart';

class PoolDetailScreen extends ConsumerWidget {
  const PoolDetailScreen({super.key, required this.poolId});

  final String poolId;

  Future<void> _sharePool(
    BuildContext context,
    WidgetRef ref,
    PoolSummary pool,
  ) async {
    final repository = ref.read(poolsRepositoryProvider);
    var shareUrl = _withSource(
      pool.shareUrl ??
          (pool.shareSlug == null ? '/pools' : '/pools/${pool.shareSlug}'),
      'social_share',
    );
    var inviteCreated = false;

    try {
      await repository.ensureSocialCard(pool.id);
    } catch (_) {
      // Sharing should still work if the backend card worker is unavailable.
    }

    try {
      final result = await repository.createInvite(pool.id);
      final inviteUrl = result['share_url']?.toString();
      if (inviteUrl != null && inviteUrl.isNotEmpty) {
        shareUrl = inviteUrl;
        inviteCreated = true;
      }
    } catch (_) {
      // Non-creators can still share the public pool link without attribution.
    }

    final absoluteUrl = _absolutePoolShareUrl(shareUrl);
    if (!context.mounted) return;

    await showFzInviteFriendsSheet(
      context,
      title: inviteCreated ? 'Invite ready' : 'Share pool',
      shareUrl: absoluteUrl,
      onShare: () async {
        try {
          await SharePlus.instance.share(
            ShareParams(
              text: '${pool.title}\nJoin the pool: $absoluteUrl',
              title: pool.title,
              subject: pool.title,
            ),
          );
        } catch (_) {
          await Clipboard.setData(ClipboardData(text: absoluteUrl));
        }
      },
      onCopy: () async {
        await Clipboard.setData(ClipboardData(text: absoluteUrl));
      },
    );
  }

  Future<void> _showWinnerReward(
    BuildContext context,
    PoolSummary pool,
    PoolEntryState entry,
  ) {
    return showFzWinnerCelebrationSheet(
      context,
      title: 'Reward ready',
      amountFet: entry.payoutFet,
      onOpenWallet: () {
        if (context.mounted) context.push('/wallet');
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poolAsync = ref.watch(poolDetailProvider(poolId));
    final entryAsync = ref.watch(poolEntryStateProvider(poolId));

    return Scaffold(
      body: SafeArea(
        child: poolAsync.when(
          data: (pool) {
            if (pool == null) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 130),
                children: [
                  const FzBackHeader(title: 'Pool', subtitle: 'Entry'),
                  const SizedBox(height: 48),
                  StateView.empty(
                    title: 'Pool not found',
                    subtitle: 'Choose another.',
                    action: () => context.go('/pools'),
                    actionLabel: 'Pools',
                  ),
                ],
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(poolDetailProvider(poolId));
                ref.invalidate(poolEntryStateProvider(poolId));
                await ref.read(poolDetailProvider(poolId).future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 130),
                children: [
                  const FzBackHeader(title: 'Pool', subtitle: 'Entry'),
                  const SizedBox(height: 18),
                  _PoolHero(pool: pool),
                  const SizedBox(height: 14),
                  entryAsync.when(
                    data: (entry) => Column(
                      children: [
                        _EntryStateCard(pool: pool, entry: entry),
                        if (entry != null && entry.payoutFet > 0) ...[
                          const SizedBox(height: 14),
                          _WinnerRewardCard(
                            pool: pool,
                            entry: entry,
                            onView: () =>
                                _showWinnerReward(context, pool, entry),
                          ),
                        ],
                      ],
                    ),
                    loading: () => const _EntryStateLoading(),
                    error: (_, _) =>
                        const _EntryStateCard(pool: null, entry: null),
                  ),
                  const SizedBox(height: 14),
                  const FzEligibilityRuleCard(),
                  const SizedBox(height: 14),
                  _CampsSection(pool: pool),
                  const SizedBox(height: 14),
                  _LiveTimeline(pool: pool),
                  const SizedBox(height: 14),
                  _SettlementCard(pool: pool),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: pool.isOpen
                              ? () => context.push('/pool/${pool.id}/join')
                              : null,
                          icon: const Icon(LucideIcons.trophy, size: 16),
                          label: const Text('Stake'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _sharePool(context, ref, pool),
                          icon: const Icon(LucideIcons.share2, size: 16),
                          label: const Text('Share'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
          loading: () => const _PoolDetailLoadingState(),
          error: (error, _) => StateView.error(
            title: 'Pool unavailable',
            subtitle: error.toString(),
            onRetry: () => ref.invalidate(poolDetailProvider(poolId)),
          ),
        ),
      ),
    );
  }
}

String _absolutePoolShareUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
  return 'https://fanzone.ikanisa.com$path';
}

String _withSource(String value, String source) {
  final uri = Uri.parse(value);
  if (uri.queryParameters.containsKey('source')) return value;
  return uri
      .replace(queryParameters: {...uri.queryParameters, 'source': source})
      .toString();
}

class _PoolHero extends StatelessWidget {
  const _PoolHero({required this.pool});

  final PoolSummary pool;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FzColors.darkSurface, FzColors.teal],
        ),
        borderRadius: FzRadii.heroRadius,
        border: Border.all(color: FzColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusPill(status: pool.status),
              const SizedBox(width: 8),
              const _ScopePill(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            pool.title,
            style: FzTypography.display(
              size: 34,
              color: Colors.white,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            pool.venueName == null ? 'Bar needed' : pool.venueName!,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeroMetric(label: 'Members', value: '${pool.totalMembers}'),
              const SizedBox(width: 10),
              _HeroMetric(label: 'Pooled', value: '${pool.totalStakedFet} FET'),
              const SizedBox(width: 10),
              _HeroMetric(label: 'Stake', value: '${pool.defaultStakeFet} FET'),
            ],
          ),
        ],
      ),
    );
  }
}

class _EntryStateCard extends StatelessWidget {
  const _EntryStateCard({required this.pool, required this.entry});

  final PoolSummary? pool;
  final PoolEntryState? entry;

  @override
  Widget build(BuildContext context) {
    final camp = entry == null
        ? null
        : pool?.camps.cast<PoolCamp?>().firstWhere(
            (camp) => camp?.id == entry!.campId,
            orElse: () => null,
          );

    return FzCard(
      padding: const EdgeInsets.all(16),
      borderRadius: FzRadii.compact,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (entry == null ? FzColors.darkMuted : FzColors.success)
                  .withValues(alpha: 0.12),
              borderRadius: FzRadii.buttonRadius,
            ),
            child: Icon(
              entry == null ? LucideIcons.ticket : LucideIcons.badgeCheck,
              color: entry == null ? FzColors.darkMuted : FzColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry == null ? 'No entry' : 'Joined',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry == null
                      ? 'Pick a camp.'
                      : '${camp?.label ?? 'Camp'} - ${entry!.amountFet} FET',
                  style: const TextStyle(
                    fontSize: 13,
                    color: FzColors.darkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryStateLoading extends StatelessWidget {
  const _EntryStateLoading();

  @override
  Widget build(BuildContext context) {
    return const FzCard(
      padding: EdgeInsets.all(16),
      borderRadius: FzRadii.compact,
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Checking...'),
        ],
      ),
    );
  }
}

class _WinnerRewardCard extends StatelessWidget {
  const _WinnerRewardCard({
    required this.pool,
    required this.entry,
    required this.onView,
  });

  final PoolSummary pool;
  final PoolEntryState entry;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      padding: const EdgeInsets.all(16),
      borderRadius: FzRadii.compact,
      borderColor: FzColors.success.withValues(alpha: 0.45),
      color: FzColors.success.withValues(alpha: 0.08),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: FzColors.success.withValues(alpha: 0.16),
              borderRadius: FzRadii.buttonRadius,
            ),
            child: const Icon(LucideIcons.crown, color: FzColors.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reward ready',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  '+${entry.payoutFet} FET from ${pool.title}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FzColors.darkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'View reward',
            onPressed: onView,
            icon: const Icon(LucideIcons.sparkles, color: FzColors.success),
          ),
        ],
      ),
    );
  }
}

class _PoolDetailLoadingState extends StatelessWidget {
  const _PoolDetailLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
          FzBackHeader(title: 'Pool', subtitle: 'Entry'),
          Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}

class _CampsSection extends StatelessWidget {
  const _CampsSection({required this.pool});

  final PoolSummary pool;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Camps'),
        const SizedBox(height: 10),
        if (pool.camps.isEmpty)
          const FzCard(padding: EdgeInsets.all(16), child: Text('No camps.'))
        else
          ...pool.camps.map(
            (camp) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CampCard(pool: pool, camp: camp),
            ),
          ),
      ],
    );
  }
}

class _CampCard extends StatelessWidget {
  const _CampCard({required this.pool, required this.camp});

  final PoolSummary pool;
  final PoolCamp camp;

  @override
  Widget build(BuildContext context) {
    final isWinner = pool.resultCampId == camp.id;

    return FzCard(
      padding: const EdgeInsets.all(16),
      borderColor: isWinner ? FzColors.success : null,
      borderRadius: FzRadii.cardAlt,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (isWinner ? FzColors.success : FzColors.accent).withValues(
                alpha: 0.10,
              ),
              borderRadius: FzRadii.buttonRadius,
            ),
            child: Icon(
              isWinner ? LucideIcons.crown : LucideIcons.users,
              size: 18,
              color: isWinner ? FzColors.success : FzColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  camp.label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${camp.memberCount} members',
                  style: const TextStyle(
                    fontSize: 12,
                    color: FzColors.darkMuted,
                  ),
                ),
              ],
            ),
          ),
          if (isWinner)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(LucideIcons.crown, size: 16, color: FzColors.success),
            ),
          Text(
            '${camp.totalStakedFet} FET',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _LiveTimeline extends StatelessWidget {
  const _LiveTimeline({required this.pool});

  final PoolSummary pool;

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('Open', true),
      ('Locked', pool.status == 'locked' || pool.isSettled),
      ('Settled', pool.isSettled),
    ];

    return FzCard(
      padding: const EdgeInsets.all(16),
      borderRadius: FzRadii.compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'Timeline'),
          const SizedBox(height: 14),
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    step.$2 ? LucideIcons.checkCircle2 : LucideIcons.circle,
                    size: 18,
                    color: step.$2 ? FzColors.success : FzColors.darkMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      step.$1,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: step.$2 ? FzColors.darkText : FzColors.darkMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SettlementCard extends StatelessWidget {
  const _SettlementCard({required this.pool});

  final PoolSummary pool;

  @override
  Widget build(BuildContext context) {
    final winner = pool.resultCampId == null
        ? null
        : pool.camps.cast<PoolCamp?>().firstWhere(
            (camp) => camp?.id == pool.resultCampId,
            orElse: () => null,
          );

    return FzCard(
      padding: const EdgeInsets.all(16),
      borderRadius: FzRadii.compact,
      child: Row(
        children: [
          Icon(
            pool.isSettled ? LucideIcons.badgeCheck : LucideIcons.timer,
            color: pool.isSettled ? FzColors.success : FzColors.accent2,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              pool.isSettled
                  ? 'Winner: ${winner?.label ?? 'posted'}'
                  : 'Awaiting result',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: FzRadii.buttonRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = status == 'open'
        ? FzColors.success
        : status == 'settled'
        ? FzColors.accent2
        : FzColors.darkMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: FzRadii.fullRadius,
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _ScopePill extends StatelessWidget {
  const _ScopePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: FzRadii.fullRadius,
      ),
      child: const Text(
        'BAR POOL',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

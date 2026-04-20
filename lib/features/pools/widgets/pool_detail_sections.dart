import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../models/pool.dart';
import '../../../providers/currency_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_badge.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/social/feed_chat.dart';
import 'pool_join_sheet.dart';

class PoolStatusHeroCard extends ConsumerWidget {
  const PoolStatusHeroCard({
    super.key,
    required this.pool,
    required this.isDark,
    required this.textColor,
    required this.muted,
    required this.statusColor,
  });

  final ScorePool pool;
  final bool isDark;
  final Color textColor;
  final Color muted;
  final Color statusColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockTimeFormatted = DateFormat.Hm().format(pool.lockAt);
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';

    return RepaintBoundary(
      child: FzCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FzBadge(
                  label: pool.status.toUpperCase(),
                  variant: _statusBadgeVariant(pool.status),
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
                          style: FzTypography.scoreCompact(color: textColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              pool.matchName,
              style: FzTypography.display(size: 28, color: textColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? FzColors.darkSurface3 : FzColors.lightSurface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: PoolStatCard(
                    icon: LucideIcons.zap,
                    iconColor: FzColors.primary,
                    label: 'TOTAL POOL',
                    value: formatFET(pool.totalPool, currency),
                    isDark: isDark,
                    muted: muted,
                    textColor: textColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PoolStatCard(
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
    );
  }
}

FzBadgeVariant _statusBadgeVariant(String status) {
  switch (status) {
    case 'open':
      return FzBadgeVariant.accent;
    case 'settled':
      return FzBadgeVariant.accent3;
    case 'locked':
    case 'void':
      return FzBadgeVariant.ghost;
    default:
      return FzBadgeVariant.outline;
  }
}

class PoolCreatorCard extends StatelessWidget {
  const PoolCreatorCard({
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
  Widget build(BuildContext context) {
    return RepaintBoundary(
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
                          color: FzColors.primary,
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
    );
  }
}

class PoolJoinSection extends ConsumerWidget {
  const PoolJoinSection({
    super.key,
    required this.pool,
    required this.statusColor,
    required this.isDark,
    required this.textColor,
    required this.muted,
  });

  final ScorePool pool;
  final Color statusColor;
  final bool isDark;
  final Color textColor;
  final Color muted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';

    if (pool.status == 'open') {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () => showPoolJoinSheet(
            context,
            pool: pool,
            isDark: isDark,
            textColor: textColor,
            muted: muted,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: FzColors.primary,
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
      );
    }

    return FzCard(
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
    );
  }
}

class PoolChatSection extends StatelessWidget {
  const PoolChatSection({super.key, required this.poolId});

  final String poolId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                child: FeedChat(channelType: 'pool', channelId: poolId),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PoolStatCard extends StatelessWidget {
  const PoolStatCard({
    super.key,
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

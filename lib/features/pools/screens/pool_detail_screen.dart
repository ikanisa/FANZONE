import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/pool.dart';
import '../../../services/pool_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/state_view.dart';
import '../../../config/app_config.dart';
import '../widgets/pool_detail_sections.dart';

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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PoolStatusHeroCard(
          pool: pool,
          isDark: isDark,
          textColor: textColor,
          muted: muted,
          statusColor: statusColor,
        ),

        const SizedBox(height: 16),

        PoolCreatorCard(
          pool: pool,
          isDark: isDark,
          textColor: textColor,
          muted: muted,
        ),

        const SizedBox(height: 24),

        PoolJoinSection(
          pool: pool,
          statusColor: statusColor,
          isDark: isDark,
          textColor: textColor,
          muted: muted,
        ),

        if (AppConfig.enableSocialFeed) ...[
          const SizedBox(height: 20),
          PoolChatSection(poolId: pool.id),
        ],

        const SizedBox(height: 96),
      ],
    );
  }
}

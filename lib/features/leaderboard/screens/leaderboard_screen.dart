import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/common/fz_shimmer.dart';
import '../../../services/leaderboard_service.dart';
import '../../../services/wallet_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/fan/fan_identity_widgets.dart';

/// Leaderboard screen — global FET rankings with podium.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(globalLeaderboardProvider);
    final userRankAsync = ref.watch(userRankProvider);
    final balanceAsync = ref.watch(walletServiceProvider);
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'LEADERBOARD',
          style: FzTypography.display(
            size: 28,
            color: isDark ? FzColors.darkText : FzColors.lightText,
          ),
        ),
      ),
      body: leaderboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => StateView.error(
          title: 'Could not load leaderboard',
          onRetry: () => ref.invalidate(globalLeaderboardProvider),
        ),
        data: (rankings) {
          if (rankings.isEmpty) {
            return StateView.empty(
              title: 'No rankings yet',
              subtitle: 'Rankings will appear once users start earning FET.',
              icon: LucideIcons.trophy,
            );
          }

          // Split top 3 for podium, rest for list
          final podium = rankings.take(3).toList();
          final rest = rankings.skip(3).toList();

          return CustomScrollView(
            slivers: [
              // Podium (top 3)
              if (podium.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (podium.length > 1)
                          Expanded(
                            child: _PodiumItem(
                              rank: 2,
                              name: podium[1]['name']?.toString() ?? 'Fan',
                              score: podium[1]['fet']?.toString() ?? '0',
                              height: 100,
                            ),
                          ),
                        if (podium.length > 1) const SizedBox(width: 8),
                        Expanded(
                          child: _PodiumItem(
                            rank: 1,
                            name: podium[0]['name']?.toString() ?? 'Fan',
                            score: podium[0]['fet']?.toString() ?? '0',
                            height: 130,
                          ),
                        ),
                        if (podium.length > 2) const SizedBox(width: 8),
                        if (podium.length > 2)
                          Expanded(
                            child: _PodiumItem(
                              rank: 3,
                              name: podium[2]['name']?.toString() ?? 'Fan',
                              score: podium[2]['fet']?.toString() ?? '0',
                              height: 80,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              // Your rank card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FzCard(
                    padding: const EdgeInsets.all(16),
                    borderColor: FzColors.accent.withValues(alpha: 0.3),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: FzColors.accent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: userRankAsync.when(
                              data: (rank) => Text(
                                rank != null ? '$rank' : '—',
                                style: FzTypography.scoreCompact(
                                  color: FzColors.accent,
                                ),
                              ),
                              loading: () =>
                                  const FzShimmer(width: 20, height: 14),
                              error: (_, st) => Text(
                                '—',
                                style: FzTypography.scoreCompact(
                                  color: FzColors.accent,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user != null ? 'You' : 'Guest',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              balanceAsync.when(
                                data: (balance) => Text(
                                  '$balance FET',
                                  style: TextStyle(fontSize: 12, color: muted),
                                ),
                                loading: () => Text(
                                  '...',
                                  style: TextStyle(fontSize: 12, color: muted),
                                ),
                                error: (_, st) => Text(
                                  '— FET',
                                  style: TextStyle(fontSize: 12, color: muted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'RANKINGS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: muted,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: rest.length,
                  itemBuilder: (context, index) {
                    final entry = rest[index];
                    return _RankRow(
                      rank: (entry['rank'] as num?)?.toInt() ?? index + 4,
                      name: entry['name']?.toString() ?? 'Fan',
                      fet: entry['fet']?.toString() ?? '0',
                      level: (entry['level'] as num?)?.toInt(),
                    );
                  },
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }
}

class _PodiumItem extends StatelessWidget {
  const _PodiumItem({
    required this.rank,
    required this.name,
    required this.score,
    required this.height,
  });
  final int rank;
  final String name;
  final String score;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = {
      1: FzColors.amber,
      2: const Color(0xFFC0C0C0),
      3: const Color(0xFFCD7F32),
    };
    final c = colors[rank]!;

    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: c, width: 2),
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0] : '?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          score,
          style: FzTypography.scoreCompact(
            color: Theme.of(context).brightness == Brightness.dark
                ? FzColors.darkMuted
                : FzColors.lightMuted,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: c.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text('#$rank', style: FzTypography.scoreMedium(color: c)),
          ),
        ),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.name,
    required this.fet,
    this.level,
  });
  final int rank;
  final String name;
  final String fet;
  final int? level;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '$rank',
              style: FzTypography.scoreCompact(color: muted),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark ? FzColors.darkSurface3 : FzColors.lightSurface3,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0] : '?',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Text(fet, style: FzTypography.scoreCompact(color: FzColors.coral)),
          const SizedBox(width: 4),
          Text('FET', style: TextStyle(fontSize: 9, color: muted)),
          // Show level badge if available
          if (level != null && level! > 0) ...[
            const SizedBox(width: 8),
            FanLevelBadge(
              level: level!,
              title: '',
              colorValue: _levelColorValue(level),
              compact: true,
            ),
          ],
        ],
      ),
    );
  }

  static int _levelColorValue(int? level) {
    switch (level) {
      case 1:
        return 0xFFA8A29E; // Stone muted
      case 2:
        return 0xFF98FF98; // Mint Green (success)
      case 3:
        return 0xFF22D3EE; // Cyan (accent)
      case 4:
        return 0xFF2563EB; // Blue (secondary)
      case 5:
        return 0xFFFF7F50; // Coral
      case 6:
        return 0xFFEF4444; // Red (danger)
      case 7:
        return 0xFFFFD700; // Gold crown
      default:
        return 0xFFA8A29E;
    }
  }
}

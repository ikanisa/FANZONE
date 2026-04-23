import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../services/leaderboard_service.dart';
import '../../../services/wallet_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/state_view.dart';
import '../widgets/leaderboard_widgets.dart';
import '../../../widgets/common/fz_glass_loader.dart';

/// Canonical leaderboard screen aligned to the reference UI.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  @override
  Widget build(BuildContext context) {
    final leaderboardAsync = ref.watch(globalLeaderboardProvider);
    final userRankAsync = ref.watch(userRankProvider);
    final balanceAsync = ref.watch(walletServiceProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final borderColor = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final surfaceColor = isDark ? FzColors.darkSurface : FzColors.lightSurface;
    final surface2Color = isDark
        ? FzColors.darkSurface2
        : FzColors.lightSurface2;
    final width = MediaQuery.sizeOf(context).width;
    final pinnedBottomOffset = width >= 1024 ? 24.0 : 86.0;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        toolbarHeight: 82,
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: borderColor, width: 1)),
        titleSpacing: 16,
        title: Text(
          'Leaderboard',
          style: FzTypography.display(
            size: 34,
            color: textColor,
            letterSpacing: 0.4,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(18),
          child: SizedBox(height: 18),
        ),
      ),
      body: leaderboardAsync.when(
        loading: () => const FzGlassLoader(message: 'Syncing...'),
        error: (error, stackTrace) => StateView.error(
          title: 'Could not load leaderboard',
          onRetry: () => ref.invalidate(globalLeaderboardProvider),
        ),
        data: (rankings) {
          final standardEntries = _resolveEntries(rankings);
          final pinnedCard = PinnedUserCard(
            rankAsync: userRankAsync,
            balanceAsync: balanceAsync,
            bottomOffset: pinnedBottomOffset,
          );

          if (standardEntries.isEmpty) {
            return StateView.empty(
              title: 'No rankings yet',
              subtitle: 'Rankings will appear once users start earning FET.',
              icon: LucideIcons.trophy,
            );
          }

          final podium = standardEntries.take(3).toList(growable: false);
          final rows = standardEntries.skip(3).toList(growable: false);

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Stack(
              key: const ValueKey<String>('global'),
              children: [
                ListView(
                  padding: const EdgeInsets.only(bottom: 188),
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                      decoration: BoxDecoration(
                        color: surface2Color,
                        border: Border(
                          bottom: BorderSide(color: borderColor, width: 1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (podium.length > 1)
                            PodiumItem(
                              rank: podium[1].rank,
                              name: podium[1].name,
                              fet: podium[1].fetLabel,
                              pedestalHeight: 112,
                            ),
                          if (podium.length > 1) const SizedBox(width: 8),
                          PodiumItem(
                            rank: podium[0].rank,
                            name: podium[0].name,
                            fet: podium[0].fetLabel,
                            pedestalHeight: 144,
                          ),
                          if (podium.length > 2) const SizedBox(width: 8),
                          if (podium.length > 2)
                            PodiumItem(
                              rank: podium[2].rank,
                              name: podium[2].name,
                              fet: podium[2].fetLabel,
                              pedestalHeight: 96,
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Column(
                        children: [
                          for (final entry in rows) ...[
                            LeaderboardRow(entry: entry),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                pinnedCard,
              ],
            ),
          );
        },
      ),
    );
  }

  List<StandardLeaderboardEntry> _resolveEntries(
    List<Map<String, dynamic>> rankings,
  ) {
    final resolved = <StandardLeaderboardEntry>[];
    for (final row in rankings) {
      resolved.add(
        StandardLeaderboardEntry(
          rank: (row['rank'] as num?)?.toInt() ?? resolved.length + 1,
          name: row['name']?.toString() ?? 'Fan',
          fetValue: _coerceInt(row['fet']),
        ),
      );
    }
    return resolved;
  }

  int _coerceInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

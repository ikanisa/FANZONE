import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/league_constants.dart';
import '../../../models/competition_model.dart';
import '../../../providers/competitions_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_animated_entry.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_shimmer.dart';
import '../../../widgets/common/state_view.dart';

/// All Leagues screen — shows every tier-1 league outside the Top 5
/// European countries, grouped by region.
class AllLeaguesScreen extends ConsumerWidget {
  const AllLeaguesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final otherAsync = ref.watch(otherLeaguesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ALL LEAGUES',
          style: FzTypography.display(size: 24, color: textColor),
        ),
      ),
      body: RefreshIndicator(
        color: FzColors.accent,
        onRefresh: () async {
          unawaited(HapticFeedback.mediumImpact());
          ref.invalidate(otherLeaguesProvider);
          await ref.read(otherLeaguesProvider.future);
        },
        child: otherAsync.when(
          data: (leagues) {
            if (leagues.isEmpty) {
              return CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: StateView.empty(
                      title: 'No other leagues',
                      subtitle: 'Only the Top 5 European leagues are available right now.',
                      icon: LucideIcons.trophy,
                    ),
                  ),
                ],
              );
            }

            // Group by region
            final grouped = _groupByRegion(leagues);
            final regionOrder = ['europe', 'africa', 'americas', 'global'];

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              itemCount: regionOrder.length,
              itemBuilder: (context, regionIndex) {
                final regionKey = regionOrder[regionIndex];
                final regionLeagues = grouped[regionKey];
                if (regionLeagues == null || regionLeagues.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (regionIndex > 0) const SizedBox(height: 24),
                    // Region header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: FzColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _regionIcon(regionKey),
                            size: 14,
                            color: FzColors.accent,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _regionLabel(regionKey).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: FzColors.accent,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(${regionLeagues.length})',
                            style: TextStyle(
                              fontSize: 10,
                              color: muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // League list
                    ...regionLeagues.asMap().entries.map((entry) {
                      final i = entry.key;
                      final league = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: i < regionLeagues.length - 1 ? 6 : 0,
                        ),
                        child: FzAnimatedEntry(
                          index: i,
                          child: _LeagueTile(
                            league: league,
                            onTap: () =>
                                context.push('/league/${league.id}'),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            );
          },
          loading: () => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(
                6,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: FzShimmer(width: double.infinity, height: 56, borderRadius: 14),
                ),
              ),
            ),
          ),
          error: (error, _) => CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: StateView.fromError(
                  error,
                  onRetry: () => ref.invalidate(otherLeaguesProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, List<CompetitionModel>> _groupByRegion(
    List<CompetitionModel> leagues,
  ) {
    final grouped = <String, List<CompetitionModel>>{};
    for (final league in leagues) {
      final region = league.region ?? 'global';
      grouped.putIfAbsent(region, () => []).add(league);
    }
    // Sort each group alphabetically
    for (final list in grouped.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    return grouped;
  }

  String _regionLabel(String regionKey) {
    switch (regionKey) {
      case 'europe':
        return 'Other Europe';
      case 'africa':
        return 'Africa';
      case 'americas':
        return 'Americas';
      default:
        return 'International';
    }
  }

  IconData _regionIcon(String regionKey) {
    switch (regionKey) {
      case 'europe':
        return LucideIcons.star;
      case 'africa':
        return LucideIcons.sun;
      case 'americas':
        return LucideIcons.globe;
      default:
        return LucideIcons.globe2;
    }
  }
}

// ═════════════════════════════════════════════════════════════════
// League Tile
// ═════════════════════════════════════════════════════════════════

class _LeagueTile extends StatelessWidget {
  const _LeagueTile({required this.league, required this.onTap});

  final CompetitionModel league;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final flag = flagForCountry(league.country);

    return FzCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // Flag circle
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? FzColors.darkSurface : FzColors.lightSurface,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
              ),
            ),
            child: Center(
              child: Text(flag, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  league.shortName.isNotEmpty ? league.shortName : league.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? FzColors.darkText : FzColors.lightText,
                  ),
                ),
                Text(
                  league.country,
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: muted.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/matches_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_badge.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/fz_glass_loader.dart';
import '../../../widgets/common/state_view.dart';
import '../../auth/widgets/sign_in_required_sheet.dart';

class JackpotChallengeScreen extends ConsumerWidget {
  const JackpotChallengeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final end = now.add(const Duration(days: 7));
    final filter = MatchesFilter(
      dateFrom: now.toIso8601String(),
      dateTo: end.toIso8601String(),
      limit: 10,
      ascending: true,
    );
    final matchesAsync = ref.watch(matchesProvider(filter));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 132),
            children: [
              Text(
                'Jackpots',
                style: FzTypography.display(
                  size: 34,
                  color: textColor,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [FzColors.secondary, FzColors.primary],
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      bottom: -40,
                      child: Icon(
                        LucideIcons.trophy,
                        size: 180,
                        color: Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FzBadge(
                          label: 'WEEKLY POOL',
                          variant: FzBadgeVariant.ghost,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          '50,000 FET',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                            height: 0.95,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.zap,
                                size: 12,
                                color: Colors.black,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'ENDS: 2d 14h',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                  letterSpacing: 1.1,
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
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '10 Matches',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                  FzBadge(
                    label: '0/10 predicted',
                    variant: FzBadgeVariant.ghost,
                    textColor: muted,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              matchesAsync.when(
                data: (matches) {
                  final visible = matches
                      .where((match) => match.isUpcoming)
                      .take(10)
                      .toList();
                  if (visible.isEmpty) {
                    return StateView.empty(
                      title: 'No jackpot matches yet',
                      subtitle:
                          'The weekly pool will show eligible matches here.',
                      icon: LucideIcons.trophy,
                    );
                  }

                  return Column(
                    children: [
                      for (int index = 0; index < visible.length; index++)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: index == visible.length - 1 ? 0 : 12,
                          ),
                          child: _JackpotMatchTile(match: visible[index]),
                        ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: FzGlassLoader(message: 'Syncing...'),
                ),
                error: (_, _) => StateView.error(
                  title: 'Could not load jackpot matches',
                  onRetry: () => ref.invalidate(matchesProvider(filter)),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: (isDark ? FzColors.darkSurface : FzColors.lightSurface)
                    .withValues(alpha: 0.92),
                border: Border(
                  top: BorderSide(
                    color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: FilledButton.icon(
                  onPressed: () {
                    if (!ref.read(isAuthenticatedProvider)) {
                      showSignInRequiredSheet(
                        context,
                        title: 'Verify to Enter Jackpot',
                        message:
                            'Verify your number via WhatsApp to submit your jackpot entry.',
                        from: '/jackpot',
                      );
                      return;
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: FzColors.coral,
                    foregroundColor: FzColors.darkBg,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  icon: const Icon(LucideIcons.check, size: 18),
                  label: const Text(
                    'SUBMIT 500 FET',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JackpotMatchTile extends StatelessWidget {
  const _JackpotMatchTile({required this.match});

  final dynamic match;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return FzCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('⚽', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${match.homeTeam} vs ${match.awayTeam}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${match.competitionId.toString().toUpperCase()} · ${match.kickoffLabel}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: muted,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? FzColors.darkBorder : FzColors.lightBorder,
              ),
            ),
            child: Icon(LucideIcons.chevronRight, size: 18, color: muted),
          ),
        ],
      ),
    );
  }
}

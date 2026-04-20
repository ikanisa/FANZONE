import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../providers/matches_provider.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/common/fz_glass_loader.dart';

/// Weekly Jackpot Challenge screen — 10-match prediction challenge.
///
/// Matches original design reference (JackpotChallenge.tsx):
/// - Sticky top prize banner
/// - 10 match predictions grid
/// - Progressive reward tiers (5+, 7+, 10/10)
/// - Weekly deadline countdown
class JackpotChallengeScreen extends ConsumerWidget {
  const JackpotChallengeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 68,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'WEEKLY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: muted,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Jackpot Challenge',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          // ── Hero Prize Banner ──
          FzCard(
            padding: EdgeInsets.zero,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    FzColors.primary.withValues(alpha: 0.12),
                    FzColors.teal.withValues(alpha: 0.12),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(
                    LucideIcons.trophy,
                    color: FzColors.primary,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'JACKPOT PRIZE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: muted,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '10,000 FET',
                    style: FzTypography.score(
                      size: 36,
                      weight: FontWeight.w700,
                      color: FzColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Predict all 10 matches correctly',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Reward Tiers ──
          Text(
            'REWARD TIERS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: muted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TierCard(
                  correct: '5+',
                  reward: '100 FET',
                  color: FzColors.coral,
                  textColor: textColor,
                  muted: muted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TierCard(
                  correct: '7+',
                  reward: '500 FET',
                  color: FzColors.blue,
                  textColor: textColor,
                  muted: muted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TierCard(
                  correct: '10/10',
                  reward: 'JACKPOT',
                  color: FzColors.primary,
                  textColor: textColor,
                  muted: muted,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── This Week's Matches ──
          Text(
            'THIS WEEK\'S MATCHES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: muted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final now = DateTime.now();
              final weekEnd = now.add(const Duration(days: 7));
              final filter = MatchesFilter(
                dateFrom: now.toIso8601String(),
                dateTo: weekEnd.toIso8601String(),
                limit: 10,
              );
              final matchesAsync = ref.watch(matchesProvider(filter));

              return matchesAsync.when(
                data: (matches) {
                  if (matches.isEmpty) {
                    return StateView.empty(
                      title: 'No jackpot fixtures yet',
                      subtitle:
                          'The weekly jackpot will appear here when the next set of eligible matches is published.',
                    );
                  }

                  final matchNames = matches
                      .take(10)
                      .map((m) => '${m.homeTeam} vs ${m.awayTeam}')
                      .toList();

                  return Column(
                    children: matchNames
                        .asMap()
                        .entries
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _MatchPredictionCard(
                              index: entry.key + 1,
                              match: entry.value,
                              textColor: textColor,
                              muted: muted,
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: const FzGlassLoader(message: 'Syncing...'),
                ),
                error: (error, _) => StateView.fromError(
                  error,
                  onRetry: () => ref.invalidate(matchesProvider(filter)),
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // ── Rules ──
          Text(
            'CHALLENGE RULES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: muted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          const FzCard(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RuleItem(text: 'Free to enter — no FET stake required.'),
                _RuleItem(
                  text: 'Predict outcome (Home / Draw / Away) for each match.',
                ),
                _RuleItem(
                  text:
                      'All predictions must be locked before Saturday 12:00 CET.',
                ),
                _RuleItem(text: 'Correct 5+ = 100 FET. Correct 7+ = 500 FET.'),
                _RuleItem(
                  text:
                      'All 10 correct = Jackpot (split equally if multiple winners).',
                ),
                _RuleItem(text: 'Results settled Sunday 23:59 CET.'),
              ],
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: null,
              icon: const Icon(LucideIcons.zap, size: 16),
              label: const Text('Weekly Jackpot Opens Soon'),
              style: FilledButton.styleFrom(
                backgroundColor: FzColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.correct,
    required this.reward,
    required this.color,
    required this.textColor,
    required this.muted,
  });

  final String correct;
  final String reward;
  final Color color;
  final Color textColor;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                correct,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            reward,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text('correct', style: TextStyle(fontSize: 10, color: muted)),
        ],
      ),
    );
  }
}

class _MatchPredictionCard extends StatefulWidget {
  const _MatchPredictionCard({
    required this.index,
    required this.match,
    required this.textColor,
    required this.muted,
  });

  final int index;
  final String match;
  final Color textColor;
  final Color muted;

  @override
  State<_MatchPredictionCard> createState() => _MatchPredictionCardState();
}

class _MatchPredictionCardState extends State<_MatchPredictionCard> {
  String? _selected; // 'home', 'draw', 'away'

  @override
  Widget build(BuildContext context) {
    return FzCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _selected != null
                  ? FzColors.primary.withValues(alpha: 0.15)
                  : FzColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${widget.index}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _selected != null ? FzColors.primary : widget.muted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.match,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.textColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _OutcomeChip(
            label: 'H',
            selected: _selected == 'home',
            onTap: () => setState(() => _selected = 'home'),
          ),
          const SizedBox(width: 4),
          _OutcomeChip(
            label: 'D',
            selected: _selected == 'draw',
            onTap: () => setState(() => _selected = 'draw'),
          ),
          const SizedBox(width: 4),
          _OutcomeChip(
            label: 'A',
            selected: _selected == 'away',
            onTap: () => setState(() => _selected = 'away'),
          ),
        ],
      ),
    );
  }
}

class _OutcomeChip extends StatelessWidget {
  const _OutcomeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: selected
              ? FzColors.primary
              : FzColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : FzColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  const _RuleItem({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.checkCircle, size: 14, color: FzColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? FzColors.darkText : FzColors.lightText,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

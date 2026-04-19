import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../models/daily_challenge_model.dart';
import '../../../models/pool.dart';
import '../../../providers/currency_provider.dart';
import '../../../services/daily_challenge_service.dart';
import '../../../services/pool_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';

class PredictionHistoryScreen extends ConsumerWidget {
  const PredictionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poolsAsync = ref.watch(myEntriesProvider);
    final dailyHistoryAsync = ref.watch(dailyChallengeHistoryProvider);
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkText
        : FzColors.lightText;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'PREDICTION HISTORY',
          style: FzTypography.display(size: 28, color: textColor),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'POOL ENTRIES',
            style: FzTypography.sectionLabel(Theme.of(context).brightness),
          ),
          const SizedBox(height: 10),
          poolsAsync.when(
            data: (entries) {
              if (entries.isEmpty) {
                return StateView.empty(
                  title: 'No pool history yet',
                  subtitle: 'Join a challenge to start tracking your record.',
                  icon: LucideIcons.swords,
                );
              }
              return Column(
                children: entries
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PoolHistoryCard(
                          entry: entry,
                          currency: currency,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => StateView.error(
              title: 'Could not load pool history',
              onRetry: () => ref.invalidate(myEntriesProvider),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'DAILY CHALLENGE HISTORY',
            style: FzTypography.sectionLabel(Theme.of(context).brightness),
          ),
          const SizedBox(height: 10),
          dailyHistoryAsync.when(
            data: (entries) {
              if (entries.isEmpty) {
                return const FzCard(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Daily challenge entries will appear here after your first submission.',
                  ),
                );
              }
              return Column(
                children: entries
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DailyHistoryCard(
                          entry: entry,
                          currency: currency,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => StateView.error(
              title: 'Could not load daily challenge history',
              onRetry: () => ref.invalidate(dailyChallengeHistoryProvider),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _PoolHistoryCard extends StatelessWidget {
  const _PoolHistoryCard({required this.entry, required this.currency});

  final PoolEntry entry;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkMuted
        : FzColors.lightMuted;

    return FzCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.predictedHomeScore}–${entry.predictedAwayScore}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Stake ${formatFET(entry.stake, currency)}',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                entry.status.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: FzColors.accent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                formatFET(entry.payout, currency),
                style: FzTypography.scoreCompact(color: FzColors.amber),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyHistoryCard extends StatelessWidget {
  const _DailyHistoryCard({required this.entry, required this.currency});

  final DailyChallengeEntry entry;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkMuted
        : FzColors.lightMuted;

    return FzCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.predictedHomeScore}–${entry.predictedAwayScore}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.submittedAt == null
                      ? 'Daily challenge'
                      : '${entry.submittedAt!.day}/${entry.submittedAt!.month}/${entry.submittedAt!.year}',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                entry.result.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: FzColors.accent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                formatFET(entry.payoutFet, currency),
                style: FzTypography.scoreCompact(color: FzColors.success),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

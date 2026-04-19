import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../models/daily_challenge_model.dart';
import '../../../providers/currency_provider.dart';
import '../../../services/daily_challenge_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../services/product_analytics_service.dart';

class DailyChallengeScreen extends ConsumerStatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  ConsumerState<DailyChallengeScreen> createState() =>
      _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends ConsumerState<DailyChallengeScreen> {
  final _homeController = TextEditingController(text: '1');
  final _awayController = TextEditingController(text: '0');
  bool _submitting = false;
  String? _validationError;

  @override
  void dispose() {
    _homeController.dispose();
    _awayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challengeAsync = ref.watch(dailyChallengeServiceProvider);
    final entryAsync = ref.watch(myDailyEntryProvider);
    final historyAsync = ref.watch(dailyChallengeHistoryProvider);
    final currency = ref.watch(userCurrencyProvider).valueOrNull ?? 'EUR';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? FzColors.darkText : FzColors.lightText;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'DAILY CHALLENGE',
          style: FzTypography.display(size: 28, color: textColor),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          challengeAsync.when(
            data: (challenge) {
              if (challenge == null) {
                return StateView.empty(
                  title: 'No daily challenge live',
                  subtitle: 'Check back on the next matchday.',
                  icon: LucideIcons.calendar,
                );
              }

              return FzCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: FzColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            LucideIcons.calendar,
                            color: FzColors.accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                challenge.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                challenge.matchName,
                                style: TextStyle(fontSize: 12, color: muted),
                              ),
                            ],
                          ),
                        ),
                        _RewardPill(
                          label: formatFETSigned(
                            challenge.rewardFet,
                            currency,
                            positive: true,
                          ),
                        ),
                      ],
                    ),
                    if (challenge.description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        challenge.description,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                    if (challenge.matchId.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.push('/match/${challenge.matchId}'),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('Open match'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    entryAsync.when(
                      data: (entry) => entry == null
                          ? _buildEntryForm(context, challenge, muted, currency)
                          : _CurrentEntryCard(entry: entry),
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (_, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Could not load your entry status yet.',
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () =>
                                ref.invalidate(myDailyEntryProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => StateView.error(
              title: 'Daily challenge unavailable',
              onRetry: () => ref.invalidate(dailyChallengeServiceProvider),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'RECENT ENTRIES',
            style: FzTypography.sectionLabel(Theme.of(context).brightness),
          ),
          const SizedBox(height: 10),
          historyAsync.when(
            data: (entries) {
              if (entries.isEmpty) {
                return FzCard(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Your recent daily challenge entries will appear here.',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                );
              }
              return Column(
                children: entries
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _HistoryEntryCard(
                          entry: entry,
                          currency: currency,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => FzCard(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Loading recent entries...',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ),
            error: (_, _) => FzCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recent entry history is unavailable right now.',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(dailyChallengeHistoryProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildEntryForm(
    BuildContext context,
    DailyChallenge challenge,
    Color muted,
    String currency,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Submit today’s prediction',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _homeController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: 'Home'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _awayController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: 'Away'),
              ),
            ),
          ],
        ),
        if (_validationError != null) ...[
          const SizedBox(height: 10),
          Text(
            _validationError!,
            style: const TextStyle(
              fontSize: 12,
              color: FzColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          'Exact score pays ${formatFET(challenge.bonusExactFet, currency)}. Correct result pays ${formatFET(challenge.rewardFet, currency)}.',
          style: TextStyle(fontSize: 12, color: muted),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _submitting
                ? null
                : () => _submitPrediction(context, challenge),
            icon: _submitting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.send, size: 16),
            label: Text(_submitting ? 'Submitting...' : 'Submit prediction'),
          ),
        ),
      ],
    );
  }

  Future<void> _submitPrediction(
    BuildContext context,
    DailyChallenge challenge,
  ) async {
    final home = int.tryParse(_homeController.text.trim());
    final away = int.tryParse(_awayController.text.trim());

    if (home == null || away == null) {
      setState(() {
        _validationError = 'Enter a valid score for both teams.';
      });
      return;
    }

    if (home < 0 || away < 0) {
      setState(() {
        _validationError = 'Scores cannot be negative.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _validationError = null;
    });
    try {
      await ref
          .read(dailyChallengeServiceProvider.notifier)
          .submitPrediction(
            challengeId: challenge.id,
            homeScore: home,
            awayScore: away,
          );
      if (!context.mounted) return;
      ProductAnalytics.dailyChallengeEntered(challengeId: challenge.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily challenge prediction submitted.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _CurrentEntryCard extends StatelessWidget {
  const _CurrentEntryCard({required this.entry});

  final DailyChallengeEntry entry;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkMuted
        : FzColors.lightMuted;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FzColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FzColors.success.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your entry is locked in',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '${entry.predictedHomeScore}–${entry.predictedAwayScore}',
            style: FzTypography.scoreLarge(color: FzColors.success),
          ),
          const SizedBox(height: 4),
          Text(
            'Result: ${entry.result.replaceAll('_', ' ')}',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ),
    );
  }
}

class _HistoryEntryCard extends StatelessWidget {
  const _HistoryEntryCard({required this.entry, required this.currency});

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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.submittedAt == null
                      ? 'Submitted'
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
                style: FzTypography.scoreCompact(color: FzColors.amber),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardPill extends StatelessWidget {
  const _RewardPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: FzColors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: FzColors.amber,
        ),
      ),
    );
  }
}

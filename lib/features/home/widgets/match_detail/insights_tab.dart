part of '../../screens/match_detail_screen.dart';

class _InsightsTab extends ConsumerWidget {
  const _InsightsTab({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? FzColors.darkMuted : FzColors.lightMuted;
    final analysisAsync = ref.watch(matchAiAnalysisProvider(match.id));

    return analysisAsync.when(
      data: (analysis) {
        if (analysis == null || !analysis.isValid) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FzCard(
                padding: const EdgeInsets.all(18),
                borderColor: FzColors.primary.withValues(alpha: 0.18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: FzColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 18,
                            color: FzColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Match Insights',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No live AI summary is available for this fixture right now.',
                      style: TextStyle(
                        fontSize: 13,
                        color: muted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [_AiAnalysisCard(analysis: analysis, match: match)],
        );
      },
      loading: () => ListView(
        padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 16),
        children: [
          Column(
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: FzColors.primary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Gathering AI insights...',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: muted,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ],
      ),
      error: (_, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StateView.error(
            title: 'Insights unavailable',
            subtitle: 'Try again in a moment.',
            onRetry: () => ref.invalidate(matchAiAnalysisProvider(match.id)),
          ),
        ],
      ),
    );
  }
}

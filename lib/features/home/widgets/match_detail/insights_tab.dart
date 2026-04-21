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
            padding: const EdgeInsets.all(24),
            children: [
              _MatchInsightsCard(
                content:
                    'No live AI summary is available for this fixture right now.',
                muted: muted,
              ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _MatchInsightsCard(
              content: _resolveInsightCopy(analysis, match),
              muted: muted,
            ),
          ],
        );
      },
      loading: () => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Gathering AI Insights...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: muted,
              ),
            ),
          ],
        ),
      ),
      error: (_, _) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _MatchInsightsCard(
            content: 'Unable to fetch insights. Please try again in a moment.',
            muted: muted,
          ),
        ],
      ),
    );
  }

  String _resolveInsightCopy(MatchAiAnalysis analysis, MatchModel match) {
    final parts = <String>[];
    final narrative = analysis.analysisNarrative?.trim();
    if (narrative != null && narrative.isNotEmpty) {
      parts.add(narrative);
    }
    final formBits = <String>[];
    if (analysis.homeFormSummary?.trim().isNotEmpty ?? false) {
      formBits.add('${match.homeTeam}: ${analysis.homeFormSummary!.trim()}');
    }
    if (analysis.awayFormSummary?.trim().isNotEmpty ?? false) {
      formBits.add('${match.awayTeam}: ${analysis.awayFormSummary!.trim()}');
    }
    if (formBits.isNotEmpty) {
      parts.add(formBits.join(' '));
    }
    final h2h = analysis.h2hSummary?.trim();
    if (h2h != null && h2h.isNotEmpty) {
      parts.add(h2h);
    }
    if (parts.isEmpty && analysis.keyFactors.isNotEmpty) {
      parts.add(
        analysis.keyFactors
            .map(
              (factor) => factor.description.trim().isNotEmpty
                  ? '${factor.factor}: ${factor.description.trim()}'
                  : factor.factor,
            )
            .join(' '),
      );
    }
    if (parts.isEmpty) {
      return 'No live AI summary is available for this fixture right now.';
    }
    return parts.join('\n\n');
  }
}

class _MatchInsightsCard extends StatelessWidget {
  const _MatchInsightsCard({required this.content, required this.muted});

  final String content;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? FzColors.darkText : FzColors.lightText;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? FzColors.darkSurface2 : FzColors.lightSurface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FzColors.primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: FzColors.primary.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: -10,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.sparkles, size: 20, color: FzColors.primary),
              SizedBox(width: 10),
              Text(
                'MATCH INSIGHTS',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: TextStyle(fontSize: 14, color: text, height: 1.6),
          ),
        ],
      ),
    );
  }
}

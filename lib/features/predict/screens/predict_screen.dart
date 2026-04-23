import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../models/match_model.dart';
import '../../../models/prediction_engine_output_model.dart';
import '../../../models/user_prediction_model.dart';
import '../../../providers/competitions_provider.dart';
import '../../../providers/crowd_prediction_provider.dart';
import '../../../providers/matches_provider.dart';
import '../../../services/prediction_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/match/match_list_widgets.dart';
import '../widgets/prediction_entry_sheet.dart';

enum _PredictTab { upcoming, myPicks }

class PredictScreen extends ConsumerStatefulWidget {
  const PredictScreen({super.key});

  @override
  ConsumerState<PredictScreen> createState() => _PredictScreenState();
}

class _PredictScreenState extends ConsumerState<PredictScreen> {
  _PredictTab _activeTab = _PredictTab.upcoming;

  @override
  Widget build(BuildContext context) {
    final upcomingAsync = ref.watch(upcomingMatchesProvider);
    final myPredictionsAsync = ref.watch(myPredictionsProvider);
    final muted = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkMuted
        : FzColors.lightMuted;
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? FzColors.darkText
        : FzColors.lightText;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Predict',
                        style: FzTypography.display(
                          size: 36,
                          color: textColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Free football picks powered by simple historical form.',
                        style: TextStyle(
                          fontSize: 14,
                          color: muted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FzCard(
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: _PredictTabChip(
                      label: 'Upcoming',
                      selected: _activeTab == _PredictTab.upcoming,
                      trailingCount: upcomingAsync.valueOrNull?.length,
                      onTap: () =>
                          setState(() => _activeTab = _PredictTab.upcoming),
                    ),
                  ),
                  Expanded(
                    child: _PredictTabChip(
                      label: 'My picks',
                      selected: _activeTab == _PredictTab.myPicks,
                      trailingCount: myPredictionsAsync.valueOrNull?.length,
                      onTap: () =>
                          setState(() => _activeTab = _PredictTab.myPicks),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_activeTab == _PredictTab.upcoming)
              upcomingAsync.when(
                data: (matches) {
                  if (matches.isEmpty) {
                    return StateView.empty(
                      title: 'No matches open for picks',
                      subtitle:
                          'Upcoming fixtures will appear here once they are imported.',
                      icon: LucideIcons.calendar,
                    );
                  }

                  return Column(
                    children: [
                      for (var index = 0; index < matches.length; index++) ...[
                        _PredictionMatchCard(match: matches[index]),
                        if (index < matches.length - 1)
                          const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
                loading: () => const _PredictionListSkeleton(),
                error: (_, _) => StateView.error(
                  title: 'Could not load prediction fixtures',
                  subtitle: 'Try again in a moment.',
                  onRetry: () => ref.invalidate(upcomingMatchesProvider),
                ),
              )
            else
              _MyPredictionsPanel(
                predictionsAsync: myPredictionsAsync,
              ),
          ],
        ),
      ),
    );
  }
}

class _PredictTabChip extends StatelessWidget {
  const _PredictTabChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailingCount,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? trailingCount;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? FzColors.accent2 : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? FzColors.darkBg : FzColors.darkText,
              ),
            ),
            if (trailingCount != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? FzColors.darkBg.withValues(alpha: 0.12)
                      : FzColors.darkSurface3,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$trailingCount',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? FzColors.darkBg : FzColors.darkMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PredictionMatchCard extends ConsumerWidget {
  const _PredictionMatchCard({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final competition = ref.watch(competitionProvider(match.competitionId));
    final engineOutput = ref.watch(predictionEngineOutputProvider(match.id));
    final myPrediction = ref.watch(myPredictionForMatchProvider(match.id));
    final crowd = ref.watch(crowdPredictionProvider(match.id));

    final competitionLabel =
        competition.valueOrNull?.shortName.isNotEmpty == true
        ? competition.valueOrNull!.shortName
        : competition.valueOrNull?.name ?? match.competitionId.toUpperCase();
    final engine = engineOutput.valueOrNull;
    final prediction = myPrediction.valueOrNull;
    final crowdData = crowd.valueOrNull;

    return FzCard(
      padding: const EdgeInsets.all(16),
      onTap: () => context.push('/match/${match.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  competitionLabel,
                  style: FzTypography.metaLabel(color: FzColors.darkMuted),
                ),
              ),
              Text(
                match.kickoffLabel,
                style: FzTypography.metaLabel(
                  color: match.isLive ? FzColors.danger : FzColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _TeamTile(
                  name: match.homeTeam,
                  logoUrl: match.homeLogoUrl,
                  alignEnd: false,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  match.scoreDisplay ?? 'VS',
                  style: FzTypography.scoreLarge(
                    color: match.isLive ? FzColors.danger : FzColors.darkText,
                  ),
                ),
              ),
              Expanded(
                child: _TeamTile(
                  name: match.awayTeam,
                  logoUrl: match.awayLogoUrl,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (engine != null) ...[
            _EngineStrip(engine: engine),
            const SizedBox(height: 12),
          ],
          if (crowdData != null) ...[
            _ConsensusStrip(crowd: crowdData),
            const SizedBox(height: 12),
          ],
          if (prediction != null) ...[
            _SavedPredictionBadge(prediction: prediction),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/match/${match.id}'),
                  icon: const Icon(LucideIcons.lineChart, size: 16),
                  label: const Text('Details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FzColors.darkText,
                    side: const BorderSide(color: FzColors.darkBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => showPredictionEntrySheet(
                    context,
                    match: match,
                    engineOutput: engine,
                    existingPrediction: prediction,
                  ),
                  icon: Icon(
                    prediction == null
                        ? LucideIcons.target
                        : LucideIcons.pencil,
                    size: 16,
                  ),
                  label: Text(prediction == null ? 'Make pick' : 'Edit pick'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FzColors.accent2,
                    foregroundColor: FzColors.darkText,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamTile extends StatelessWidget {
  const _TeamTile({
    required this.name,
    required this.logoUrl,
    required this.alignEnd,
  });

  final String name;
  final String? logoUrl;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignEnd
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        if (alignEnd)
          Flexible(
            child: Text(
              name,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: FzColors.darkText,
              ),
            ),
          ),
        if (alignEnd) const SizedBox(width: 10),
        TeamAvatar(name: name, logoUrl: logoUrl, size: 34),
        if (!alignEnd) const SizedBox(width: 10),
        if (!alignEnd)
          Flexible(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: FzColors.darkText,
              ),
            ),
          ),
      ],
    );
  }
}

class _EngineStrip extends StatelessWidget {
  const _EngineStrip({required this.engine});

  final PredictionEngineOutputModel engine;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FzColors.darkSurface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FzColors.darkBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Engine outlook',
                style: FzTypography.metaLabel(color: FzColors.darkMuted),
              ),
              const Spacer(),
              Text(
                engine.confidenceLabel.toUpperCase(),
                style: FzTypography.metaLabel(color: FzColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _TinyMetric(label: '1', value: engine.homeWinScore),
              const SizedBox(width: 8),
              _TinyMetric(label: 'X', value: engine.drawScore),
              const SizedBox(width: 8),
              _TinyMetric(label: '2', value: engine.awayWinScore),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Model score ${engine.predictedHomeGoals ?? 0}-${engine.predictedAwayGoals ?? 0}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: FzColors.darkText,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TinyMetric extends StatelessWidget {
  const _TinyMetric({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: FzColors.darkSurface3,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: FzTypography.metaLabel(color: FzColors.darkMuted),
            ),
            const SizedBox(height: 4),
            Text(
              '${(value * 100).round()}%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: FzColors.darkText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsensusStrip extends StatelessWidget {
  const _ConsensusStrip({required this.crowd});

  final CrowdPrediction crowd;

  @override
  Widget build(BuildContext context) {
    final (home, draw, away) = crowd.normalized;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FzColors.darkSurface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FzColors.darkBorder),
      ),
      child: Row(
        children: [
          Text(
            'Crowd',
            style: FzTypography.metaLabel(color: FzColors.darkMuted),
          ),
          const Spacer(),
          Text(
            '1 $home%  ·  X $draw%  ·  2 $away%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: FzColors.darkText,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedPredictionBadge extends StatelessWidget {
  const _SavedPredictionBadge({required this.prediction});

  final UserPredictionModel prediction;

  @override
  Widget build(BuildContext context) {
    final pickBits = <String>[
      if (prediction.predictedResultCode != null)
        '1X2 ${prediction.predictedResultCode}',
      if (prediction.predictedOver25 != null)
        prediction.predictedOver25! ? 'Over 2.5' : 'Under 2.5',
      if (prediction.predictedBtts != null)
        prediction.predictedBtts! ? 'BTTS Yes' : 'BTTS No',
      if (prediction.scorelineLabel != null) prediction.scorelineLabel!,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FzColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FzColors.accent.withValues(alpha: 0.24)),
      ),
      child: Text(
        'Saved: ${pickBits.join(' · ')}',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: FzColors.darkText,
        ),
      ),
    );
  }
}

class _MyPredictionsPanel extends ConsumerWidget {
  const _MyPredictionsPanel({required this.predictionsAsync});

  final AsyncValue<List<UserPredictionModel>> predictionsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return predictionsAsync.when(
      data: (predictions) {
        if (predictions.isEmpty) {
          return StateView.empty(
            title: 'No picks saved yet',
            subtitle:
                'Choose a match from the upcoming list and save your first prediction.',
            icon: LucideIcons.target,
          );
        }

        final lookupKey = predictions
            .map((prediction) => prediction.matchId.trim())
            .where((matchId) => matchId.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();

        final matchesLookupAsync = ref.watch(
          predictionMatchLookupProvider(lookupKey.join(',')),
        );

        return matchesLookupAsync.when(
          data: (matchById) {
            final activePredictions = predictions
                .where((prediction) {
                  final match = matchById[prediction.matchId];
                  return match != null && !match.isFinished;
                })
                .toList(growable: false);
            final settledPredictions = predictions
                .where((prediction) {
                  final match = matchById[prediction.matchId];
                  return match == null || match.isFinished;
                })
                .toList(growable: false);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (activePredictions.isNotEmpty) ...[
                  Text(
                    'Active picks',
                    style: FzTypography.display(
                      size: 22,
                      color: FzColors.darkText,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (
                    var index = 0;
                    index < activePredictions.length;
                    index++
                  ) ...[
                    _PredictionMatchCard(
                      match: matchById[activePredictions[index].matchId]!,
                    ),
                    if (index < activePredictions.length - 1)
                      const SizedBox(height: 12),
                  ],
                ],
                if (settledPredictions.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text(
                    'Recent scored picks',
                    style: FzTypography.display(
                      size: 22,
                      color: FzColors.darkText,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FzCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (
                          var index = 0;
                          index < settledPredictions.length;
                          index++
                        ) ...[
                          if (index > 0)
                            const Divider(height: 1, color: FzColors.darkBorder),
                          _SettledPredictionRow(
                            prediction: settledPredictions[index],
                            match: matchById[settledPredictions[index].matchId],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const _PredictionListSkeleton(),
          error: (_, _) => StateView.error(
            title: 'Could not load saved predictions',
            subtitle: 'Try again in a moment.',
            onRetry: () => ref.invalidate(myPredictionsProvider),
          ),
        );
      },
      loading: () => const _PredictionListSkeleton(),
      error: (_, _) => StateView.error(
        title: 'Could not load saved predictions',
        subtitle: 'Try again in a moment.',
        onRetry: () => ref.invalidate(myPredictionsProvider),
      ),
    );
  }
}

class _SettledPredictionRow extends StatelessWidget {
  const _SettledPredictionRow({required this.prediction, this.match});

  final UserPredictionModel prediction;
  final MatchModel? match;

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[
      if (prediction.predictedResultCode != null)
        '1X2 ${prediction.predictedResultCode}',
      if (prediction.scorelineLabel != null) prediction.scorelineLabel!,
      'Points ${prediction.pointsAwarded}',
    ].join(' · ');

    final title = match == null
        ? prediction.matchId
        : '${match!.homeTeam} vs ${match!.awayTeam}';
    final trailingLabel = prediction.rewardStatus.toUpperCase();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: FzColors.darkSurface3,
        child: Text(
          '${prediction.pointsAwarded}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: FzColors.accent,
          ),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: FzColors.darkText,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: FzColors.darkMuted),
      ),
      trailing: Text(
        trailingLabel,
        style: FzTypography.metaLabel(color: FzColors.accent),
      ),
    );
  }
}

class _PredictionListSkeleton extends StatelessWidget {
  const _PredictionListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index == 2 ? 0 : 12),
          child: const FzCard(
            padding: EdgeInsets.all(16),
            child: SizedBox(height: 120),
          ),
        ),
      ),
    );
  }
}

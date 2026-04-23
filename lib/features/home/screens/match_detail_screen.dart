import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../features/predict/widgets/prediction_entry_sheet.dart';
import '../../../models/match_model.dart';
import '../../../models/prediction_engine_output_model.dart';
import '../../../models/team_form_feature_model.dart';
import '../../../models/user_prediction_model.dart';
import '../../../providers/competitions_provider.dart';
import '../../../providers/crowd_prediction_provider.dart';
import '../../../providers/matches_provider.dart';
import '../../../providers/standings_provider.dart';
import '../../../services/prediction_service.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../../../widgets/common/fz_card.dart';
import '../../../widgets/common/state_view.dart';
import '../../../widgets/match/match_list_widgets.dart';
import '../../../widgets/match/standings_table.dart';

class MatchDetailScreen extends ConsumerWidget {
  const MatchDetailScreen({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchAsync = ref.watch(matchDetailProvider(matchId));

    return matchAsync.when(
      data: (match) {
        if (match == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Match')),
            body: StateView.empty(
              title: 'Match not found',
              subtitle: 'Return to fixtures to choose another one.',
              icon: LucideIcons.calendar,
            ),
          );
        }

        final competitionAsync = ref.watch(
          competitionProvider(match.competitionId),
        );
        final engineAsync = ref.watch(predictionEngineOutputProvider(match.id));
        final myPredictionAsync = ref.watch(
          myPredictionForMatchProvider(match.id),
        );
        final crowdAsync = ref.watch(crowdPredictionProvider(match.id));
        final formAsync = ref.watch(matchFormFeaturesProvider(match.id));
        final standingsAsync = ref.watch(
          competitionStandingsProvider(
            CompetitionStandingsFilter(
              competitionId: match.competitionId,
              season: match.season.isEmpty ? null : match.season,
            ),
          ),
        );

        final competition = competitionAsync.valueOrNull;
        final engine = engineAsync.valueOrNull;
        final myPrediction = myPredictionAsync.valueOrNull;
        final crowd = crowdAsync.valueOrNull;
        final formFeatures =
            formAsync.valueOrNull ?? const <TeamFormFeatureModel>[];

        return Scaffold(
          appBar: AppBar(
            title: Text(
              competition?.shortName.isNotEmpty == true
                  ? competition!.shortName
                  : competition?.name ?? 'Match',
            ),
            leading: IconButton(
              tooltip: 'Back',
              onPressed: () => context.pop(),
              icon: const Icon(LucideIcons.chevronLeft),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              _MatchHeroCard(match: match),
              const SizedBox(height: 14),
              if (engine != null)
                _DetailSection(
                  title: 'Prediction engine',
                  child: _EngineDetailCard(engine: engine),
                ),
              if (crowd != null) ...[
                const SizedBox(height: 14),
                _DetailSection(
                  title: 'Community picks',
                  child: _CrowdDetailCard(crowd: crowd),
                ),
              ],
              const SizedBox(height: 14),
              _DetailSection(
                title: 'Your prediction',
                child: _MyPredictionCard(
                  match: match,
                  engine: engine,
                  prediction: myPrediction,
                ),
              ),
              if (formFeatures.isNotEmpty) ...[
                const SizedBox(height: 14),
                _DetailSection(
                  title: 'Recent form',
                  child: _FormFeatureCard(match: match, features: formFeatures),
                ),
              ],
              const SizedBox(height: 14),
              standingsAsync.when(
                data: (rows) {
                  if (rows.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return _DetailSection(
                    title: 'Standings snapshot',
                    child: StandingsTable(
                      rows: rows.take(8).toList(growable: false),
                      highlightTeamIds: {
                        if (match.homeTeamId != null) match.homeTeamId!,
                        if (match.awayTeamId != null) match.awayTeamId!,
                      },
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        appBar: AppBar(title: const Text('Match')),
        body: StateView.error(
          title: 'Match unavailable',
          subtitle: 'Try again later.',
          onRetry: () => ref.invalidate(matchDetailProvider(matchId)),
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            title,
            style: FzTypography.display(
              size: 22,
              color: FzColors.darkText,
              letterSpacing: 0.4,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _MatchHeroCard extends StatelessWidget {
  const _MatchHeroCard({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    final statusColor = match.isLive ? FzColors.danger : FzColors.accent;
    return FzCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                match.kickoffLabel,
                style: FzTypography.metaLabel(color: statusColor),
              ),
              const Spacer(),
              Text(
                match.season,
                style: FzTypography.metaLabel(color: FzColors.darkMuted),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _HeroTeam(match.homeTeam, match.homeLogoUrl)),
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
                child: _HeroTeam(
                  match.awayTeam,
                  match.awayLogoUrl,
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroTeam extends StatelessWidget {
  const _HeroTeam(this.name, this.logoUrl, {this.alignEnd = false});

  final String name;
  final String? logoUrl;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        TeamAvatar(name: name, logoUrl: logoUrl, size: 46),
        const SizedBox(height: 10),
        Text(
          name,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: FzColors.darkText,
          ),
        ),
      ],
    );
  }
}

class _EngineDetailCard extends StatelessWidget {
  const _EngineDetailCard({required this.engine});

  final PredictionEngineOutputModel engine;

  @override
  Widget build(BuildContext context) {
    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _MetricBar(
            label: 'Home win',
            value: engine.homeWinScore,
            color: FzColors.accent2,
          ),
          const SizedBox(height: 10),
          _MetricBar(
            label: 'Draw',
            value: engine.drawScore,
            color: FzColors.warning,
          ),
          const SizedBox(height: 10),
          _MetricBar(
            label: 'Away win',
            value: engine.awayWinScore,
            color: FzColors.accent3,
          ),
          const Divider(height: 24, color: FzColors.darkBorder),
          Row(
            children: [
              Expanded(
                child: _OutcomePill(
                  label: 'Over 2.5',
                  value: '${(engine.over25Score * 100).round()}%',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OutcomePill(
                  label: 'BTTS',
                  value: '${(engine.bttsScore * 100).round()}%',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OutcomePill(
                  label: 'Model score',
                  value:
                      '${engine.predictedHomeGoals ?? 0}-${engine.predictedAwayGoals ?? 0}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: FzColors.darkText,
              ),
            ),
            const Spacer(),
            Text(
              '$pct%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: FzColors.darkText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: value.clamp(0, 1),
            backgroundColor: FzColors.darkSurface3,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _OutcomePill extends StatelessWidget {
  const _OutcomePill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: FzColors.darkSurface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: FzTypography.metaLabel(color: FzColors.darkMuted),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: FzColors.darkText,
            ),
          ),
        ],
      ),
    );
  }
}

class _CrowdDetailCard extends StatelessWidget {
  const _CrowdDetailCard({required this.crowd});

  final CrowdPrediction crowd;

  @override
  Widget build(BuildContext context) {
    final (home, draw, away) = crowd.normalized;
    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _OutcomePill(label: 'Home', value: '$home%'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _OutcomePill(label: 'Draw', value: '$draw%'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _OutcomePill(label: 'Away', value: '$away%'),
          ),
        ],
      ),
    );
  }
}

class _MyPredictionCard extends StatelessWidget {
  const _MyPredictionCard({
    required this.match,
    required this.engine,
    required this.prediction,
  });

  final MatchModel match;
  final PredictionEngineOutputModel? engine;
  final UserPredictionModel? prediction;

  @override
  Widget build(BuildContext context) {
    final text = prediction == null
        ? 'You have not saved a pick for this match yet.'
        : [
            if (prediction!.predictedResultCode != null)
              '1X2 ${prediction!.predictedResultCode}',
            if (prediction!.predictedOver25 != null)
              prediction!.predictedOver25! ? 'Over 2.5' : 'Under 2.5',
            if (prediction!.predictedBtts != null)
              prediction!.predictedBtts! ? 'BTTS Yes' : 'BTTS No',
            if (prediction!.scorelineLabel != null) prediction!.scorelineLabel!,
          ].join(' · ');

    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: FzColors.darkText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => showPredictionEntrySheet(
                context,
                match: match,
                engineOutput: engine,
                existingPrediction: prediction,
              ),
              icon: Icon(
                prediction == null ? LucideIcons.target : LucideIcons.pencil,
                size: 16,
              ),
              label: Text(prediction == null ? 'Make pick' : 'Update pick'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FzColors.accent2,
                foregroundColor: FzColors.darkText,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormFeatureCard extends StatelessWidget {
  const _FormFeatureCard({required this.match, required this.features});

  final MatchModel match;
  final List<TeamFormFeatureModel> features;

  TeamFormFeatureModel? _resolveFeature(String? teamId, int fallbackIndex) {
    if (teamId != null) {
      for (final feature in features) {
        if (feature.teamId == teamId) return feature;
      }
    }
    if (fallbackIndex < features.length) return features[fallbackIndex];
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final homeFeature = _resolveFeature(match.homeTeamId, 0);
    final awayFeature = _resolveFeature(match.awayTeamId, 1);

    return FzCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _FormColumn(teamName: match.homeTeam, feature: homeFeature),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _FormColumn(teamName: match.awayTeam, feature: awayFeature),
          ),
        ],
      ),
    );
  }
}

class _FormColumn extends StatelessWidget {
  const _FormColumn({required this.teamName, required this.feature});

  final String teamName;
  final TeamFormFeatureModel? feature;

  @override
  Widget build(BuildContext context) {
    final currentFeature = feature;
    if (feature == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            teamName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: FzColors.darkText,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No recent form snapshot yet.',
            style: TextStyle(fontSize: 12, color: FzColors.darkMuted),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          teamName,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: FzColors.darkText,
          ),
        ),
        const SizedBox(height: 10),
        _FormRow(
          label: 'Last 5 points',
          value: '${currentFeature!.last5Points}',
        ),
        _FormRow(
          label: 'W-D-L',
          value:
              '${currentFeature.last5Wins}-${currentFeature.last5Draws}-${currentFeature.last5Losses}',
        ),
        _FormRow(
          label: 'Goals',
          value:
              '${currentFeature.last5GoalsFor}:${currentFeature.last5GoalsAgainst}',
        ),
        _FormRow(
          label: 'Clean sheets',
          value: '${currentFeature.last5CleanSheets}',
        ),
        _FormRow(
          label: 'Failed to score',
          value: '${currentFeature.last5FailedToScore}',
        ),
      ],
    );
  }
}

class _FormRow extends StatelessWidget {
  const _FormRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: FzColors.darkMuted),
            ),
          ),
          Text(
            value,
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

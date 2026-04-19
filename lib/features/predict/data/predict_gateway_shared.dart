import '../../../config/app_config.dart';
import '../../../models/daily_challenge_model.dart';
import 'predict_gateway_models.dart';

bool get allowPredictSeedFallback => !AppConfig.isProduction;

Never throwPredictUnavailable(String action) {
  throw StateError('$action is unavailable right now. Please try again.');
}

DailyChallenge fallbackDailyChallenge() {
  final today = DateTime.now();
  return DailyChallenge(
    id: 'daily_1',
    date: DateTime(today.year, today.month, today.day),
    matchId: 'match_live_1',
    matchName: 'Liverpool vs Arsenal',
    title: 'Predict the final score',
    description: 'Submit one scoreline before kickoff for a free FET reward.',
    rewardFet: 25,
    bonusExactFet: 50,
    status: 'active',
    totalEntries: 132,
    totalWinners: 7,
  );
}

const List<GlobalLeaderboardEntryDto>
fallbackLeaderboard = <GlobalLeaderboardEntryDto>[
  GlobalLeaderboardEntryDto(rank: 1, name: 'FAN Malta', fet: 920, level: 3),
  GlobalLeaderboardEntryDto(rank: 2, name: 'FAN Kigali', fet: 880, level: 2),
  GlobalLeaderboardEntryDto(rank: 3, name: 'FAN Madrid', fet: 860, level: 2),
  GlobalLeaderboardEntryDto(rank: 4, name: 'FAN Lagos', fet: 810, level: 2),
];

import 'dart:async';

import '../../../config/app_config.dart';
import '../../../models/match_model.dart';
import '../../../models/match_odds_model.dart';
import 'home_dtos.dart';

const matchPollInterval = Duration(seconds: 15);

Stream<T> pollMatchStream<T>(Future<T> Function() loader) {
  final controller = StreamController<T>();
  Timer? timer;
  var loading = false;

  Future<void> emit() async {
    if (loading || controller.isClosed) return;
    loading = true;
    try {
      controller.add(await loader());
    } catch (error, stackTrace) {
      controller.addError(error, stackTrace);
    } finally {
      loading = false;
    }
  }

  controller.onListen = () {
    unawaited(emit());
    timer = Timer.periodic(matchPollInterval, (_) => unawaited(emit()));
  };
  controller.onCancel = () async {
    timer?.cancel();
    timer = null;
  };

  return controller.stream;
}

List<MatchModel> fallbackMatchesForFilter(MatchesFilter filter) {
  if (AppConfig.isProduction) return const <MatchModel>[];
  return applyMatchesFilter(seedMatches(), filter);
}

MatchOddsModel? fallbackOddsOrNull(String matchId) {
  if (AppConfig.isProduction) return null;
  return seedOdds(matchId);
}

List<MatchModel> applyMatchesFilter(
  List<MatchModel> matches,
  MatchesFilter filter,
) {
  final dateFrom = filter.dateFrom == null
      ? null
      : DateTime.tryParse(filter.dateFrom!);
  final dateTo = filter.dateTo == null
      ? null
      : DateTime.tryParse(filter.dateTo!);

  var filtered = matches
      .where((match) {
        if (filter.competitionId != null &&
            match.competitionId != filter.competitionId) {
          return false;
        }
        if (filter.teamId != null &&
            match.homeTeamId != filter.teamId &&
            match.awayTeamId != filter.teamId) {
          return false;
        }
        if (filter.status != null &&
            match.normalizedStatus != filter.status!.trim().toLowerCase()) {
          return false;
        }
        if (dateFrom != null && match.date.isBefore(dateFrom)) {
          return false;
        }
        if (dateTo != null && match.date.isAfter(dateTo)) {
          return false;
        }
        return true;
      })
      .toList(growable: false);

  filtered = [...filtered]
    ..sort(
      (left, right) => filter.ascending
          ? left.date.compareTo(right.date)
          : right.date.compareTo(left.date),
    );

  if (filtered.length > filter.limit) {
    filtered = filtered.take(filter.limit).toList(growable: false);
  }
  return filtered;
}

MatchOddsModel seedOdds(String matchId) {
  return MatchOddsModel(
    matchId: matchId,
    homeMultiplier: 1.8,
    drawMultiplier: 3.4,
    awayMultiplier: 4.1,
    provider: 'fallback',
    refreshedAt: DateTime.now(),
  );
}

List<MatchModel> seedMatches() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return [
    MatchModel(
      id: 'match_live_1',
      competitionId: 'epl',
      season: '2025/26',
      date: today,
      kickoffTime: '20:00',
      homeTeamId: 'liverpool',
      awayTeamId: 'arsenal',
      homeTeam: 'Liverpool',
      awayTeam: 'Arsenal',
      ftHome: 2,
      ftAway: 1,
      status: 'live',
      dataSource: 'fallback',
    ),
    MatchModel(
      id: 'match_upcoming_1',
      competitionId: 'laliga',
      season: '2025/26',
      date: today,
      kickoffTime: '21:00',
      homeTeamId: 'barcelona',
      awayTeamId: 'real-madrid',
      homeTeam: 'Barcelona',
      awayTeam: 'Real Madrid',
      status: 'upcoming',
      dataSource: 'fallback',
    ),
    MatchModel(
      id: 'match_finished_1',
      competitionId: 'epl',
      season: '2025/26',
      date: today.subtract(const Duration(days: 1)),
      kickoffTime: '18:00',
      homeTeamId: 'manchester-city',
      awayTeamId: 'manchester-united',
      homeTeam: 'Manchester City',
      awayTeam: 'Manchester United',
      ftHome: 3,
      ftAway: 2,
      status: 'finished',
      dataSource: 'fallback',
    ),
  ];
}

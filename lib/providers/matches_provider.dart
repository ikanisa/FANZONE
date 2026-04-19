import 'package:flutter_riverpod/flutter_riverpod.dart';

export '../features/home/data/home_dtos.dart' show MatchesFilter;

import '../core/di/injection.dart';
import '../features/home/data/home_dtos.dart';
import '../features/home/data/match_detail_gateway.dart';
import '../features/home/data/match_listing_gateway.dart';
import '../models/live_match_event.dart';
import '../models/match_model.dart';
import '../models/match_odds_model.dart';

final matchesProvider = FutureProvider.family
    .autoDispose<List<MatchModel>, MatchesFilter>((ref, filter) async {
      return getIt<MatchListingGateway>().getMatches(filter);
    });

final matchDetailProvider = StreamProvider.family
    .autoDispose<MatchModel?, String>((ref, matchId) {
      return getIt<MatchListingGateway>().watchMatch(matchId);
    });

final matchesByDateProvider = StreamProvider.family
    .autoDispose<List<MatchModel>, DateTime>((ref, date) {
      return getIt<MatchListingGateway>().watchMatchesByDate(date);
    });

final competitionMatchesProvider = StreamProvider.family
    .autoDispose<List<MatchModel>, String>((ref, competitionId) {
      return getIt<MatchListingGateway>().watchCompetitionMatches(
        competitionId,
      );
    });

final teamMatchesProvider = StreamProvider.family
    .autoDispose<List<MatchModel>, String>((ref, teamId) {
      return getIt<MatchListingGateway>().watchTeamMatches(teamId);
    });

final liveMatchEventsStreamProvider = StreamProvider.family
    .autoDispose<List<LiveMatchEvent>, String>((ref, matchId) {
      return getIt<MatchDetailGateway>().watchLiveMatchEvents(matchId);
    });

final matchOddsProvider = StreamProvider.family
    .autoDispose<MatchOddsModel?, String>((ref, matchId) {
      return getIt<MatchDetailGateway>().watchMatchOdds(matchId);
    });

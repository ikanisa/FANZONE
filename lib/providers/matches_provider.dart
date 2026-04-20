import 'package:flutter_riverpod/flutter_riverpod.dart';

export '../features/home/data/home_dtos.dart' show MatchesFilter;

import '../core/di/gateway_providers.dart';
import '../features/home/data/home_dtos.dart';
import '../models/live_match_event.dart';
import '../models/match_model.dart';
import '../models/match_odds_model.dart';

final matchesProvider = FutureProvider.family
    .autoDispose<List<MatchModel>, MatchesFilter>((ref, filter) async {
      return ref.read(matchListingGatewayProvider).getMatches(filter);
    });

final matchDetailProvider = StreamProvider.family
    .autoDispose<MatchModel?, String>((ref, matchId) {
      return ref.read(matchListingGatewayProvider).watchMatch(matchId);
    });

final matchesByDateProvider = StreamProvider.family
    .autoDispose<List<MatchModel>, DateTime>((ref, date) {
      return ref.read(matchListingGatewayProvider).watchMatchesByDate(date);
    });

final competitionMatchesProvider = StreamProvider.family
    .autoDispose<List<MatchModel>, String>((ref, competitionId) {
      return ref
          .read(matchListingGatewayProvider)
          .watchCompetitionMatches(competitionId);
    });

final teamMatchesProvider = StreamProvider.family
    .autoDispose<List<MatchModel>, String>((ref, teamId) {
      return ref.read(matchListingGatewayProvider).watchTeamMatches(teamId);
    });

final liveMatchEventsStreamProvider = StreamProvider.family
    .autoDispose<List<LiveMatchEvent>, String>((ref, matchId) {
      return ref.read(matchDetailGatewayProvider).watchLiveMatchEvents(matchId);
    });

final matchOddsProvider = StreamProvider.family
    .autoDispose<MatchOddsModel?, String>((ref, matchId) {
      return ref.read(matchDetailGatewayProvider).watchMatchOdds(matchId);
    });

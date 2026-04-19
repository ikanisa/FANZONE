import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/injection.dart';
import '../features/home/data/matches_gateway.dart';
import '../models/match_advanced_stats_model.dart';
import '../models/match_ai_analysis_model.dart';
import '../models/match_event_model.dart';
import '../models/match_player_stats_model.dart';

final matchAdvancedStatsProvider = StreamProvider.family
    .autoDispose<MatchAdvancedStats?, String>((ref, matchId) {
      return getIt<MatchesGateway>().watchAdvancedStats(matchId);
    });

final matchPlayerStatsProvider = StreamProvider.family
    .autoDispose<List<MatchPlayerStats>, String>((ref, matchId) {
      return getIt<MatchesGateway>().watchPlayerStats(matchId);
    });

final matchEventsProvider = StreamProvider.family
    .autoDispose<List<MatchEventModel>, String>((ref, matchId) {
      return getIt<MatchesGateway>().watchMatchEvents(matchId);
    });

final matchAiAnalysisProvider = FutureProvider.family
    .autoDispose<MatchAiAnalysis?, String>((ref, matchId) async {
      return getIt<MatchesGateway>().getMatchAiAnalysis(matchId);
    });

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/gateway_providers.dart';
import '../models/match_advanced_stats_model.dart';
import '../models/match_ai_analysis_model.dart';
import '../models/match_event_model.dart';
import '../models/match_player_stats_model.dart';
import '../models/prediction_market_catalog_item.dart';

final matchAdvancedStatsProvider = StreamProvider.family
    .autoDispose<MatchAdvancedStats?, String>((ref, matchId) {
      return ref.read(matchDetailGatewayProvider).watchAdvancedStats(matchId);
    });

final matchPlayerStatsProvider = StreamProvider.family
    .autoDispose<List<MatchPlayerStats>, String>((ref, matchId) {
      return ref.read(matchDetailGatewayProvider).watchPlayerStats(matchId);
    });

final matchEventsProvider = StreamProvider.family
    .autoDispose<List<MatchEventModel>, String>((ref, matchId) {
      return ref.read(matchDetailGatewayProvider).watchMatchEvents(matchId);
    });

final matchAiAnalysisProvider = FutureProvider.family
    .autoDispose<MatchAiAnalysis?, String>((ref, matchId) async {
      return ref.read(matchDetailGatewayProvider).getMatchAiAnalysis(matchId);
    });

final matchMarketCatalogProvider = FutureProvider.family
    .autoDispose<List<PredictionMarketCatalogItem>, String>((
      ref,
      competitionId,
    ) async {
      return ref
          .read(matchDetailGatewayProvider)
          .getMarketCatalog(competitionId);
    });

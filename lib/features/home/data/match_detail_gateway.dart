import 'package:injectable/injectable.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/live_match_event.dart';
import '../../../models/match_advanced_stats_model.dart';
import '../../../models/match_ai_analysis_model.dart';
import '../../../models/match_event_model.dart';
import '../../../models/match_odds_model.dart';
import '../../../models/match_player_stats_model.dart';
import 'matches_gateway_shared.dart';

abstract interface class MatchDetailGateway {
  Stream<List<LiveMatchEvent>> watchLiveMatchEvents(String matchId);

  Stream<MatchOddsModel?> watchMatchOdds(String matchId);

  Stream<MatchAdvancedStats?> watchAdvancedStats(String matchId);

  Stream<List<MatchPlayerStats>> watchPlayerStats(String matchId);

  Stream<List<MatchEventModel>> watchMatchEvents(String matchId);

  Future<MatchAiAnalysis?> getMatchAiAnalysis(String matchId);
}

@LazySingleton(as: MatchDetailGateway)
class SupabaseMatchDetailGateway implements MatchDetailGateway {
  SupabaseMatchDetailGateway(this._connection);

  final SupabaseConnection _connection;

  @override
  Stream<List<LiveMatchEvent>> watchLiveMatchEvents(String matchId) {
    return pollMatchStream<List<LiveMatchEvent>>(() async {
      final client = _connection.client;
      if (client == null) return const <LiveMatchEvent>[];

      try {
        final rows = await client
            .from('live_match_events')
            .select()
            .eq('match_id', matchId)
            .order('created_at');
        return (rows as List)
            .whereType<Map>()
            .map(
              (row) => LiveMatchEvent.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList(growable: false);
      } catch (error) {
        AppLogger.d('Failed to load live match events: $error');
        return const <LiveMatchEvent>[];
      }
    });
  }

  @override
  Stream<MatchOddsModel?> watchMatchOdds(String matchId) {
    return pollMatchStream<MatchOddsModel?>(() async {
      final client = _connection.client;
      if (client == null) return fallbackOddsOrNull(matchId);

      try {
        final row = await client
            .from('match_odds_cache')
            .select()
            .eq('match_id', matchId)
            .maybeSingle();
        if (row == null) return fallbackOddsOrNull(matchId);
        return MatchOddsModel.fromJson(Map<String, dynamic>.from(row));
      } catch (error) {
        AppLogger.d('Failed to load match odds: $error');
        return fallbackOddsOrNull(matchId);
      }
    });
  }

  @override
  Stream<MatchAdvancedStats?> watchAdvancedStats(String matchId) {
    return pollMatchStream<MatchAdvancedStats?>(() async {
      final client = _connection.client;
      if (client == null) return null;

      try {
        final row = await client
            .from('match_advanced_stats')
            .select()
            .eq('match_id', matchId)
            .maybeSingle();
        return row == null
            ? null
            : MatchAdvancedStats.fromJson(Map<String, dynamic>.from(row));
      } catch (error) {
        AppLogger.d('Failed to load advanced stats: $error');
        return null;
      }
    });
  }

  @override
  Stream<List<MatchPlayerStats>> watchPlayerStats(String matchId) {
    return pollMatchStream<List<MatchPlayerStats>>(() async {
      final client = _connection.client;
      if (client == null) return const <MatchPlayerStats>[];

      try {
        final rows = await client
            .from('match_player_stats')
            .select()
            .eq('match_id', matchId)
            .order('rating', ascending: false);
        return (rows as List)
            .whereType<Map>()
            .map(
              (row) =>
                  MatchPlayerStats.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList(growable: false);
      } catch (error) {
        AppLogger.d('Failed to load player stats: $error');
        return const <MatchPlayerStats>[];
      }
    });
  }

  @override
  Stream<List<MatchEventModel>> watchMatchEvents(String matchId) {
    return pollMatchStream<List<MatchEventModel>>(() async {
      final client = _connection.client;
      if (client == null) return const <MatchEventModel>[];

      try {
        final rows = await client
            .from('match_events')
            .select()
            .eq('match_id', matchId)
            .order('minute');
        return (rows as List)
            .whereType<Map>()
            .map(
              (row) => MatchEventModel.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList(growable: false);
      } catch (error) {
        AppLogger.d('Failed to load match events: $error');
        return const <MatchEventModel>[];
      }
    });
  }

  @override
  Future<MatchAiAnalysis?> getMatchAiAnalysis(String matchId) async {
    final client = _connection.client;
    if (client == null) return null;

    try {
      final row = await client
          .from('match_ai_analysis')
          .select()
          .eq('match_id', matchId)
          .order('generated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return row == null
          ? null
          : MatchAiAnalysis.fromJson(Map<String, dynamic>.from(row));
    } catch (error) {
      AppLogger.d('Failed to load match AI analysis: $error');
      return null;
    }
  }
}

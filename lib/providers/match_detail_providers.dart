import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/supabase_provider.dart';
import '../models/match_advanced_stats_model.dart';
import '../models/match_player_stats_model.dart';
import '../models/match_event_model.dart';
import '../models/match_ai_analysis_model.dart';

// ─── Advanced Match Stats ──────────────────────────────────────────

/// Realtime stream of advanced stats (xG, possession, shots, cards).
final matchAdvancedStatsProvider = StreamProvider.family
    .autoDispose<MatchAdvancedStats?, String>((ref, matchId) {
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return Stream.value(null);

      return client
          .from('match_advanced_stats')
          .stream(primaryKey: ['id'])
          .eq('match_id', matchId)
          .limit(1)
          .map((rows) {
            if (rows.isEmpty) return null;
            return MatchAdvancedStats.fromJson(
              Map<String, dynamic>.from(rows.first),
            );
          });
    });

// ─── Player Stats ──────────────────────────────────────────────────

/// Realtime stream of player-level stats for a match.
final matchPlayerStatsProvider = StreamProvider.family
    .autoDispose<List<MatchPlayerStats>, String>((ref, matchId) {
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return Stream.value(const []);

      return client
          .from('match_player_stats')
          .stream(primaryKey: ['id'])
          .eq('match_id', matchId)
          .order('is_starter', ascending: false)
          .order('rating', ascending: false)
          .map((rows) => rows
              .map((row) => MatchPlayerStats.fromJson(
                    Map<String, dynamic>.from(row),
                  ))
              .toList());
    });

// ─── Match Events Timeline ─────────────────────────────────────────

/// Realtime stream of match events (goals, cards, subs).
final matchEventsProvider = StreamProvider.family
    .autoDispose<List<MatchEventModel>, String>((ref, matchId) {
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return Stream.value(const []);

      return client
          .from('match_events')
          .stream(primaryKey: ['id'])
          .eq('match_id', matchId)
          .order('minute')
          .map((rows) => rows
              .map((row) => MatchEventModel.fromJson(
                    Map<String, dynamic>.from(row),
                  ))
              .toList());
    });

// ─── AI Pre-Match Analysis ─────────────────────────────────────────

/// Fetches AI analysis for a match (pre-match prediction + narrative).
final matchAiAnalysisProvider = FutureProvider.family
    .autoDispose<MatchAiAnalysis?, String>((ref, matchId) async {
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return null;

      final data = await client
          .from('match_ai_analysis')
          .select()
          .eq('match_id', matchId)
          .eq('analysis_type', 'pre_match')
          .maybeSingle()
          .timeout(supabaseTimeout);

      if (data == null) return null;
      return MatchAiAnalysis.fromJson(data);
    });

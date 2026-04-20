import '../../../models/live_match_event.dart';
import '../../../models/match_advanced_stats_model.dart';
import '../../../models/match_ai_analysis_model.dart';
import '../../../models/match_event_model.dart';
import '../../../models/match_model.dart';
import '../../../models/match_odds_model.dart';
import '../../../models/match_player_stats_model.dart';
import 'home_dtos.dart';
import 'match_detail_gateway.dart';
import 'match_listing_gateway.dart';

abstract interface class MatchesGateway
    implements MatchListingGateway, MatchDetailGateway {}

class SupabaseMatchesGateway implements MatchesGateway {
  SupabaseMatchesGateway(this._listing, this._detail);

  final MatchListingGateway _listing;
  final MatchDetailGateway _detail;

  @override
  Future<List<MatchModel>> getMatches(MatchesFilter filter) =>
      _listing.getMatches(filter);

  @override
  Stream<MatchModel?> watchMatch(String matchId) =>
      _listing.watchMatch(matchId);

  @override
  Stream<List<MatchModel>> watchMatchesByDate(DateTime date) =>
      _listing.watchMatchesByDate(date);

  @override
  Stream<List<MatchModel>> watchCompetitionMatches(String competitionId) =>
      _listing.watchCompetitionMatches(competitionId);

  @override
  Stream<List<MatchModel>> watchTeamMatches(String teamId) =>
      _listing.watchTeamMatches(teamId);

  @override
  Stream<List<MatchModel>> watchUpcomingMatches() =>
      _listing.watchUpcomingMatches();

  @override
  Stream<List<LiveMatchEvent>> watchLiveMatchEvents(String matchId) =>
      _detail.watchLiveMatchEvents(matchId);

  @override
  Stream<MatchOddsModel?> watchMatchOdds(String matchId) =>
      _detail.watchMatchOdds(matchId);

  @override
  Stream<MatchAdvancedStats?> watchAdvancedStats(String matchId) =>
      _detail.watchAdvancedStats(matchId);

  @override
  Stream<List<MatchPlayerStats>> watchPlayerStats(String matchId) =>
      _detail.watchPlayerStats(matchId);

  @override
  Stream<List<MatchEventModel>> watchMatchEvents(String matchId) =>
      _detail.watchMatchEvents(matchId);

  @override
  Future<MatchAiAnalysis?> getMatchAiAnalysis(String matchId) =>
      _detail.getMatchAiAnalysis(matchId);

  @override
  Stream<List<MatchModel>> watchLiveMatches() =>
      _listing.watchLiveMatches();
}

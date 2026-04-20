import '../../../models/competition_model.dart';
import '../../../models/featured_event_model.dart';
import '../../../models/global_challenge_model.dart';
import '../../../models/search_result_model.dart';
import '../../../models/standing_row_model.dart';
import '../../../models/team_model.dart';
import 'competition_catalog_gateway.dart';
import 'event_catalog_gateway.dart';
import 'home_dtos.dart';
import 'search_catalog_gateway.dart';
import 'team_catalog_gateway.dart';

export 'competition_catalog_gateway.dart';
export 'event_catalog_gateway.dart';
export 'search_catalog_gateway.dart';
export 'team_catalog_gateway.dart';

abstract interface class CatalogGateway
    implements
        CompetitionCatalogGateway,
        TeamCatalogGateway,
        EventCatalogGateway,
        SearchCatalogGateway {}

class SupabaseCatalogGateway implements CatalogGateway {
  SupabaseCatalogGateway(
    this._competitions,
    this._teams,
    this._events,
    this._search,
  );

  final CompetitionCatalogGateway _competitions;
  final TeamCatalogGateway _teams;
  final EventCatalogGateway _events;
  final SearchCatalogGateway _search;

  @override
  Future<CompetitionModel?> getCompetition(String competitionId) {
    return _competitions.getCompetition(competitionId);
  }

  @override
  Future<List<CompetitionModel>> getCompetitions({
    int? tier,
    bool featuredOnly = false,
  }) {
    return _competitions.getCompetitions(
      tier: tier,
      featuredOnly: featuredOnly,
    );
  }

  @override
  Future<List<StandingRowModel>> getCompetitionStandings(
    CompetitionStandingsFilter filter,
  ) {
    return _competitions.getCompetitionStandings(filter);
  }

  @override
  Future<FeaturedEventModel?> getFeaturedEventByTag(String eventTag) {
    return _events.getFeaturedEventByTag(eventTag);
  }

  @override
  Future<List<FeaturedEventModel>> getFeaturedEvents({
    bool activeOnly = false,
    bool upcomingOnly = false,
    int? limit,
  }) {
    return _events.getFeaturedEvents(
      activeOnly: activeOnly,
      upcomingOnly: upcomingOnly,
      limit: limit,
    );
  }

  @override
  Future<List<GlobalChallengeModel>> getGlobalChallenges({
    String? eventTag,
    List<String>? regionValues,
    int? limit,
  }) {
    return _events.getGlobalChallenges(
      eventTag: eventTag,
      regionValues: regionValues,
      limit: limit,
    );
  }

  @override
  Future<SearchResults> search(SearchQueryDto query) {
    return _search.search(query);
  }

  @override
  Future<TeamModel?> getTeam(String teamId) {
    return _teams.getTeam(teamId);
  }

  @override
  Future<List<TeamModel>> getTeams({
    String? competitionId,
    bool featuredOnly = false,
  }) {
    return _teams.getTeams(
      competitionId: competitionId,
      featuredOnly: featuredOnly,
    );
  }
}

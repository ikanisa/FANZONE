import '../features/onboarding/data/onboarding_gateway.dart';
import '../features/onboarding/data/team_search_catalog.dart';

export '../features/onboarding/data/team_search_catalog.dart'
    show FavoriteTeamRecordDto, OnboardingTeam, TeamSearchCatalog;

/// Global team search singleton — resolved once at startup.
/// The onboarding gateway uses the injected catalog internally.
TeamSearchCatalog? _catalog = TeamSearchCatalog.empty();
OnboardingGateway? _gateway;

TeamSearchCatalog get activeTeamSearchCatalog =>
    _catalog ?? TeamSearchCatalog.empty();

/// Called during app startup (from gateway_providers.dart resolveAsyncOverrides).
void initTeamSearchDatabase({
  required TeamSearchCatalog catalog,
  OnboardingGateway? gateway,
}) {
  _catalog = catalog;
  _gateway = gateway;
}

List<OnboardingTeam> get allTeams {
  if (_gateway != null) {
    try {
      return _gateway!.allTeams;
    } catch (_) {}
  }
  return activeTeamSearchCatalog.allTeams;
}

List<OnboardingTeam> searchTeams(String query, {int limit = 10}) {
  if (_gateway != null) {
    try {
      return _gateway!.searchTeams(query, limit: limit);
    } catch (_) {}
  }
  return activeTeamSearchCatalog.searchLocal(query, limit: limit);
}

List<OnboardingTeam> searchPopularTeams(String query, {int limit = 10}) {
  if (_gateway != null) {
    try {
      return _gateway!.searchPopularTeams(query, limit: limit);
    } catch (_) {}
  }
  return activeTeamSearchCatalog.searchPopular(query, limit: limit);
}

Future<List<OnboardingTeam>> searchTeamsAsync(
  String query, {
  int limit = 10,
}) async {
  return searchTeams(query, limit: limit);
}

Future<List<OnboardingTeam>> searchPopularTeamsAsync(
  String query, {
  int limit = 10,
}) async {
  return searchPopularTeams(query, limit: limit);
}

List<OnboardingTeam> popularTeamsForRegion(String region) {
  if (_gateway != null) {
    try {
      return _gateway!.popularTeamsForRegion(region);
    } catch (_) {}
  }
  return activeTeamSearchCatalog.popularForRegion(region);
}

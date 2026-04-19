import '../core/di/injection.dart';
import '../features/onboarding/data/onboarding_gateway.dart';
import '../features/onboarding/data/team_search_catalog.dart';

export '../features/onboarding/data/team_search_catalog.dart'
    show FavoriteTeamRecordDto, OnboardingTeam, TeamSearchCatalog;

OnboardingGateway get _gateway => getIt<OnboardingGateway>();
TeamSearchCatalog? get _catalog => getIt.isRegistered<TeamSearchCatalog>()
    ? getIt<TeamSearchCatalog>()
    : null;

List<OnboardingTeam> get allTeams => getIt.isRegistered<OnboardingGateway>()
    ? _gateway.allTeams
    : (_catalog?.allTeams ?? const <OnboardingTeam>[]);

List<OnboardingTeam> searchTeams(String query, {int limit = 10}) {
  if (getIt.isRegistered<OnboardingGateway>()) {
    return _gateway.searchTeams(query, limit: limit);
  }
  return _catalog?.search(query, limit: limit) ?? const <OnboardingTeam>[];
}

List<OnboardingTeam> popularTeamsForRegion(String region) {
  if (getIt.isRegistered<OnboardingGateway>()) {
    return _gateway.popularTeamsForRegion(region);
  }
  return _catalog?.popularForRegion(region) ?? const <OnboardingTeam>[];
}

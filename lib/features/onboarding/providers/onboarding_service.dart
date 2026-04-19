import '../../../core/di/injection.dart';
import '../data/onboarding_gateway.dart';
import '../data/team_search_catalog.dart';

/// Compatibility wrapper for onboarding persistence/search.
///
/// The actual data access lives in [OnboardingGateway].
class OnboardingService {
  static OnboardingGateway get _gateway => getIt<OnboardingGateway>();

  static Future<void> saveOnboardingTeams({
    OnboardingTeam? localTeam,
    Set<String> popularTeamIds = const <String>{},
  }) {
    return _gateway.saveOnboardingTeams(
      localTeam: localTeam,
      popularTeamIds: popularTeamIds,
    );
  }

  static Future<void> addFavoriteTeam(
    OnboardingTeam team, {
    String source = 'settings',
  }) {
    return _gateway.addFavoriteTeam(team, source: source);
  }

  static Future<void> syncCachedTeamsIfAuthenticated() {
    return _gateway.syncCachedTeamsIfAuthenticated();
  }

  static Future<List<FavoriteTeamRecordDto>> getCachedFavoriteTeams() {
    return _gateway.getCachedFavoriteTeams();
  }

  static Future<List<FavoriteTeamRecordDto>> getUserFavoriteTeams() {
    return _gateway.getUserFavoriteTeams();
  }

  static Future<void> deleteFavoriteTeam(String teamId) {
    return _gateway.deleteFavoriteTeam(teamId);
  }
}

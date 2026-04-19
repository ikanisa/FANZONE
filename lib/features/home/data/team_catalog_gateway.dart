import '../../../config/app_config.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/team_model.dart';
import 'catalog_gateway_shared.dart';

abstract interface class TeamCatalogGateway {
  Future<List<TeamModel>> getTeams({String? competitionId, bool featuredOnly});

  Future<TeamModel?> getTeam(String teamId);
}

class SupabaseTeamCatalogGateway implements TeamCatalogGateway {
  SupabaseTeamCatalogGateway(this._connection);

  final SupabaseConnection _connection;

  @override
  Future<List<TeamModel>> getTeams({
    String? competitionId,
    bool featuredOnly = false,
  }) async {
    final client = _connection.client;
    if (client == null) {
      return _fallbackTeams(
        competitionId: competitionId,
        featuredOnly: featuredOnly,
      );
    }

    try {
      final rows = await client.from('team_catalog_entries').select();
      final teams = (rows as List)
          .whereType<Map>()
          .map((row) => TeamModel.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      final filtered = filterTeams(
        teams,
        competitionId: competitionId,
        featuredOnly: featuredOnly,
      );
      return filtered;
    } catch (error) {
      AppLogger.d('Failed to load teams: $error');
      return _fallbackTeams(
        competitionId: competitionId,
        featuredOnly: featuredOnly,
      );
    }
  }

  @override
  Future<TeamModel?> getTeam(String teamId) async {
    final teams = await getTeams();
    for (final team in teams) {
      if (team.id == teamId) return team;
    }
    return null;
  }

  List<TeamModel> _fallbackTeams({
    String? competitionId,
    bool featuredOnly = false,
  }) {
    if (!AppConfig.isDevelopment) return const <TeamModel>[];
    return filterTeams(
      fallbackTeams,
      competitionId: competitionId,
      featuredOnly: featuredOnly,
    );
  }
}

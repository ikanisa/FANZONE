import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/team_model.dart';

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
    if (client == null) return const <TeamModel>[];

    try {
      final rows = await client.from('team_catalog_entries').select();
      final teams = (rows as List)
          .whereType<Map>()
          .map((row) => TeamModel.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      Iterable<TeamModel> result = teams;
      if (competitionId != null) {
        result = result.where((t) => t.competitionIds.contains(competitionId));
      }
      if (featuredOnly) {
        result = result.where((t) => t.isFeatured);
      }
      return result.toList(growable: false);
    } catch (error) {
      AppLogger.d('Failed to load teams: $error');
      return const <TeamModel>[];
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
}

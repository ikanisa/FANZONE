import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/team_model.dart';

abstract interface class TeamCatalogGateway {
  Future<List<TeamModel>> getTeams({String? competitionId, bool featuredOnly});

  Future<TeamModel?> getTeam(String teamId);

  /// Resolves a potentially aliased team ID to its canonical ID
  /// using the `team_aliases` table. Returns the original ID if
  /// no alias mapping exists.
  Future<String> resolveTeamId(String teamId);
}

class SupabaseTeamCatalogGateway implements TeamCatalogGateway {
  SupabaseTeamCatalogGateway(this._connection);

  final SupabaseConnection _connection;

  /// In-memory alias cache to avoid repeated lookups.
  final Map<String, String> _aliasCache = {};

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
    // Resolve alias first
    final canonicalId = await resolveTeamId(teamId);
    final teams = await getTeams();
    for (final team in teams) {
      if (team.id == canonicalId) return team;
    }
    return null;
  }

  @override
  Future<String> resolveTeamId(String teamId) async {
    // Check in-memory cache first
    if (_aliasCache.containsKey(teamId)) {
      return _aliasCache[teamId]!;
    }

    final client = _connection.client;
    if (client == null) return teamId;

    try {
      final row = await client
          .from('team_aliases')
          .select('canonical_id')
          .eq('alias_id', teamId)
          .maybeSingle();
      if (row != null) {
        final canonical = row['canonical_id']?.toString() ?? teamId;
        _aliasCache[teamId] = canonical;
        return canonical;
      }
    } catch (error) {
      AppLogger.d('Failed to resolve team alias: $error');
    }

    _aliasCache[teamId] = teamId;
    return teamId;
  }
}

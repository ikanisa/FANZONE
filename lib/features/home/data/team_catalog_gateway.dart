import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/team_model.dart';
import 'sports_data_exception.dart';

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

  Never _throwUnavailable(String operation) {
    throw SportsDataUnavailableException(
      'Sports data is unavailable for $operation.',
    );
  }

  @override
  Future<List<TeamModel>> getTeams({
    String? competitionId,
    bool featuredOnly = false,
  }) async {
    final client = _connection.client;
    if (client == null) {
      _throwUnavailable('team loading');
    }

    try {
      var query = client.from('teams').select().eq('is_active', true);
      if (competitionId != null && competitionId.trim().isNotEmpty) {
        query = query.contains('competition_ids', [competitionId.trim()]);
      }
      if (featuredOnly) {
        query = query.eq('is_featured', true);
      }
      final rows = await query.order('name', ascending: true).range(0, 2999);
      final teams = (rows as List)
          .whereType<Map>()
          .map((row) => TeamModel.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      return teams;
    } catch (error) {
      AppLogger.d('Failed to load teams: $error');
      if (error is SportsDataException) rethrow;
      throw SportsDataQueryException('Failed to load teams.', cause: error);
    }
  }

  @override
  Future<TeamModel?> getTeam(String teamId) async {
    final canonicalId = await resolveTeamId(teamId);
    final client = _connection.client;
    if (client == null) {
      _throwUnavailable('team details');
    }

    try {
      final row = await client
          .from('teams')
          .select()
          .eq('id', canonicalId)
          .maybeSingle();
      if (row == null) return null;
      return TeamModel.fromJson(
        Map<String, dynamic>.from(row as Map<dynamic, dynamic>),
      );
    } catch (error) {
      AppLogger.d('Failed to load team $canonicalId: $error');
      throw SportsDataQueryException(
        'Failed to load team details for $canonicalId.',
        cause: error,
      );
    }
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
          .select('team_id')
          .eq('alias_name', teamId)
          .maybeSingle();
      if (row != null) {
        final canonical = row['team_id']?.toString() ?? teamId;
        _aliasCache[teamId] = canonical;
        return canonical;
      }
    } catch (error) {
      AppLogger.d('Failed to resolve team alias: $error');
    }

    try {
      final row = await client
          .from('team_aliases')
          .select('team_id')
          .ilike('alias_name', teamId)
          .maybeSingle();
      if (row != null) {
        final canonical = row['team_id']?.toString() ?? teamId;
        _aliasCache[teamId] = canonical;
        return canonical;
      }
    } catch (error) {
      AppLogger.d('Failed to resolve team alias by name: $error');
    }

    _aliasCache[teamId] = teamId;
    return teamId;
  }
}

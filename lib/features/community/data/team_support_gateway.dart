
import '../../../config/app_config.dart';
import '../../../core/cache/cache_service.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/team_contribution_model.dart';
import '../../../models/team_supporter_model.dart';
import 'community_gateway_shared.dart';

abstract interface class TeamSupportGateway {
  Future<Set<String>> getSupportedTeamIds(String userId);

  Future<String?> supportTeam(String teamId);

  Future<void> unsupportTeam(String teamId);

  Future<TeamCommunityStats?> getTeamCommunityStats(String teamId);

  Future<List<AnonymousFanRecord>> getTeamAnonymousFans(
    String teamId, {
    int limit,
  });

  Future<int> contributeFet(String teamId, int amount);

  Future<List<TeamContributionModel>> getTeamContributionHistory(
    String userId,
    String teamId,
  );

  Future<List<Map<String, dynamic>>> getFeaturedTeamsRaw();
}

class SupabaseTeamSupportGateway implements TeamSupportGateway {
  SupabaseTeamSupportGateway(this._cache, this._connection);

  static const _supportedPrefix = 'community.supported.';
  static const _contributionPrefix = 'community.contributions.';
  static const _balancePrefix = 'community.balance.';

  final CacheService _cache;
  final SupabaseConnection _connection;

  @override
  Future<Set<String>> getSupportedTeamIds(String userId) async {
    final cached = (await _cache.getStringList(
      '$_supportedPrefix$userId',
    )).toSet();
    final client = _connection.client;
    if (client == null) return cached;

    try {
      final rows = await client
          .from('team_supporters')
          .select('team_id')
          .eq('user_id', userId)
          .eq('is_active', true);
      final supported = (rows as List)
          .whereType<Map>()
          .map((row) => row['team_id']?.toString())
          .whereType<String>()
          .toSet();
      await _cache.setStringList(
        '$_supportedPrefix$userId',
        supported.toList()..sort(),
      );
      return supported;
    } catch (error) {
      AppLogger.d('Failed to load supported teams: $error');
      return cached;
    }
  }

  @override
  Future<String?> supportTeam(String teamId) async {
    final userId = _requireUserId();
    final client = _connection.client;
    if (client == null) {
      _throwUnavailable('Supporting a team');
    }

    try {
      final response = await client.rpc(
        'support_team',
        params: {'p_team_id': teamId},
      );
      final payload = response is Map<String, dynamic>
          ? response
          : response is Map
          ? Map<String, dynamic>.from(response)
          : const <String, dynamic>{};
      final next = {...await getSupportedTeamIds(userId), teamId}.toList()
        ..sort();
      await _cache.setStringList('$_supportedPrefix$userId', next);
      return payload['anonymous_fan_id']?.toString();
    } catch (error) {
      AppLogger.d('Failed to support team: $error');
      rethrow;
    }
  }

  @override
  Future<void> unsupportTeam(String teamId) async {
    final userId = _requireUserId();
    final client = _connection.client;
    if (client == null) {
      _throwUnavailable('Leaving a team community');
    }

    try {
      await client.rpc('unsupport_team', params: {'p_team_id': teamId});
      final next = {...await getSupportedTeamIds(userId)}..remove(teamId);
      await _cache.setStringList(
        '$_supportedPrefix$userId',
        next.toList()..sort(),
      );
    } catch (error) {
      AppLogger.d('Failed to unsupport team: $error');
      rethrow;
    }
  }

  @override
  Future<TeamCommunityStats?> getTeamCommunityStats(String teamId) async {
    final client = _connection.client;
    if (client != null) {
      try {
        final row = await client
            .from('team_community_stats')
            .select()
            .eq('team_id', teamId)
            .maybeSingle();
        if (row != null) {
          return TeamCommunityStats.fromJson(Map<String, dynamic>.from(row));
        }
      } catch (error) {
        AppLogger.d('Failed to load team community stats: $error');
      }
    }

    if (!AppConfig.isDevelopment) return null;

    final supporters = await getTeamAnonymousFans(teamId);
    final totalFet = await _cachedContributionTotal(teamId);
    return TeamCommunityStats(
      teamId: teamId,
      teamName: communityTeamName(teamId),
      fanCount: supporters.length + 120,
      totalFetContributed: totalFet,
      contributionCount: supporters.isEmpty ? 0 : 4,
      supportersLast30d: 18,
    );
  }

  @override
  Future<List<AnonymousFanRecord>> getTeamAnonymousFans(
    String teamId, {
    int limit = 50,
  }) async {
    final client = _connection.client;
    if (client != null) {
      try {
        final rows = await client
            .from('team_supporters')
            .select('anonymous_fan_id, joined_at')
            .eq('team_id', teamId)
            .eq('is_active', true)
            .order('joined_at', ascending: false)
            .limit(limit);
        final supporters = (rows as List)
            .whereType<Map>()
            .map(
              (row) =>
                  AnonymousFanRecord.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList(growable: false);
        return supporters;
      } catch (error) {
        AppLogger.d('Failed to load anonymous fans: $error');
      }
    }

    if (!AppConfig.isDevelopment) return const <AnonymousFanRecord>[];

    final count = limit.clamp(0, 6);
    return List<AnonymousFanRecord>.generate(
      count,
      (index) => AnonymousFanRecord(
        anonymousFanId: 'FAN${1000 + index}',
        joinedAt: DateTime.now().subtract(Duration(days: index + 1)),
      ),
      growable: false,
    );
  }

  @override
  Future<int> contributeFet(String teamId, int amount) async {
    final userId = _requireUserId();
    final client = _connection.client;
    if (client == null) {
      _throwUnavailable('FET contribution');
    }

    try {
      final response = await client.rpc(
        'contribute_fet_to_team',
        params: {'p_team_id': teamId, 'p_amount_fet': amount},
      );
      final payload = response is Map<String, dynamic>
          ? response
          : response is Map
          ? Map<String, dynamic>.from(response)
          : const <String, dynamic>{};
      final balanceAfter = (payload['balance_after'] as num?)?.toInt();
      await _cache.remove(_contributionKey(userId, teamId));
      if (balanceAfter != null) {
        await _cache.setString('$_balancePrefix$userId', '$balanceAfter');
        return balanceAfter;
      }
    } catch (error) {
      AppLogger.d('Failed to persist team contribution: $error');
      rethrow;
    }

    throw StateError('Contribution did not return an updated balance.');
  }

  @override
  Future<List<TeamContributionModel>> getTeamContributionHistory(
    String userId,
    String teamId,
  ) async {
    final cachedRows = await _cache.getJsonList(
      _contributionKey(userId, teamId),
      debugLabel: 'team contributions',
    );
    final cached = cachedRows
        .map(TeamContributionModel.fromJson)
        .toList(growable: false);

    final client = _connection.client;
    if (client == null) return cached;

    try {
      final rows = await client
          .from('team_contributions')
          .select()
          .eq('user_id', userId)
          .eq('team_id', teamId)
          .order('created_at', ascending: false);
      final contributions = (rows as List)
          .whereType<Map>()
          .map(
            (row) =>
                TeamContributionModel.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
      await _cache.setJson(
        _contributionKey(userId, teamId),
        contributions.map(teamContributionToJson).toList(growable: false),
      );
      return contributions;
    } catch (error) {
      AppLogger.d('Failed to load contribution history: $error');
      return cached;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getFeaturedTeamsRaw() async {
    final client = _connection.client;
    if (client != null) {
      try {
        final rows = await client
            .from('teams')
            .select('id, name, fan_count, country, league_name, crest_url')
            .eq('is_featured', true)
            .order('fan_count', ascending: false)
            .limit(6);
        final teams = (rows as List)
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList(growable: false);
        return teams;
      } catch (error) {
        AppLogger.d('Failed to load featured teams: $error');
      }
    }

    if (!AppConfig.isDevelopment) return const <Map<String, dynamic>>[];

    return const [
      {'id': 'liverpool', 'name': 'Liverpool', 'fan_count': 24000},
      {'id': 'arsenal', 'name': 'Arsenal', 'fan_count': 22000},
      {'id': 'barcelona', 'name': 'Barcelona', 'fan_count': 26000},
    ];
  }

  String _contributionKey(String userId, String teamId) =>
      '$_contributionPrefix$userId.$teamId';

  Future<int> _cachedContributionTotal(String teamId) async {
    final userId = _connection.currentUser?.id;
    if (userId == null) return 0;
    final history = await getTeamContributionHistory(userId, teamId);
    return history.fold<int>(0, (sum, item) => sum + (item.amountFet ?? 0));
  }

  String _requireUserId() {
    final userId = _connection.currentUser?.id;
    if (userId == null) {
      throw StateError('Not authenticated');
    }
    return userId;
  }

  Never _throwUnavailable(String action) {
    throw StateError('$action is unavailable right now. Please try again.');
  }
}

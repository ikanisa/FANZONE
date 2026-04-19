
import '../../../core/cache/cache_service.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import 'preferences_gateway_shared.dart';

class CompetitionSelectionsDto {
  const CompetitionSelectionsDto({this.competitionIds = const <String>{}});

  final Set<String> competitionIds;
}

abstract interface class CompetitionPreferencesGateway {
  Future<CompetitionSelectionsDto> readCachedCompetitionFavourites({
    required String scope,
  });

  Future<void> writeCachedCompetitionFavourites({
    required String scope,
    required CompetitionSelectionsDto selections,
  });

  Future<CompetitionSelectionsDto> readRemoteCompetitionFavourites(
    String userId,
  );

  Future<void> setRemoteCompetitionFavourite({
    required String userId,
    required String competitionId,
    required bool enabled,
  });
}

class SupabaseCompetitionPreferencesGateway
    implements CompetitionPreferencesGateway {
  SupabaseCompetitionPreferencesGateway(this._cache, this._connection);

  final CacheService _cache;
  final SupabaseConnection _connection;

  @override
  Future<CompetitionSelectionsDto> readCachedCompetitionFavourites({
    required String scope,
  }) async {
    final competitionIds = await _cache.getStringList(
      '$competitionIdsCachePrefix$scope',
    );
    return CompetitionSelectionsDto(competitionIds: competitionIds.toSet());
  }

  @override
  Future<void> writeCachedCompetitionFavourites({
    required String scope,
    required CompetitionSelectionsDto selections,
  }) async {
    final competitionIds = selections.competitionIds.toList()..sort();
    await _cache.setStringList(
      '$competitionIdsCachePrefix$scope',
      competitionIds,
    );
  }

  @override
  Future<CompetitionSelectionsDto> readRemoteCompetitionFavourites(
    String userId,
  ) async {
    final fallback = await readCachedCompetitionFavourites(
      scope: 'user_$userId',
    );
    final client = _connection.client;
    if (client == null) return fallback;

    try {
      final competitionRows = await client
          .from('user_followed_competitions')
          .select('competition_id')
          .eq('user_id', userId);

      final competitionIds = (competitionRows as List)
          .whereType<Map>()
          .map((row) => row['competition_id']?.toString())
          .whereType<String>()
          .toSet();

      if (competitionIds.isEmpty) return fallback;
      return CompetitionSelectionsDto(competitionIds: competitionIds);
    } catch (error) {
      AppLogger.d('Failed to load remote competition favourites: $error');
      return fallback;
    }
  }

  @override
  Future<void> setRemoteCompetitionFavourite({
    required String userId,
    required String competitionId,
    required bool enabled,
  }) async {
    final cached = await readCachedCompetitionFavourites(scope: 'user_$userId');
    final nextCompetitionIds = Set<String>.from(cached.competitionIds);
    if (enabled) {
      nextCompetitionIds.add(competitionId);
    } else {
      nextCompetitionIds.remove(competitionId);
    }

    await writeCachedCompetitionFavourites(
      scope: 'user_$userId',
      selections: CompetitionSelectionsDto(competitionIds: nextCompetitionIds),
    );

    final client = _connection.client;
    if (client == null) return;

    try {
      if (enabled) {
        await client.from('user_followed_competitions').upsert({
          'user_id': userId,
          'competition_id': competitionId,
        }, onConflict: 'user_id,competition_id');
      } else {
        await client
            .from('user_followed_competitions')
            .delete()
            .eq('user_id', userId)
            .eq('competition_id', competitionId);
      }
    } catch (error) {
      AppLogger.d('Failed to sync followed competition: $error');
    }
  }
}

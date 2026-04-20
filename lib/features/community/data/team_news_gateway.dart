import '../../../config/app_config.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/team_news_model.dart';
import 'community_gateway_shared.dart';

abstract interface class TeamNewsGateway {
  Future<List<TeamNewsModel>> getTeamNews(
    String teamId, {
    String? category,
    int limit,
  });

  Future<TeamNewsModel?> getTeamNewsDetail(String newsId);
}

class SupabaseTeamNewsGateway implements TeamNewsGateway {
  SupabaseTeamNewsGateway(this._connection);

  final SupabaseConnection _connection;

  @override
  Future<List<TeamNewsModel>> getTeamNews(
    String teamId, {
    String? category,
    int limit = 20,
  }) async {
    final client = _connection.client;
    if (client == null) {
      if (!AppConfig.isDevelopment) {
        throw StateError(
          'Team news is unavailable right now. Please try again.',
        );
      }
    } else {
      try {
        var query = client
            .from('team_news')
            .select()
            .eq('team_id', teamId)
            .eq('status', 'published');
        if (category != null && category.isNotEmpty) {
          query = query.eq('category', category);
        }
        final rows = await query
            .order('published_at', ascending: false)
            .limit(limit);
        final news = (rows as List)
            .whereType<Map>()
            .map(
              (row) => TeamNewsModel.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList(growable: false);
        return news;
      } catch (error) {
        AppLogger.d('Failed to load team news: $error');
        if (!AppConfig.isDevelopment) {
          rethrow;
        }
      }
    }

    final seeded = seedTeamNews(teamId);
    final filtered = category == null || category.isEmpty
        ? seeded
        : seeded
              .where((item) => item.category == category)
              .toList(growable: false);
    return filtered.take(limit).toList(growable: false);
  }

  @override
  Future<TeamNewsModel?> getTeamNewsDetail(String newsId) async {
    final client = _connection.client;
    if (client == null) {
      if (!AppConfig.isDevelopment) {
        throw StateError(
          'Team news is unavailable right now. Please try again.',
        );
      }
    } else {
      try {
        final row = await client
            .from('team_news')
            .select()
            .eq('id', newsId)
            .maybeSingle();
        if (row != null) {
          return TeamNewsModel.fromJson(Map<String, dynamic>.from(row));
        }
      } catch (error) {
        AppLogger.d('Failed to load team news detail: $error');
        if (!AppConfig.isDevelopment) {
          rethrow;
        }
      }
    }

    for (final item in [
      ...seedTeamNews('liverpool'),
      ...seedTeamNews('arsenal'),
      ...seedTeamNews('barcelona'),
    ]) {
      if (item.id == newsId) return item;
    }
    return null;
  }
}

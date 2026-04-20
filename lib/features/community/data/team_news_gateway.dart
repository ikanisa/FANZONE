import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/team_news_model.dart';

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
    if (client == null) return const <TeamNewsModel>[];

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
      return (rows as List)
          .whereType<Map>()
          .map(
            (row) => TeamNewsModel.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    } catch (error) {
      AppLogger.d('Failed to load team news: $error');
      return const <TeamNewsModel>[];
    }
  }

  @override
  Future<TeamNewsModel?> getTeamNewsDetail(String newsId) async {
    final client = _connection.client;
    if (client == null) return null;

    try {
      final row = await client
          .from('team_news')
          .select()
          .eq('id', newsId)
          .maybeSingle();
      if (row != null) {
        return TeamNewsModel.fromJson(Map<String, dynamic>.from(row));
      }
      return null;
    } catch (error) {
      AppLogger.d('Failed to load team news detail: $error');
      return null;
    }
  }
}

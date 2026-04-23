import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/featured_event_model.dart';

abstract interface class EventCatalogGateway {
  Future<List<FeaturedEventModel>> getFeaturedEvents({
    bool activeOnly,
    bool upcomingOnly,
    int? limit,
  });

  Future<FeaturedEventModel?> getFeaturedEventByTag(String eventTag);
}

class SupabaseEventCatalogGateway implements EventCatalogGateway {
  SupabaseEventCatalogGateway(this._connection);

  final SupabaseConnection _connection;

  @override
  Future<List<FeaturedEventModel>> getFeaturedEvents({
    bool activeOnly = false,
    bool upcomingOnly = false,
    int? limit,
  }) async {
    final client = _connection.client;
    if (client == null) return const <FeaturedEventModel>[];

    try {
      final rows = await client.from('featured_events').select();
      final events = (rows as List)
          .whereType<Map>()
          .map(
            (row) =>
                FeaturedEventModel.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
      Iterable<FeaturedEventModel> result = events;
      if (activeOnly) {
        result = result.where((e) => e.isActive);
      }
      if (upcomingOnly) {
        result = result.where((e) => e.startDate.isAfter(DateTime.now()));
      }
      final list = result.toList(growable: false);
      if (limit != null && list.length > limit) {
        return list.sublist(0, limit);
      }
      return list;
    } catch (error) {
      AppLogger.d('Failed to load featured events: $error');
      return const <FeaturedEventModel>[];
    }
  }

  @override
  Future<FeaturedEventModel?> getFeaturedEventByTag(String eventTag) async {
    final events = await getFeaturedEvents();
    for (final event in events) {
      if (event.eventTag == eventTag) return event;
    }
    return null;
  }
}

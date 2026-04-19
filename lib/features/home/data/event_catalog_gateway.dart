import 'package:injectable/injectable.dart';

import '../../../config/app_config.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/featured_event_model.dart';
import '../../../models/global_challenge_model.dart';
import 'catalog_gateway_shared.dart';

abstract interface class EventCatalogGateway {
  Future<List<FeaturedEventModel>> getFeaturedEvents({
    bool activeOnly,
    bool upcomingOnly,
    int? limit,
  });

  Future<FeaturedEventModel?> getFeaturedEventByTag(String eventTag);

  Future<List<GlobalChallengeModel>> getGlobalChallenges({
    String? eventTag,
    List<String>? regionValues,
    int? limit,
  });
}

@LazySingleton(as: EventCatalogGateway)
class SupabaseEventCatalogGateway implements EventCatalogGateway {
  SupabaseEventCatalogGateway(this._connection);

  final SupabaseConnection _connection;

  @override
  Future<List<FeaturedEventModel>> getFeaturedEvents({
    bool activeOnly = false,
    bool upcomingOnly = false,
    int? limit,
  }) async {
    final fallback = _fallbackFeaturedEvents(
      activeOnly: activeOnly,
      upcomingOnly: upcomingOnly,
      limit: limit,
    );
    final client = _connection.client;
    if (client == null) return fallback;

    try {
      final rows = await client.from('featured_events').select();
      final events = (rows as List)
          .whereType<Map>()
          .map(
            (row) =>
                FeaturedEventModel.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
      final filtered = filterEvents(
        events,
        activeOnly: activeOnly,
        upcomingOnly: upcomingOnly,
        limit: limit,
      );
      return filtered.isEmpty ? fallback : filtered;
    } catch (error) {
      AppLogger.d('Failed to load featured events: $error');
      return fallback;
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

  @override
  Future<List<GlobalChallengeModel>> getGlobalChallenges({
    String? eventTag,
    List<String>? regionValues,
    int? limit,
  }) async {
    final fallback = _fallbackGlobalChallenges(
      eventTag: eventTag,
      regionValues: regionValues,
      limit: limit,
    );
    final client = _connection.client;
    if (client == null) return fallback;

    try {
      final rows = await client.from('global_challenges').select();
      final challenges = (rows as List)
          .whereType<Map>()
          .map(
            (row) =>
                GlobalChallengeModel.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
      final filtered = filterChallenges(
        challenges,
        eventTag: eventTag,
        regionValues: regionValues,
        limit: limit,
      );
      return filtered.isEmpty ? fallback : filtered;
    } catch (error) {
      AppLogger.d('Failed to load global challenges: $error');
      return fallback;
    }
  }

  List<FeaturedEventModel> _fallbackFeaturedEvents({
    bool activeOnly = false,
    bool upcomingOnly = false,
    int? limit,
  }) {
    if (AppConfig.isProduction) return const <FeaturedEventModel>[];
    return filterEvents(
      fallbackEvents(),
      activeOnly: activeOnly,
      upcomingOnly: upcomingOnly,
      limit: limit,
    );
  }

  List<GlobalChallengeModel> _fallbackGlobalChallenges({
    String? eventTag,
    List<String>? regionValues,
    int? limit,
  }) {
    if (AppConfig.isProduction) return const <GlobalChallengeModel>[];
    return filterChallenges(
      fallbackChallenges(),
      eventTag: eventTag,
      regionValues: regionValues,
      limit: limit,
    );
  }
}

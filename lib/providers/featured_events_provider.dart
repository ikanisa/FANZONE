import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/gateway_providers.dart';
import '../models/competition_model.dart';
import '../models/featured_event_model.dart';

final featuredEventsProvider =
    FutureProvider.autoDispose<List<FeaturedEventModel>>((ref) async {
      ref.keepAlive();
      return ref
          .read(eventCatalogGatewayProvider)
          .getFeaturedEvents(activeOnly: true);
    });

final upcomingFeaturedEventsProvider =
    FutureProvider.autoDispose<List<FeaturedEventModel>>((ref) async {
      return ref
          .read(eventCatalogGatewayProvider)
          .getFeaturedEvents(upcomingOnly: true, limit: 5);
    });

final allVisibleEventsProvider =
    FutureProvider.autoDispose<List<FeaturedEventModel>>((ref) async {
      final active = await ref.watch(featuredEventsProvider.future);
      final upcoming = await ref.watch(upcomingFeaturedEventsProvider.future);
      return [...active, ...upcoming];
    });

final featuredEventByTagProvider = FutureProvider.family
    .autoDispose<FeaturedEventModel?, String>((ref, eventTag) async {
      return ref
          .read(eventCatalogGatewayProvider)
          .getFeaturedEventByTag(eventTag);
    });

final featuredCompetitionsProvider =
    FutureProvider.autoDispose<List<CompetitionModel>>((ref) async {
      return ref
          .read(competitionCatalogGatewayProvider)
          .getCompetitions(featuredOnly: true);
    });

final majorCompetitionsProvider =
    FutureProvider.autoDispose<List<FeaturedEventModel>>((ref) async {
      ref.keepAlive();
      return ref.read(eventCatalogGatewayProvider).getFeaturedEvents();
    });

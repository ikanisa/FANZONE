import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/injection.dart';
import '../features/home/data/catalog_gateway.dart';
import '../models/competition_model.dart';
import '../models/featured_event_model.dart';
import '../models/global_challenge_model.dart';
import '../providers/region_provider.dart';

final featuredEventsProvider =
    FutureProvider.autoDispose<List<FeaturedEventModel>>((ref) async {
      ref.keepAlive();
      return getIt<CatalogGateway>().getFeaturedEvents(activeOnly: true);
    });

final upcomingFeaturedEventsProvider =
    FutureProvider.autoDispose<List<FeaturedEventModel>>((ref) async {
      return getIt<CatalogGateway>().getFeaturedEvents(
        upcomingOnly: true,
        limit: 5,
      );
    });

final allVisibleEventsProvider =
    FutureProvider.autoDispose<List<FeaturedEventModel>>((ref) async {
      final active = await ref.watch(featuredEventsProvider.future);
      final upcoming = await ref.watch(upcomingFeaturedEventsProvider.future);
      return [...active, ...upcoming];
    });

final featuredEventByTagProvider = FutureProvider.family
    .autoDispose<FeaturedEventModel?, String>((ref, eventTag) async {
      return getIt<CatalogGateway>().getFeaturedEventByTag(eventTag);
    });

final globalChallengesProvider = FutureProvider.family
    .autoDispose<List<GlobalChallengeModel>, String?>((ref, eventTag) async {
      return getIt<CatalogGateway>().getGlobalChallenges(eventTag: eventTag);
    });

final homeChallengesProvider =
    FutureProvider.autoDispose<List<GlobalChallengeModel>>((ref) async {
      final regionValues = ref.watch(userRegionQueryValuesProvider);
      return getIt<CatalogGateway>().getGlobalChallenges(
        regionValues: regionValues,
        limit: 5,
      );
    });

final featuredCompetitionsProvider =
    FutureProvider.autoDispose<List<CompetitionModel>>((ref) async {
      return getIt<CatalogGateway>().getCompetitions(featuredOnly: true);
    });

final majorCompetitionsProvider =
    FutureProvider.autoDispose<List<FeaturedEventModel>>((ref) async {
      ref.keepAlive();
      return getIt<CatalogGateway>().getFeaturedEvents();
    });

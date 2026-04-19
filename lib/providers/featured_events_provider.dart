import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/supabase_provider.dart';
import '../models/featured_event_model.dart';
import '../models/global_challenge_model.dart';
import '../providers/region_provider.dart';

/// Provider for active featured events.
/// Returns events that are currently active, ordered by start date.
final featuredEventsProvider =
    FutureProvider.autoDispose<List<FeaturedEventModel>>((ref) async {
      ref.keepAlive();
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return const [];

      final now = DateTime.now().toIso8601String();
      final data = await client
          .from('featured_events')
          .select()
          .eq('is_active', true)
          .lte('start_date', now)
          .gte('end_date', now)
          .order('start_date')
          .timeout(supabaseTimeout);

      return (data as List)
          .map((row) => FeaturedEventModel.fromJson(row))
          .toList();
    });

/// Provider for upcoming featured events (not yet started).
final upcomingFeaturedEventsProvider =
    FutureProvider.autoDispose<List<FeaturedEventModel>>((ref) async {
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return const [];

      final now = DateTime.now().toIso8601String();
      final data = await client
          .from('featured_events')
          .select()
          .eq('is_active', true)
          .gt('start_date', now)
          .order('start_date')
          .limit(5)
          .timeout(supabaseTimeout);

      return (data as List)
          .map((row) => FeaturedEventModel.fromJson(row))
          .toList();
    });

/// Combined: active + upcoming events (for the home banner carousel).
final allVisibleEventsProvider =
    FutureProvider.autoDispose<List<FeaturedEventModel>>((ref) async {
      final active = await ref.watch(featuredEventsProvider.future);
      final upcoming = await ref.watch(upcomingFeaturedEventsProvider.future);
      return [...active, ...upcoming];
    });

/// Provider for a single featured event by tag.
final featuredEventByTagProvider = FutureProvider.family
    .autoDispose<FeaturedEventModel?, String>((ref, eventTag) async {
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return null;

      final data = await client
          .from('featured_events')
          .select()
          .eq('event_tag', eventTag)
          .maybeSingle()
          .timeout(supabaseTimeout);

      if (data == null) return null;
      return FeaturedEventModel.fromJson(data);
    });

/// Provider for global challenges, optionally filtered by event tag.
final globalChallengesProvider = FutureProvider.family
    .autoDispose<List<GlobalChallengeModel>, String?>((ref, eventTag) async {
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return const [];

      var query = client
          .from('global_challenges')
          .select()
          .eq('status', 'open');

      if (eventTag != null) {
        query = query.eq('event_tag', eventTag);
      }

      final data = await query
          .order('start_at')
          .limit(20)
          .timeout(supabaseTimeout);

      return (data as List)
          .map((row) => GlobalChallengeModel.fromJson(row))
          .toList();
    });

/// Active challenges for the home screen (all events, user region-aware).
final homeChallengesProvider =
    FutureProvider.autoDispose<List<GlobalChallengeModel>>((ref) async {
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return const [];
      final regionValues = ref.watch(userRegionQueryValuesProvider);
      final regionalFilter = regionValues.length == 1
          ? 'region.eq.${regionValues.first}'
          : 'region.in.(${regionValues.join(',')})';

      final data = await client
          .from('global_challenges')
          .select()
          .eq('status', 'open')
          .or('region.eq.global,$regionalFilter')
          .order('start_at')
          .limit(5)
          .timeout(supabaseTimeout);

      return (data as List)
          .map((row) => GlobalChallengeModel.fromJson(row))
          .toList();
    });

/// Featured competitions (tier-1 with is_featured=true).
final featuredCompetitionsProvider = FutureProvider.autoDispose<List<dynamic>>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const [];

  final data = await client
      .from('competitions')
      .select()
      .eq('is_featured', true)
      .order('name')
      .timeout(supabaseTimeout);

  return data as List;
});

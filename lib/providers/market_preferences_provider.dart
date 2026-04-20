import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/gateway_providers.dart';
import '../core/market/launch_market.dart';
import '../models/featured_event_model.dart';
import '../models/global_challenge_model.dart';
import '../models/user_market_preferences_model.dart';
import 'featured_events_provider.dart';

final userMarketPreferencesProvider =
    FutureProvider.autoDispose<UserMarketPreferences>((ref) async {
      ref.keepAlive();
      return ref
          .read(marketPreferencesGatewayProvider)
          .getUserMarketPreferences();
    });

final primaryMarketRegionProvider = Provider<String>((ref) {
  final preferences =
      ref.watch(userMarketPreferencesProvider).valueOrNull ??
      UserMarketPreferences.defaults;
  return normalizeRegionKey(preferences.primaryRegion);
});

final marketFocusTagsProvider = Provider<Set<String>>((ref) {
  final preferences =
      ref.watch(userMarketPreferencesProvider).valueOrNull ??
      UserMarketPreferences.defaults;
  return preferences.focusEventTags.toSet();
});

final homeLaunchEventsProvider =
    FutureProvider.autoDispose<List<FeaturedEventModel>>((ref) async {
      final preferences = await ref.watch(userMarketPreferencesProvider.future);
      final events = await ref.watch(allVisibleEventsProvider.future);
      return _rankEvents(events, preferences).take(4).toList();
    });

final spotlightChallengesProvider =
    FutureProvider.autoDispose<List<GlobalChallengeModel>>((ref) async {
      final preferences = await ref.watch(userMarketPreferencesProvider.future);
      final challenges = await ref.watch(homeChallengesProvider.future);
      return _rankChallenges(challenges, preferences).take(4).toList();
    });

List<FeaturedEventModel> _rankEvents(
  List<FeaturedEventModel> events,
  UserMarketPreferences preferences,
) {
  final focusTags = preferences.focusEventTags.toSet();
  final primaryRegion = preferences.primaryRegion;

  final ranked = [...events];
  ranked.sort((left, right) {
    final leftScore = _eventScore(left, focusTags, primaryRegion);
    final rightScore = _eventScore(right, focusTags, primaryRegion);
    if (leftScore != rightScore) return rightScore.compareTo(leftScore);
    return left.startDate.compareTo(right.startDate);
  });
  return ranked;
}

List<GlobalChallengeModel> _rankChallenges(
  List<GlobalChallengeModel> challenges,
  UserMarketPreferences preferences,
) {
  final focusTags = preferences.focusEventTags.toSet();
  final primaryRegion = preferences.primaryRegion;

  final ranked = [...challenges];
  ranked.sort((left, right) {
    final leftScore = _challengeScore(left, focusTags, primaryRegion);
    final rightScore = _challengeScore(right, focusTags, primaryRegion);
    if (leftScore != rightScore) return rightScore.compareTo(leftScore);
    final leftStart = left.startAt ?? DateTime.now();
    final rightStart = right.startAt ?? DateTime.now();
    return leftStart.compareTo(rightStart);
  });
  return ranked;
}

int _eventScore(
  FeaturedEventModel event,
  Set<String> focusTags,
  String primaryRegion,
) {
  var score = 0;
  if (focusTags.contains(event.eventTag)) score += 120;
  if (regionKeyMatches(event.region, primaryRegion)) score += 40;
  if (event.isCurrentlyActive) score += 25;

  final daysUntilStart = event.daysUntilStart.abs();
  if (daysUntilStart <= 3) score += 20;
  if (daysUntilStart <= 14) score += 10;

  return score;
}

int _challengeScore(
  GlobalChallengeModel challenge,
  Set<String> focusTags,
  String primaryRegion,
) {
  var score = 0;
  if (focusTags.contains(challenge.eventTag)) score += 120;
  if (regionKeyMatches(challenge.region, primaryRegion)) score += 40;
  if (challenge.isOpen) score += 20;
  if (challenge.entryFeeFet == 0) score += 12;
  if ((challenge.maxParticipants ?? 0) > 0) score += 8;
  return score;
}

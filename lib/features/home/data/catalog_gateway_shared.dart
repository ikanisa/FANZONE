import '../../../models/competition_model.dart';
import '../../../models/featured_event_model.dart';
import '../../../models/global_challenge_model.dart';
import '../../../models/team_model.dart';

/// Filters and sorts competitions by tier and featured status.
List<CompetitionModel> filterCompetitions(
  List<CompetitionModel> competitions, {
  int? tier,
  required bool featuredOnly,
}) {
  var filtered = competitions;
  if (tier != null) {
    filtered = filtered
        .where((competition) => competition.tier == tier)
        .toList(growable: false);
  }
  if (featuredOnly) {
    filtered = filtered
        .where((competition) => competition.isFeatured)
        .toList(growable: false);
  }

  return [...filtered]..sort((left, right) => left.name.compareTo(right.name));
}

/// Filters and sorts teams by competition and featured status.
List<TeamModel> filterTeams(
  List<TeamModel> teams, {
  String? competitionId,
  required bool featuredOnly,
}) {
  var filtered = teams;
  if (competitionId != null && competitionId.isNotEmpty) {
    filtered = filtered
        .where((team) => team.competitionIds.contains(competitionId))
        .toList(growable: false);
  }
  if (featuredOnly) {
    filtered = filtered
        .where((team) => team.isFeatured)
        .toList(growable: false);
  }

  return [...filtered]..sort((left, right) => left.name.compareTo(right.name));
}

/// Filters and sorts featured events.
List<FeaturedEventModel> filterEvents(
  List<FeaturedEventModel> events, {
  required bool activeOnly,
  required bool upcomingOnly,
  int? limit,
}) {
  final now = DateTime.now();
  var filtered =
      events
          .where((event) {
            if (activeOnly) {
              return event.isActive &&
                  !event.startDate.isAfter(now) &&
                  !event.endDate.isBefore(now);
            }
            if (upcomingOnly) {
              return event.startDate.isAfter(now);
            }
            return true;
          })
          .toList(growable: false)
        ..sort((left, right) => left.startDate.compareTo(right.startDate));

  if (limit != null && filtered.length > limit) {
    filtered = filtered.take(limit).toList(growable: false);
  }
  return filtered;
}

/// Filters and sorts global challenges.
List<GlobalChallengeModel> filterChallenges(
  List<GlobalChallengeModel> challenges, {
  String? eventTag,
  List<String>? regionValues,
  int? limit,
}) {
  final normalizedRegions = (regionValues ?? const <String>[])
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .toSet();

  var filtered =
      challenges
          .where((challenge) {
            if (eventTag != null &&
                eventTag.isNotEmpty &&
                challenge.eventTag != eventTag) {
              return false;
            }
            if (normalizedRegions.isNotEmpty &&
                !normalizedRegions.contains(challenge.region.toLowerCase()) &&
                challenge.region.toLowerCase() != 'global') {
              return false;
            }
            return true;
          })
          .toList(growable: false)
        ..sort((left, right) => left.name.compareTo(right.name));

  if (limit != null && filtered.length > limit) {
    filtered = filtered.take(limit).toList(growable: false);
  }
  return filtered;
}

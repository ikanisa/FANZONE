import '../../../core/constants/league_constants.dart';
import '../../../data/team_search_database.dart';
import '../../../models/match_model.dart';

const kDefaultHomeFeaturedClubLimit = 20;

class MatchHomeDisplayOverride {
  const MatchHomeDisplayOverride({
    this.isHomeFeatured = false,
    this.hideFromHome = false,
    this.homeFeatureRank = 0,
  });

  final bool isHomeFeatured;
  final bool hideFromHome;
  final int homeFeatureRank;
}

class HomeFeedSelection {
  const HomeFeedSelection({
    this.liveMatches = const <MatchModel>[],
    this.upcomingMatches = const <MatchModel>[],
  });

  final List<MatchModel> liveMatches;
  final List<MatchModel> upcomingMatches;
}

HomeFeedSelection curateHomeFeedMatches({
  required List<MatchModel> matches,
  required List<OnboardingTeam> defaultHomeTeams,
  required List<FavoriteTeamRecordDto> favoriteTeams,
  Map<String, MatchHomeDisplayOverride> overrides = const {},
  int featuredClubLimit = kDefaultHomeFeaturedClubLimit,
}) {
  final favoriteTeamTokens = favoriteTeams.expand(_favoriteTeamTokens).toSet();

  final defaultFeaturedTeams = defaultHomeTeams
      .take(featuredClubLimit)
      .toList(growable: false);
  final defaultFeaturedTeamTokens = defaultFeaturedTeams
      .expand(_onboardingTeamTokens)
      .toSet();
  final eligibleHomeTokens = {
    ...defaultFeaturedTeamTokens,
    ...favoriteTeamTokens,
  };

  final curated = <MatchModel>[];
  for (final match in matches) {
    if (!match.isLive && !match.isUpcoming) continue;

    final override = overrides[match.id] ?? const MatchHomeDisplayOverride();
    if (override.hideFromHome) continue;

    final isExplicitHomeMatch = override.isHomeFeatured;
    final isDefaultHomeMatch = _matchInvolvesAnyTeam(
      match,
      teamTokens: eligibleHomeTokens,
    );

    if (isExplicitHomeMatch || isDefaultHomeMatch) {
      curated.add(match);
    }
  }

  curated.sort(
    (left, right) => compareHomeFeedMatches(
      left,
      right,
      overrides: overrides,
      favoriteTeamTokens: favoriteTeamTokens,
      defaultFeaturedTeamTokens: defaultFeaturedTeamTokens,
    ),
  );

  return HomeFeedSelection(
    liveMatches: curated.where((match) => match.isLive).toList(growable: false),
    upcomingMatches: curated
        .where((match) => match.isUpcoming)
        .toList(growable: false),
  );
}

List<MatchModel> orderFixtureMatches({
  required List<MatchModel> matches,
  required Map<String, String> competitionNames,
  Map<String, int> competitionRanks = const {},
}) {
  final ordered = [...matches];
  ordered.sort(
    (left, right) => compareFixtureMatches(
      left,
      right,
      competitionNames: competitionNames,
      competitionRanks: competitionRanks,
    ),
  );
  return ordered;
}

int compareHomeFeedMatches(
  MatchModel left,
  MatchModel right, {
  required Map<String, MatchHomeDisplayOverride> overrides,
  required Set<String> favoriteTeamTokens,
  required Set<String> defaultFeaturedTeamTokens,
}) {
  final leftOverride = overrides[left.id] ?? const MatchHomeDisplayOverride();
  final rightOverride = overrides[right.id] ?? const MatchHomeDisplayOverride();

  if (leftOverride.isHomeFeatured != rightOverride.isHomeFeatured) {
    return leftOverride.isHomeFeatured ? -1 : 1;
  }

  final featureRankDiff = rightOverride.homeFeatureRank.compareTo(
    leftOverride.homeFeatureRank,
  );
  if (featureRankDiff != 0) return featureRankDiff;

  final leftFavoriteWeight =
      _matchInvolvesAnyTeam(left, teamTokens: favoriteTeamTokens) ? 0 : 1;
  final rightFavoriteWeight =
      _matchInvolvesAnyTeam(right, teamTokens: favoriteTeamTokens) ? 0 : 1;
  if (leftFavoriteWeight != rightFavoriteWeight) {
    return leftFavoriteWeight.compareTo(rightFavoriteWeight);
  }

  final leftFeaturedWeight =
      _matchInvolvesAnyTeam(left, teamTokens: defaultFeaturedTeamTokens)
      ? 0
      : 1;
  final rightFeaturedWeight =
      _matchInvolvesAnyTeam(right, teamTokens: defaultFeaturedTeamTokens)
      ? 0
      : 1;
  if (leftFeaturedWeight != rightFeaturedWeight) {
    return leftFeaturedWeight.compareTo(rightFeaturedWeight);
  }

  final kickoffDiff = _kickoffSortValue(
    left,
  ).compareTo(_kickoffSortValue(right));
  if (kickoffDiff != 0) return kickoffDiff;

  final labelDiff = _matchLabel(left).compareTo(_matchLabel(right));
  if (labelDiff != 0) return labelDiff;

  return left.id.compareTo(right.id);
}

int compareFixtureMatches(
  MatchModel left,
  MatchModel right, {
  required Map<String, String> competitionNames,
  Map<String, int> competitionRanks = const {},
}) {
  final leftStatusWeight = _fixtureStatusWeight(left);
  final rightStatusWeight = _fixtureStatusWeight(right);
  if (leftStatusWeight != rightStatusWeight) {
    return leftStatusWeight.compareTo(rightStatusWeight);
  }

  final kickoffDiff = _kickoffSortValue(
    left,
  ).compareTo(_kickoffSortValue(right));
  if (kickoffDiff != 0) return kickoffDiff;

  final leftCompetitionRank = _competitionRank(
    left,
    competitionNames,
    competitionRanks,
  );
  final rightCompetitionRank = _competitionRank(
    right,
    competitionNames,
    competitionRanks,
  );
  if (leftCompetitionRank != rightCompetitionRank) {
    return leftCompetitionRank.compareTo(rightCompetitionRank);
  }

  final leftCompetitionLabel = _competitionLabel(left, competitionNames);
  final rightCompetitionLabel = _competitionLabel(right, competitionNames);
  final competitionDiff = leftCompetitionLabel.compareTo(rightCompetitionLabel);
  if (competitionDiff != 0) return competitionDiff;

  final labelDiff = _matchLabel(left).compareTo(_matchLabel(right));
  if (labelDiff != 0) return labelDiff;

  return left.id.compareTo(right.id);
}

bool _matchInvolvesAnyTeam(
  MatchModel match, {
  required Set<String> teamTokens,
}) {
  final matchTokens = <String>{
    ..._tokenVariants(match.homeTeamId),
    ..._tokenVariants(match.awayTeamId),
    ..._tokenVariants(match.homeTeam),
    ..._tokenVariants(match.awayTeam),
  };

  return matchTokens.any(teamTokens.contains);
}

int _competitionRank(
  MatchModel match,
  Map<String, String> competitionNames,
  Map<String, int> competitionRanks,
) {
  return competitionCatalogRank(
    id: match.competitionId,
    name: competitionNames[match.competitionId],
    catalogRank: competitionRanks[match.competitionId],
  );
}

String _competitionLabel(
  MatchModel match,
  Map<String, String> competitionNames,
) {
  return _normalizedToken(
        competitionNames[match.competitionId] ?? match.competitionId,
      ) ??
      match.competitionId;
}

int _fixtureStatusWeight(MatchModel match) {
  if (match.isLive) return 0;
  if (match.isUpcoming) return 1;
  return 2;
}

DateTime _kickoffSortValue(MatchModel match) {
  final kickoff = match.kickoffAtUtc;
  if (kickoff != null) return kickoff;
  return match.date.isUtc ? match.date.toUtc() : match.date;
}

String _matchLabel(MatchModel match) {
  return '${_normalizedToken(match.homeTeam) ?? match.homeTeam}|'
      '${_normalizedToken(match.awayTeam) ?? match.awayTeam}';
}

String? _normalizedToken(String? value) {
  final normalized = _normalizeComparable(value);
  if (normalized == null || normalized.isEmpty) return null;
  return normalized;
}

Iterable<String> _favoriteTeamTokens(FavoriteTeamRecordDto team) sync* {
  yield* _collectTokenVariants([
    team.teamId,
    team.teamName,
    team.teamShortName,
  ]);
}

Iterable<String> _onboardingTeamTokens(OnboardingTeam team) sync* {
  yield* _collectTokenVariants([
    team.id,
    team.name,
    team.shortName,
    ...team.aliases,
  ]);
}

Iterable<String> _collectTokenVariants(Iterable<String?> values) sync* {
  final emitted = <String>{};
  for (final value in values) {
    for (final token in _tokenVariants(value)) {
      if (emitted.add(token)) yield token;
    }
  }
}

Iterable<String> _tokenVariants(String? value) sync* {
  final normalized = _normalizeComparable(value);
  if (normalized == null) return;

  yield normalized;

  final compact = normalized.replaceAll(' ', '');
  if (compact.isNotEmpty && compact != normalized) {
    yield compact;
  }

  final withoutPrefix = _dropLeadingShortCode(normalized);
  if (withoutPrefix != null && withoutPrefix != normalized) {
    yield withoutPrefix;
    final compactWithoutPrefix = withoutPrefix.replaceAll(' ', '');
    if (compactWithoutPrefix.isNotEmpty &&
        compactWithoutPrefix != withoutPrefix) {
      yield compactWithoutPrefix;
    }
  }

  final stripped = _stripFootballTerms(normalized);
  if (stripped != null && stripped != normalized) {
    yield stripped;
    final compactStripped = stripped.replaceAll(' ', '');
    if (compactStripped.isNotEmpty && compactStripped != stripped) {
      yield compactStripped;
    }
  }

  if (withoutPrefix != null) {
    final strippedWithoutPrefix = _stripFootballTerms(withoutPrefix);
    if (strippedWithoutPrefix != null &&
        strippedWithoutPrefix != withoutPrefix) {
      yield strippedWithoutPrefix;
      final compactStrippedWithoutPrefix = strippedWithoutPrefix.replaceAll(
        ' ',
        '',
      );
      if (compactStrippedWithoutPrefix.isNotEmpty &&
          compactStrippedWithoutPrefix != strippedWithoutPrefix) {
        yield compactStrippedWithoutPrefix;
      }
    }
  }
}

String? _normalizeComparable(String? value) {
  if (value == null) return null;

  final folded = _foldToAscii(value.trim().toLowerCase());
  if (folded.isEmpty) return null;

  final normalized = folded
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return normalized.isEmpty ? null : normalized;
}

String _foldToAscii(String value) {
  const replacements = <String, String>{
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'å': 'a',
    'æ': 'ae',
    'ç': 'c',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ñ': 'n',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ø': 'o',
    'œ': 'oe',
    'ß': 'ss',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
  };

  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(replacements[char] ?? char);
  }
  return buffer.toString();
}

String? _dropLeadingShortCode(String value) {
  final parts = value.split(' ').where((part) => part.isNotEmpty).toList();
  if (parts.length < 2) return null;

  final first = parts.first;
  if (first.length > 2 || int.tryParse(first) != null) return null;

  final trimmed = parts.skip(1).join(' ').trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _stripFootballTerms(String value) {
  const stopwords = <String>{
    'club',
    'de',
    'del',
    'fc',
    'cf',
    'afc',
    'ac',
    'sc',
    'rc',
    'cd',
    'ud',
    'fk',
    'sv',
    'ss',
    'as',
  };

  final parts = value.split(' ').where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return null;

  final stripped = parts.where((part) => !stopwords.contains(part)).toList();
  if (stripped.isEmpty || stripped.length == parts.length) return null;

  return stripped.join(' ');
}

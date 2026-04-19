import 'match_model.dart';

enum SearchResultType { competition, team, match }

class SearchResultModel {
  const SearchResultModel({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final SearchResultType type;
  final String id;
  final String title;
  final String subtitle;

  String get route {
    switch (type) {
      case SearchResultType.competition:
        return '/league/$id';
      case SearchResultType.team:
        return '/clubs/team/$id';
      case SearchResultType.match:
        return '/match/$id';
    }
  }
}

class SearchResults {
  const SearchResults({
    this.competitions = const [],
    this.teams = const [],
    this.matches = const [],
  });

  final List<SearchResultModel> competitions;
  final List<SearchResultModel> teams;
  final List<SearchResultModel> matches;

  bool get isEmpty => competitions.isEmpty && teams.isEmpty && matches.isEmpty;

  int get totalCount => competitions.length + teams.length + matches.length;
}

SearchResultModel searchResultFromMatch(MatchModel match) {
  final title = '${match.homeTeam} vs ${match.awayTeam}';
  final status = switch (match.status) {
    'live' => 'LIVE',
    'finished' => 'FT',
    'postponed' => 'POSTPONED',
    _ => match.kickoffLabel,
  };

  return SearchResultModel(
    type: SearchResultType.match,
    id: match.id,
    title: title,
    subtitle: '${match.date.toIso8601String().split('T').first} · $status',
  );
}

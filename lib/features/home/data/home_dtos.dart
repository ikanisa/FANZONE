class MatchesFilter {
  const MatchesFilter({
    this.competitionId,
    this.status,
    this.teamId,
    this.dateFrom,
    this.dateTo,
    this.limit = 100,
    this.ascending = false,
  });

  final String? competitionId;
  final String? status;
  final String? teamId;
  final String? dateFrom;
  final String? dateTo;
  final int limit;
  final bool ascending;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MatchesFilter &&
            runtimeType == other.runtimeType &&
            competitionId == other.competitionId &&
            status == other.status &&
            teamId == other.teamId &&
            dateFrom == other.dateFrom &&
            dateTo == other.dateTo &&
            limit == other.limit &&
            ascending == other.ascending;
  }

  @override
  int get hashCode => Object.hash(
    competitionId,
    status,
    teamId,
    dateFrom,
    dateTo,
    limit,
    ascending,
  );
}

class CompetitionStandingsFilter {
  const CompetitionStandingsFilter({required this.competitionId, this.season});

  final String competitionId;
  final String? season;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CompetitionStandingsFilter &&
            runtimeType == other.runtimeType &&
            competitionId == other.competitionId &&
            season == other.season;
  }

  @override
  int get hashCode => Object.hash(competitionId, season);
}

class SearchQueryDto {
  const SearchQueryDto(this.value);

  final String value;
}

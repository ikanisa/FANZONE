import 'team_search_catalog.dart';

enum FanProfileTeamCategory { local, topEuropean, national }

extension FanProfileTeamCategoryDetails on FanProfileTeamCategory {
  String get source {
    switch (this) {
      case FanProfileTeamCategory.local:
        return 'local';
      case FanProfileTeamCategory.topEuropean:
        return 'top_european';
      case FanProfileTeamCategory.national:
        return 'national';
    }
  }

  String get title {
    switch (this) {
      case FanProfileTeamCategory.local:
        return 'Local team';
      case FanProfileTeamCategory.topEuropean:
        return 'Top European';
      case FanProfileTeamCategory.national:
        return 'National teams';
    }
  }

  String get shortTitle {
    switch (this) {
      case FanProfileTeamCategory.local:
        return 'Local';
      case FanProfileTeamCategory.topEuropean:
        return 'Europe';
      case FanProfileTeamCategory.national:
        return 'National';
    }
  }

  String get helperText {
    switch (this) {
      case FanProfileTeamCategory.local:
        return 'Select one local team.';
      case FanProfileTeamCategory.topEuropean:
        return 'Select one or two top European teams.';
      case FanProfileTeamCategory.national:
        return 'Select one or two national teams.';
    }
  }

  int get maxSelections {
    switch (this) {
      case FanProfileTeamCategory.local:
        return 1;
      case FanProfileTeamCategory.topEuropean:
      case FanProfileTeamCategory.national:
        return 2;
    }
  }

  static FanProfileTeamCategory? fromSource(String source) {
    switch (source.trim().toLowerCase()) {
      case 'local':
        return FanProfileTeamCategory.local;
      case 'top_european':
      case 'popular':
        return FanProfileTeamCategory.topEuropean;
      case 'national':
        return FanProfileTeamCategory.national;
      default:
        return null;
    }
  }
}

class FanProfileSelection {
  const FanProfileSelection({
    this.localTeam,
    this.topEuropeanTeams = const <OnboardingTeam>[],
    this.nationalTeams = const <OnboardingTeam>[],
  });

  final OnboardingTeam? localTeam;
  final List<OnboardingTeam> topEuropeanTeams;
  final List<OnboardingTeam> nationalTeams;

  Set<String> get topEuropeanTeamIds =>
      topEuropeanTeams.map((team) => team.id).toSet();

  Set<String> get nationalTeamIds =>
      nationalTeams.map((team) => team.id).toSet();

  bool get isEmpty =>
      localTeam == null && topEuropeanTeams.isEmpty && nationalTeams.isEmpty;
}

void validateFanProfileSelection({
  OnboardingTeam? localTeam,
  Set<String> topEuropeanTeamIds = const <String>{},
  Set<String> nationalTeamIds = const <String>{},
}) {
  if (topEuropeanTeamIds.length >
      FanProfileTeamCategory.topEuropean.maxSelections) {
    throw ArgumentError.value(
      topEuropeanTeamIds.length,
      'topEuropeanTeamIds',
      'Select no more than two top European teams.',
    );
  }

  if (nationalTeamIds.length > FanProfileTeamCategory.national.maxSelections) {
    throw ArgumentError.value(
      nationalTeamIds.length,
      'nationalTeamIds',
      'Select no more than two national teams.',
    );
  }

  final selectedIds = <String>[
    if (localTeam != null) localTeam.id,
    ...topEuropeanTeamIds,
    ...nationalTeamIds,
  ].where((id) => id.trim().isNotEmpty).toList(growable: false);

  if (selectedIds.length != selectedIds.toSet().length) {
    throw ArgumentError('A team can only be selected once in a fan profile.');
  }
}

Map<FanProfileTeamCategory, List<FavoriteTeamRecordDto>>
groupFanProfileTeamRecords(List<FavoriteTeamRecordDto> rows) {
  final grouped = {
    for (final category in FanProfileTeamCategory.values)
      category: <FavoriteTeamRecordDto>[],
  };

  for (final row in rows) {
    final category =
        FanProfileTeamCategoryDetails.fromSource(row.source) ??
        FanProfileTeamCategory.topEuropean;
    final target = grouped[category]!;
    if (target.length < category.maxSelections) {
      target.add(row);
    }
  }

  return grouped;
}

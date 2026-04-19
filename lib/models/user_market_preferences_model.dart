import '../core/market/launch_market.dart';

class UserMarketPreferences {
  const UserMarketPreferences({
    this.primaryRegion = 'global',
    this.selectedRegions = const ['global'],
    this.focusEventTags = const [],
    this.favoriteCompetitionIds = const [],
    this.followWorldCup = true,
    this.followChampionsLeague = true,
    this.updatedAt,
  });

  final String primaryRegion;
  final List<String> selectedRegions;
  final List<String> focusEventTags;
  final List<String> favoriteCompetitionIds;
  final bool followWorldCup;
  final bool followChampionsLeague;
  final DateTime? updatedAt;

  factory UserMarketPreferences.fromJson(Map<String, dynamic> json) {
    return UserMarketPreferences(
      primaryRegion: normalizeRegionKey(json['primary_region']?.toString()),
      selectedRegions: _normalizeRegions(json['selected_regions']),
      focusEventTags: _asStringList(json['focus_event_tags']),
      favoriteCompetitionIds: _asStringList(json['favorite_competition_ids']),
      followWorldCup: json['follow_world_cup'] as bool? ?? true,
      followChampionsLeague: json['follow_champions_league'] as bool? ?? true,
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.tryParse(json['updated_at'].toString()),
    );
  }

  static const defaults = UserMarketPreferences();

  List<String> get effectiveRegions {
    final values = {
      normalizeRegionKey(primaryRegion),
      ...selectedRegions.map(normalizeRegionKey),
    }..removeWhere((value) => value.isEmpty);

    if (values.isEmpty) return const ['global'];
    return values.toList();
  }

  bool get hasCustomSelections {
    return normalizeRegionKey(primaryRegion) != 'global' ||
        focusEventTags.isNotEmpty ||
        favoriteCompetitionIds.isNotEmpty ||
        selectedRegions.any((value) => normalizeRegionKey(value) != 'global');
  }

  UserMarketPreferences copyWith({
    String? primaryRegion,
    List<String>? selectedRegions,
    List<String>? focusEventTags,
    List<String>? favoriteCompetitionIds,
    bool? followWorldCup,
    bool? followChampionsLeague,
    DateTime? updatedAt,
  }) {
    return UserMarketPreferences(
      primaryRegion: normalizeRegionKey(primaryRegion ?? this.primaryRegion),
      selectedRegions: _normalizeRegions(
        selectedRegions ?? this.selectedRegions,
      ),
      focusEventTags: _asStringList(focusEventTags ?? this.focusEventTags),
      favoriteCompetitionIds: _asStringList(
        favoriteCompetitionIds ?? this.favoriteCompetitionIds,
      ),
      followWorldCup: followWorldCup ?? this.followWorldCup,
      followChampionsLeague:
          followChampionsLeague ?? this.followChampionsLeague,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'primary_region': normalizeRegionKey(primaryRegion),
      'selected_regions': effectiveRegions,
      'focus_event_tags': _asStringList(focusEventTags),
      'favorite_competition_ids': _asStringList(favoriteCompetitionIds),
      'follow_world_cup': followWorldCup,
      'follow_champions_league': followChampionsLeague,
      'updated_at': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
    };
  }

  static List<String> _asStringList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static List<String> _normalizeRegions(dynamic raw) {
    final values = _asStringList(raw).map(normalizeRegionKey).toSet().toList();
    if (values.isEmpty) return const ['global'];
    return values;
  }
}

import '../../core/market/launch_market.dart';

class UserMarketPreferences {
  const UserMarketPreferences({
    this.primaryRegion = 'global',
    this.selectedRegions = const ['global'],
    this.focusEventTags = const [],
    this.followWorldCup = true,
    this.updatedAt,
  });

  final String primaryRegion;
  final List<String> selectedRegions;
  final List<String> focusEventTags;
  final bool followWorldCup;
  final DateTime? updatedAt;

  factory UserMarketPreferences.fromJson(Map<String, dynamic> json) {
    return UserMarketPreferences(
      primaryRegion: normalizeRegionKey(json['primary_region']?.toString()),
      selectedRegions: _normalizeRegions(json['selected_regions']),
      focusEventTags: _asStringList(json['focus_event_tags']),
      followWorldCup: json['follow_world_cup'] as bool? ?? true,
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
        selectedRegions.any((value) => normalizeRegionKey(value) != 'global');
  }

  UserMarketPreferences copyWith({
    String? primaryRegion,
    List<String>? selectedRegions,
    List<String>? focusEventTags,
    bool? followWorldCup,
    DateTime? updatedAt,
  }) {
    return UserMarketPreferences(
      primaryRegion: normalizeRegionKey(primaryRegion ?? this.primaryRegion),
      selectedRegions: _normalizeRegions(
        selectedRegions ?? this.selectedRegions,
      ),
      focusEventTags: _asStringList(focusEventTags ?? this.focusEventTags),
      followWorldCup: followWorldCup ?? this.followWorldCup,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'primary_region': normalizeRegionKey(primaryRegion),
      'selected_regions': effectiveRegions,
      'focus_event_tags': _asStringList(focusEventTags),
      'follow_world_cup': followWorldCup,
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

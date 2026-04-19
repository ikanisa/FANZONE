import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/models/user_market_preferences_model.dart';

void main() {
  group('UserMarketPreferences', () {
    test('fromJson normalizes region values and arrays', () {
      final preferences = UserMarketPreferences.fromJson({
        'primary_region': 'americas',
        'selected_regions': ['global', 'north-america'],
        'focus_event_tags': ['worldcup2026'],
        'favorite_competition_ids': ['ucl'],
      });

      expect(preferences.primaryRegion, 'north_america');
      expect(
        preferences.effectiveRegions,
        containsAll(['global', 'north_america']),
      );
      expect(preferences.focusEventTags, ['worldcup2026']);
      expect(preferences.favoriteCompetitionIds, ['ucl']);
    });

    test('toJson preserves explicit selections', () {
      const preferences = UserMarketPreferences(
        primaryRegion: 'europe',
        selectedRegions: ['global', 'europe', 'africa'],
        focusEventTags: ['ucl-final-2026'],
        favoriteCompetitionIds: ['champions-league'],
        followWorldCup: false,
      );

      final json = preferences.toJson();

      expect(json['primary_region'], 'europe');
      expect(
        json['selected_regions'],
        containsAll(['global', 'europe', 'africa']),
      );
      expect(json['focus_event_tags'], ['ucl-final-2026']);
      expect(json['favorite_competition_ids'], ['champions-league']);
      expect(json['follow_world_cup'], false);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/features/onboarding/data/fan_profile.dart';
import 'package:fanzone/features/onboarding/data/team_search_catalog.dart';

void main() {
  group('fan profile categories', () {
    test('maps legacy popular favorites into top European category', () {
      final grouped = groupFanProfileTeamRecords(const [
        FavoriteTeamRecordDto(
          teamId: 'local',
          teamName: 'Local FC',
          source: 'local',
        ),
        FavoriteTeamRecordDto(
          teamId: 'popular',
          teamName: 'Popular FC',
          source: 'popular',
        ),
        FavoriteTeamRecordDto(
          teamId: 'national',
          teamName: 'National FC',
          source: 'national',
        ),
      ]);

      expect(grouped[FanProfileTeamCategory.local], hasLength(1));
      expect(grouped[FanProfileTeamCategory.topEuropean], hasLength(1));
      expect(grouped[FanProfileTeamCategory.national], hasLength(1));
    });

    test('enforces one local and two-team category limits', () {
      const local = OnboardingTeam(
        id: 'local',
        name: 'Local FC',
        country: 'Rwanda',
      );

      expect(
        () => validateFanProfileSelection(
          localTeam: local,
          topEuropeanTeamIds: {'arsenal', 'barcelona'},
          nationalTeamIds: {'rwanda', 'malta'},
        ),
        returnsNormally,
      );

      expect(
        () => validateFanProfileSelection(
          topEuropeanTeamIds: {'arsenal', 'barcelona', 'madrid'},
        ),
        throwsArgumentError,
      );

      expect(
        () => validateFanProfileSelection(
          localTeam: local,
          topEuropeanTeamIds: {'local'},
        ),
        throwsArgumentError,
      );
    });
  });
}

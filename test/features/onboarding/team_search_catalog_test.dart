import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/features/onboarding/data/team_search_catalog.dart';

void main() {
  group('TeamSearchCatalog', () {
    test('defaults starts empty without bundled football fallbacks', () {
      final catalog = TeamSearchCatalog.defaults();

      expect(catalog.allTeams, isEmpty);
      expect(catalog.popularTeams, isEmpty);
      expect(catalog.popularForRegion('europe'), isEmpty);
    });

    test('local search ranks aliases and prefixes', () {
      final catalog = TeamSearchCatalog([
        const OnboardingTeam(
          id: 'metro-fc',
          name: 'Test Club One',
          country: 'Test Country One',
          aliases: ['Comets'],
        ),
        const OnboardingTeam(
          id: 'harbor-united',
          name: 'Test Club Two',
          country: 'Test Country Two',
          aliases: ['Harbor'],
        ),
        const OnboardingTeam(
          id: 'desert-stars',
          name: 'Test Club Three',
          country: 'Test Country Three',
          aliases: ['Desert'],
        ),
      ]);

      expect(catalog.searchLocal('comets').first.id, 'metro-fc');
      expect(catalog.searchLocal('har').first.id, 'harbor-united');
      expect(catalog.searchLocal('desert').first.id, 'desert-stars');
    });

    test('popular search is scoped to dedicated popular teams', () {
      final catalog = TeamSearchCatalog(
        const [
          OnboardingTeam(
            id: 'metro-fc',
            name: 'Test Club One',
            country: 'Test Country One',
          ),
          OnboardingTeam(
            id: 'desert-stars',
            name: 'Test Club Three',
            country: 'Test Country Three',
          ),
        ],
        popularTeams: const [
          OnboardingTeam(
            id: 'metro-fc',
            name: 'Test Club One',
            country: 'Test Country One',
            popularRank: 1,
          ),
        ],
      );

      expect(catalog.searchPopular('test club one').map((team) => team.id), [
        'metro-fc',
      ]);
      expect(catalog.searchPopular('desert'), isEmpty);
    });

    test('json payload can carry a separate popular teams collection', () {
      final catalog = TeamSearchCatalog.fromRawJson('''
{
  "teams": [
    {
      "id": "harbor-united",
      "name": "Test Club Two",
      "country": "Test Country Two",
      "aliases": ["Harbor"]
    },
    {
      "id": "metro-fc",
      "name": "Test Club One",
      "country": "Test Country One"
    }
  ],
  "popular_teams": [
    {
      "id": "metro-fc",
      "name": "Test Club One",
      "country": "Test Country One",
      "popular_rank": 1
    }
  ]
}
''');

      expect(catalog.allTeams, hasLength(2));
      expect(catalog.popularTeams.map((team) => team.id), ['metro-fc']);
      expect(catalog.popularForRegion('europe').map((team) => team.id), [
        'metro-fc',
      ]);
    });
  });
}

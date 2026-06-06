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

    test('browse filters local, top European, and national catalog groups', () {
      final catalog = TeamSearchCatalog(const [
        OnboardingTeam(
          id: 'valletta',
          name: 'Valletta',
          country: 'Malta',
          league: 'Malta Premier League',
          region: 'europe',
          teamType: 'club',
          countryCodeOverride: 'MT',
        ),
        OnboardingTeam(
          id: 'arsenal',
          name: 'Arsenal',
          country: 'England',
          league: 'Premier League',
          region: 'europe',
          teamType: 'club',
          isPopular: true,
          popularRank: 1,
          countryCodeOverride: 'GB',
        ),
        OnboardingTeam(
          id: 'brazil',
          name: 'Brazil',
          country: 'Brazil',
          league: 'FIFA World Cup 2026',
          region: 'americas',
          teamType: 'national',
          isPopular: true,
          popularRank: 2,
          countryCodeOverride: 'BR',
        ),
      ]);

      expect(
        catalog
            .browse(countryCode: 'MT', localOnly: true)
            .map((team) => team.id),
        ['valletta'],
      );
      expect(
        catalog
            .browse(region: 'europe', popularOnly: true)
            .map((team) => team.id),
        ['arsenal', 'brazil'],
      );
      expect(catalog.browse(nationalOnly: true).map((team) => team.id), [
        'brazil',
      ]);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/features/onboarding/data/team_search_catalog.dart';

void main() {
  group('TeamSearchCatalog', () {
    test('local search ranks aliases and prefixes', () {
      final catalog = TeamSearchCatalog([
        const OnboardingTeam(
          id: 'arsenal',
          name: 'Arsenal',
          country: 'England',
          aliases: ['Gunners'],
        ),
        const OnboardingTeam(
          id: 'hamrun-spartans',
          name: 'Hamrun Spartans',
          country: 'Malta',
          aliases: ['Hamrun'],
        ),
        const OnboardingTeam(
          id: 'apr-fc',
          name: 'APR FC',
          country: 'Rwanda',
          aliases: ['APR'],
        ),
      ]);

      expect(catalog.searchLocal('gunners').first.id, 'arsenal');
      expect(catalog.searchLocal('ham').first.id, 'hamrun-spartans');
      expect(catalog.searchLocal('apr').first.id, 'apr-fc');
    });

    test('popular search is scoped to dedicated popular teams', () {
      final catalog = TeamSearchCatalog(
        const [
          OnboardingTeam(id: 'arsenal', name: 'Arsenal', country: 'England'),
          OnboardingTeam(id: 'apr-fc', name: 'APR FC', country: 'Rwanda'),
        ],
        popularTeams: const [
          OnboardingTeam(
            id: 'arsenal',
            name: 'Arsenal',
            country: 'England',
            popularRank: 1,
          ),
        ],
      );

      expect(catalog.searchPopular('arsenal').map((team) => team.id), [
        'arsenal',
      ]);
      expect(catalog.searchPopular('apr'), isEmpty);
    });

    test('json payload can carry a separate popular teams collection', () {
      final catalog = TeamSearchCatalog.fromRawJson('''
{
  "teams": [
    {
      "id": "hamrun-spartans",
      "name": "Hamrun Spartans",
      "country": "Malta",
      "aliases": ["Hamrun"]
    },
    {
      "id": "arsenal",
      "name": "Arsenal",
      "country": "England"
    }
  ],
  "popular_teams": [
    {
      "id": "arsenal",
      "name": "Arsenal",
      "country": "England",
      "popular_rank": 1
    }
  ]
}
''');

      expect(catalog.allTeams, hasLength(2));
      expect(catalog.popularTeams.map((team) => team.id), ['arsenal']);
      expect(catalog.popularForRegion('europe').map((team) => team.id), [
        'arsenal',
      ]);
    });
  });
}

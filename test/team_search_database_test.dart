import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/data/team_search_database.dart';

void main() {
  final seededCatalog = TeamSearchCatalog(
    const [
      OnboardingTeam(
        id: 'metro-fc',
        name: 'Test Club One',
        country: 'Test Country One',
        league: 'Test League One',
        aliases: ['Comets'],
        region: 'europe',
        isPopular: true,
        popularRank: 1,
      ),
      OnboardingTeam(
        id: 'harbor-united',
        name: 'Test Club Two',
        country: 'Test Country Two',
        league: 'Test League Two',
        aliases: ['Sailors'],
        region: 'europe',
        isPopular: true,
        popularRank: 2,
      ),
      OnboardingTeam(
        id: 'desert-stars',
        name: 'Test Club Three',
        country: 'Test Country Three',
        league: 'Test League Three',
        aliases: ['Desert'],
        region: 'africa',
        isPopular: true,
        popularRank: 3,
      ),
      OnboardingTeam(
        id: 'forest-rangers',
        name: 'Test Club Four',
        country: 'Test Country Four',
        league: 'Test League Four',
        aliases: ['Forest'],
        region: 'africa',
        isPopular: true,
        popularRank: 4,
      ),
      OnboardingTeam(
        id: 'falcon-national',
        name: 'Test National Side',
        country: 'Test Country Five',
        league: 'Test National League',
        aliases: ['Sky Falcons'],
        region: 'americas',
        isPopular: true,
        popularRank: 5,
      ),
      OnboardingTeam(
        id: 'coastal-city',
        name: 'Test Club Five',
        country: 'Test Country Six',
        league: 'Test League Five',
        aliases: ['Coastal'],
        region: 'americas',
        isPopular: true,
        popularRank: 6,
      ),
    ],
    popularTeams: const [
      OnboardingTeam(
        id: 'metro-fc',
        name: 'Test Club One',
        country: 'Test Country One',
        region: 'europe',
        isPopular: true,
        popularRank: 1,
      ),
      OnboardingTeam(
        id: 'harbor-united',
        name: 'Test Club Two',
        country: 'Test Country Two',
        region: 'europe',
        isPopular: true,
        popularRank: 2,
      ),
      OnboardingTeam(
        id: 'desert-stars',
        name: 'Test Club Three',
        country: 'Test Country Three',
        region: 'africa',
        isPopular: true,
        popularRank: 3,
      ),
      OnboardingTeam(
        id: 'forest-rangers',
        name: 'Test Club Four',
        country: 'Test Country Four',
        region: 'africa',
        isPopular: true,
        popularRank: 4,
      ),
      OnboardingTeam(
        id: 'falcon-national',
        name: 'Test National Side',
        country: 'Test Country Five',
        region: 'americas',
        isPopular: true,
        popularRank: 5,
      ),
      OnboardingTeam(
        id: 'coastal-city',
        name: 'Test Club Five',
        country: 'Test Country Six',
        region: 'americas',
        isPopular: true,
        popularRank: 6,
      ),
    ],
  );

  setUp(() {
    initTeamSearchDatabase(catalog: seededCatalog);
  });

  tearDown(() {
    initTeamSearchDatabase(catalog: TeamSearchCatalog.empty());
  });

  group('OnboardingTeam', () {
    test('has correct properties', () {
      const team = OnboardingTeam(
        id: 'test-1',
        name: 'Test FC',
        country: 'Testland',
        league: 'Test League',
        aliases: ['TFC', 'Testers'],
        region: 'europe',
        isPopular: true,
      );

      expect(team.id, 'test-1');
      expect(team.name, 'Test FC');
      expect(team.country, 'Testland');
      expect(team.league, 'Test League');
      expect(team.aliases, ['TFC', 'Testers']);
      expect(team.region, 'europe');
      expect(team.isPopular, true);
    });

    test('defaults are correct', () {
      const team = OnboardingTeam(
        id: 'test-2',
        name: 'Basic FC',
        country: 'Basicland',
      );

      expect(team.aliases, isEmpty);
      expect(team.region, 'global');
      expect(team.isPopular, false);
      expect(team.league, isNull);
    });
  });

  group('searchTeams', () {
    test('returns empty list for empty query', () {
      expect(searchTeams(''), isEmpty);
      expect(searchTeams('   '), isEmpty);
    });

    test('finds team by name', () {
      final results = searchTeams('Test Club One');
      expect(results, isNotEmpty);
      expect(results.first.name, 'Test Club One');
    });

    test('finds team by alias', () {
      final results = searchTeams('Sailors');
      expect(results, isNotEmpty);
      expect(results.first.name, 'Test Club Two');
    });

    test('search is case-insensitive', () {
      final lower = searchTeams('test club one');
      final upper = searchTeams('TEST CLUB ONE');
      final mixed = searchTeams('TeSt ClUb OnE');

      expect(lower, isNotEmpty);
      expect(upper, isNotEmpty);
      expect(mixed, isNotEmpty);

      // All should find the same team
      expect(lower.first.id, upper.first.id);
      expect(lower.first.id, mixed.first.id);
    });

    test('respects limit parameter', () {
      final results = searchTeams('League', limit: 3);
      expect(results.length, lessThanOrEqualTo(3));
    });

    test('finds partial matches', () {
      final results = searchTeams('Co');
      expect(results, isNotEmpty);
    });

    test('returns empty for non-existent team', () {
      final results = searchTeams('xyznonexistent123');
      expect(results, isEmpty);
    });

    test('finds seeded regional clubs', () {
      final results = searchTeams('Desert');
      expect(results, isNotEmpty);
      expect(results.first.country, 'Test Country Three');
    });

    test('finds another seeded regional club', () {
      final results = searchTeams('Forest');
      expect(results, isNotEmpty);
      expect(results.first.country, 'Test Country Four');
    });

    test('finds national teams', () {
      final results = searchTeams('Sky Falcons');
      expect(results, isNotEmpty);
      expect(results.first.name, 'Test National Side');
    });
  });

  group('popularTeamsForRegion', () {
    test('returns popular teams for global', () {
      final results = popularTeamsForRegion('global');
      expect(results, isNotEmpty);
      expect(results.every((t) => t.isPopular), isTrue);
    });

    test('returns regional popular teams for africa', () {
      final results = popularTeamsForRegion('africa');
      expect(results, isNotEmpty);
      expect(results.any((t) => t.region == 'africa'), isTrue);
    });

    test('returns regional popular teams for europe', () {
      final results = popularTeamsForRegion('europe');
      expect(results, isNotEmpty);
      expect(results.any((t) => t.region == 'europe'), isTrue);
    });

    test('pads sparse regions with other available popular teams', () {
      final results = popularTeamsForRegion('americas');
      expect(results.length, greaterThanOrEqualTo(2));
      expect(results.any((t) => t.region == 'americas'), isTrue);
    });

    test('returns available popular teams for any requested region', () {
      for (final region in ['global', 'europe', 'africa', 'americas']) {
        final results = popularTeamsForRegion(region);
        expect(
          results,
          isNotEmpty,
          reason: 'Region $region should not be empty',
        );
      }
    });
  });
}

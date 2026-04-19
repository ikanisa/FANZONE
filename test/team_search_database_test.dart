import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/data/team_search_database.dart';

void main() {
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
      final results = searchTeams('Liverpool');
      expect(results, isNotEmpty);
      expect(results.first.name, 'Liverpool');
    });

    test('finds team by alias', () {
      final results = searchTeams('Gunners');
      expect(results, isNotEmpty);
      expect(results.first.name, 'Arsenal');
    });

    test('search is case-insensitive', () {
      final lower = searchTeams('barcelona');
      final upper = searchTeams('BARCELONA');
      final mixed = searchTeams('BarCeLoNa');

      expect(lower, isNotEmpty);
      expect(upper, isNotEmpty);
      expect(mixed, isNotEmpty);

      // All should find the same team
      expect(lower.first.id, upper.first.id);
      expect(lower.first.id, mixed.first.id);
    });

    test('respects limit parameter', () {
      final results = searchTeams('FC', limit: 3);
      expect(results.length, lessThanOrEqualTo(3));
    });

    test('finds partial matches', () {
      final results = searchTeams('Man');
      expect(results.length, greaterThanOrEqualTo(2)); // Man City + Man United
    });

    test('returns empty for non-existent team', () {
      final results = searchTeams('xyznonexistent123');
      expect(results, isEmpty);
    });

    test('finds Rwandan teams', () {
      final results = searchTeams('APR');
      expect(results, isNotEmpty);
      expect(results.first.country, 'Rwanda');
    });

    test('finds Maltese teams', () {
      final results = searchTeams('Valletta');
      expect(results, isNotEmpty);
      expect(results.first.country, 'Malta');
    });

    test('finds national teams', () {
      final results = searchTeams('Three Lions');
      expect(results, isNotEmpty);
      expect(results.first.name, 'England');
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
      // Should contain African teams
      expect(
        results.any((t) => t.region == 'africa'),
        isTrue,
      );
    });

    test('returns regional popular teams for malta', () {
      final results = popularTeamsForRegion('malta');
      expect(results, isNotEmpty);
      expect(
        results.any((t) => t.region == 'malta'),
        isTrue,
      );
    });

    test('pads sparse regions with global popular teams', () {
      // If a region has fewer than 8 popular teams, should pad with globals
      final results = popularTeamsForRegion('americas');
      expect(results.length, greaterThanOrEqualTo(8));
    });

    test('returns at least 8 teams for any region', () {
      for (final region in ['global', 'europe', 'africa', 'malta', 'americas']) {
        final results = popularTeamsForRegion(region);
        expect(
          results.length,
          greaterThanOrEqualTo(8),
          reason: 'Region $region should have at least 8 popular teams',
        );
      }
    });
  });
}

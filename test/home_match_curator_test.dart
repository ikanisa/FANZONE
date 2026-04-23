import 'package:flutter_test/flutter_test.dart';

import 'package:fanzone/data/team_search_database.dart';
import 'package:fanzone/features/home/data/home_match_curator.dart';

import 'support/test_fixtures.dart';

void main() {
  group('home match curator', () {
    test(
      'curates home feed from featured clubs, favorite teams, and admin overrides',
      () {
        final matches = [
          sampleMatch(
            id: 'featured_match',
            competitionId: 'competition_top',
            homeTeamId: 'test-club-a',
            awayTeamId: 'test-club-b',
            homeTeam: 'Test Club A FC',
            awayTeam: 'Test Club B',
            kickoffTime: '18:00',
          ),
          sampleMatch(
            id: 'favorite_match',
            competitionId: 'competition_local',
            homeTeamId: 'test-club-c',
            awayTeamId: 'test-club-d',
            homeTeam: 'Test Club C',
            awayTeam: 'Test Club D',
            kickoffTime: '19:00',
          ),
          sampleMatch(
            id: 'admin_match',
            competitionId: 'competition_local',
            homeTeamId: 'test-club-e',
            awayTeamId: 'test-club-f',
            homeTeam: 'Test Club E',
            awayTeam: 'Test Club F',
            kickoffTime: '16:00',
          ),
          sampleMatch(
            id: 'hidden_match',
            competitionId: 'competition_hidden',
            homeTeamId: 'test-club-g',
            awayTeamId: 'test-club-h',
            homeTeam: 'Test Club G',
            awayTeam: 'Test Club H',
            kickoffTime: '20:00',
          ),
        ];

        final selection = curateHomeFeedMatches(
          matches: matches,
          defaultHomeTeams: const [
            OnboardingTeam(
              id: 'test-club-a',
              name: 'Test Club A',
              country: 'Test Country A',
              shortNameOverride: 'TCA',
              aliases: ['Test Club A FC', 'Alpha Side'],
            ),
            OnboardingTeam(
              id: 'test-club-g',
              name: 'Test Club G',
              country: 'Test Country B',
              shortNameOverride: 'TCG',
              aliases: ['Test Club G FC', 'Gamma Side'],
            ),
          ],
          favoriteTeams: const [
            FavoriteTeamRecordDto(
              teamId: 'test-club-c',
              teamName: 'Test Club C',
              teamShortName: 'Club C',
              source: 'local',
            ),
          ],
          overrides: const {
            'admin_match': MatchHomeDisplayOverride(
              isHomeFeatured: true,
              homeFeatureRank: 90,
            ),
            'hidden_match': MatchHomeDisplayOverride(hideFromHome: true),
          },
        );

        expect(selection.upcomingMatches.map((match) => match.id).toList(), [
          'admin_match',
          'favorite_match',
          'featured_match',
        ]);
      },
    );

    test('orders fixtures by kickoff time then competition priority', () {
      final ordered = orderFixtureMatches(
        matches: [
          sampleMatch(
            id: 'local_match',
            competitionId: 'cpl',
            kickoffTime: '12:00',
          ),
          sampleMatch(
            id: 'top_tiebreak',
            competitionId: 'epl',
            kickoffTime: '16:00',
          ),
          sampleMatch(
            id: 'regional_mid',
            competitionId: 'la-liga',
            kickoffTime: '16:00',
          ),
          sampleMatch(
            id: 'top_early',
            competitionId: 'epl',
            kickoffTime: '15:00',
          ),
        ],
        competitionNames: const {
          'epl': 'Premier League',
          'la-liga': 'La Liga',
          'cpl': 'Test Competition Local',
        },
      );

      expect(ordered.map((match) => match.id).toList(), [
        'local_match',
        'top_early',
        'top_tiebreak',
        'regional_mid',
      ]);
    });
  });
}

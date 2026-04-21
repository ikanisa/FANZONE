import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/core/supabase/supabase_connection.dart';
import 'package:fanzone/features/home/data/competition_catalog_gateway.dart';
import 'package:fanzone/features/home/data/home_dtos.dart';
import 'package:fanzone/features/home/data/match_listing_gateway.dart';
import 'package:fanzone/features/home/data/sports_data_exception.dart';
import 'package:fanzone/features/home/data/team_catalog_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _NullSupabaseConnection implements SupabaseConnection {
  @override
  Stream<AuthState> get authStateChanges => const Stream<AuthState>.empty();

  @override
  SupabaseClient? get client => null;

  @override
  User? get currentUser => null;

  @override
  Session? get currentSession => null;

  @override
  bool get isAuthenticated => false;

  @override
  bool get isInitialized => false;
}

void main() {
  final connection = _NullSupabaseConnection();

  group('sports data gateways surface unavailable errors', () {
    test('match listing throws instead of returning an empty list', () async {
      final gateway = SupabaseMatchListingGateway(connection);

      await expectLater(
        gateway.getMatches(
          MatchesFilter(
            dateFrom: DateTime(2026, 4, 21).toIso8601String(),
            dateTo: DateTime(2026, 4, 21, 23, 59, 59).toIso8601String(),
          ),
        ),
        throwsA(isA<SportsDataUnavailableException>()),
      );
    });

    test('team catalog throws instead of returning an empty list', () async {
      final gateway = SupabaseTeamCatalogGateway(connection);

      await expectLater(
        gateway.getTeams(competitionId: 'epl'),
        throwsA(isA<SportsDataUnavailableException>()),
      );
    });

    test('team details throw instead of returning null', () async {
      final gateway = SupabaseTeamCatalogGateway(connection);

      await expectLater(
        gateway.getTeam('arsenal'),
        throwsA(isA<SportsDataUnavailableException>()),
      );
    });

    test(
      'competition catalog throws instead of returning an empty list',
      () async {
        final gateway = SupabaseCompetitionCatalogGateway(connection);

        await expectLater(
          gateway.getCompetitions(),
          throwsA(isA<SportsDataUnavailableException>()),
        );
      },
    );

    test(
      'competition standings throw instead of returning an empty list',
      () async {
        final gateway = SupabaseCompetitionCatalogGateway(connection);

        await expectLater(
          gateway.getCompetitionStandings(
            const CompetitionStandingsFilter(competitionId: 'epl'),
          ),
          throwsA(isA<SportsDataUnavailableException>()),
        );
      },
    );
  });
}

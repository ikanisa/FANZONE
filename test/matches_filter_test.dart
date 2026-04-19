import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/providers/matches_provider.dart';

void main() {
  group('MatchesFilter', () {
    test('default values', () {
      const filter = MatchesFilter();
      expect(filter.competitionId, isNull);
      expect(filter.status, isNull);
      expect(filter.teamId, isNull);
      expect(filter.dateFrom, isNull);
      expect(filter.dateTo, isNull);
      expect(filter.limit, 100);
      expect(filter.ascending, false);
    });

    test('equality — same params are equal', () {
      const a = MatchesFilter(
        competitionId: 'comp-1',
        status: 'live',
        teamId: 'team-1',
        limit: 50,
        ascending: true,
      );
      const b = MatchesFilter(
        competitionId: 'comp-1',
        status: 'live',
        teamId: 'team-1',
        limit: 50,
        ascending: true,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality — different params are not equal', () {
      const a = MatchesFilter(competitionId: 'comp-1');
      const b = MatchesFilter(competitionId: 'comp-2');

      expect(a, isNot(equals(b)));
    });

    test('inequality — different limit', () {
      const a = MatchesFilter(limit: 10);
      const b = MatchesFilter(limit: 20);

      expect(a, isNot(equals(b)));
    });

    test('inequality — different ascending', () {
      const a = MatchesFilter(ascending: true);
      const b = MatchesFilter(ascending: false);

      expect(a, isNot(equals(b)));
    });

    test('equality with dateFrom and dateTo', () {
      const a = MatchesFilter(dateFrom: '2026-01-01', dateTo: '2026-12-31');
      const b = MatchesFilter(dateFrom: '2026-01-01', dateTo: '2026-12-31');

      expect(a, equals(b));
    });

    test('identical returns true for same instance', () {
      const filter = MatchesFilter(competitionId: 'comp-1');
      // ignore: unrelated_type_equality_checks
      expect(identical(filter, filter), isTrue);
    });

    test('not equal to non-MatchesFilter', () {
      const filter = MatchesFilter();
      // ignore: unrelated_type_equality_checks
      expect(filter == 'not a filter', isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/core/constants/league_constants.dart';

void main() {
  test('competition catalog rank follows the curated order', () {
    final ranked =
        [
          ('epl', 'English Premier League'),
          ('wc-2026', 'FIFA World Cup 2026'),
          ('champions-league', 'UEFA Champions League'),
          ('serie-a', 'Serie A'),
          ('la-liga', 'La Liga'),
          ('bundesliga', 'Bundesliga'),
          ('ligue-1', 'Ligue 1'),
        ]..sort(
          (left, right) => competitionCatalogRankByIdName(
            left.$1,
            left.$2,
          ).compareTo(competitionCatalogRankByIdName(right.$1, right.$2)),
        );

    expect(
      ranked.map((competition) => competition.$1).toList(growable: false),
      [
        'champions-league',
        'epl',
        'la-liga',
        'ligue-1',
        'bundesliga',
        'serie-a',
        'wc-2026',
      ],
    );
  });
}

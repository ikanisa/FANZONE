import 'package:fanzone/core/utils/team_name_cleanup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('team name cleanup', () {
    test('flags raw slot placeholders without stripping real club names', () {
      expect(isPlaceholderTeamName('1A'), isTrue);
      expect(isPlaceholderTeamName('3A/B/C/D/F'), isTrue);
      expect(isPlaceholderTeamName('W74'), isTrue);
      expect(isPlaceholderTeamName('L102'), isTrue);
      expect(isPlaceholderTeamName('1. FC Koln'), isFalse);
      expect(isPlaceholderTeamName('1. FC Köln'), isFalse);
      expect(isPlaceholderTeamName('1899 Hoffenheim'), isFalse);
    });

    test('normalizes bracket placeholders into consumer-facing labels', () {
      expect(normalizeTeamDisplayName('1A'), 'Winner Group A');
      expect(normalizeTeamDisplayName('2B'), 'Runner-up Group B');
      expect(
        normalizeTeamDisplayName('3A/B/C/D/F'),
        'Best 3rd Place Groups A/B/C/D/F',
      );
      expect(normalizeTeamDisplayName('W74'), 'Winner Match 74');
      expect(normalizeTeamDisplayName('L102'), 'Loser Match 102');
      expect(normalizeTeamDisplayName('1. FC Köln'), 'FC Köln');
      expect(normalizeTeamDisplayName('1. FSV Mainz 05'), 'FSV Mainz 05');
      expect(normalizeTeamDisplayName('12 de Octubre'), '12 de Octubre');
    });
  });
}

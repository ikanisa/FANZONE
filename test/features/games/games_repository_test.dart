import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/features/games/data/games_repository.dart';

void main() {
  group('gameEdgeFunctionName', () {
    test('maps product game templates to deployed Supabase Edge Functions', () {
      expect(gameEdgeFunctionName('fan_trivia'), 'fan-trivia');
      expect(gameEdgeFunctionName('song_guess'), 'song-guess');
      expect(gameEdgeFunctionName('music_bingo'), 'music-bingo');
    });

    test('keeps unsupported legacy templates on direct RPC fallback', () {
      expect(gameEdgeFunctionName('bar_trivia'), isNull);
      expect(gameEdgeFunctionName(null), isNull);
    });
  });

  group('unwrapGameEdgeData', () {
    test('returns the Edge Function data payload', () {
      expect(
        unwrapGameEdgeData({
          'success': true,
          'game': 'fan_trivia',
          'action': 'join_team',
          'data': {'joined': true},
        }),
        {'joined': true},
      );
    });

    test('throws the Edge Function error message', () {
      expect(
        () => unwrapGameEdgeData({
          'success': false,
          'error': 'Music Bingo does not accept trivia answers',
        }),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('gameQuestionFromPayload', () {
    test('parses RPC list payloads', () {
      final question = gameQuestionFromPayload([
        {
          'question_id': 'question_1',
          'ordinal': 2,
          'prompt': 'Who scored first?',
          'options': [
            {'label': 'Home'},
            {'label': 'Away'},
          ],
        },
      ]);

      expect(question?.questionId, 'question_1');
      expect(question?.ordinal, 2);
      expect(question?.prompt, 'Who scored first?');
      expect(question?.options, ['Home', 'Away']);
    });

    test('parses Edge Function object payloads', () {
      final question = gameQuestionFromPayload({
        'question_id': 'question_2',
        'ordinal': 1,
        'prompt': 'Name the track.',
        'options': ['Song A', 'Song B'],
      });

      expect(question?.questionId, 'question_2');
      expect(question?.ordinal, 1);
      expect(question?.options, ['Song A', 'Song B']);
    });

    test('returns null for empty question payloads', () {
      expect(gameQuestionFromPayload([]), isNull);
      expect(gameQuestionFromPayload(null), isNull);
    });
  });
}

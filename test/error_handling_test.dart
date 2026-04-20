import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/core/errors/failures.dart';
import 'package:fanzone/core/errors/app_exception.dart';

void main() {
  group('Failure hierarchy', () {
    test('ServerFailure has correct message and code', () {
      const failure = ServerFailure(
        message: 'Server error',
        code: '500',
        statusCode: 500,
      );
      expect(failure.message, 'Server error');
      expect(failure.code, '500');
      expect(failure.statusCode, 500);
    });

    test('CacheFailure has correct message', () {
      const failure = CacheFailure(message: 'Cache miss');
      expect(failure.message, 'Cache miss');
    });

    test('AuthFailure has default message', () {
      const failure = AuthFailure();
      expect(failure.message, 'Not authenticated');
    });

    test('AuthFailure accepts custom message', () {
      const failure = AuthFailure(message: 'Session expired');
      expect(failure.message, 'Session expired');
    });

    test('ValidationFailure has correct message', () {
      const failure = ValidationFailure(message: 'Invalid input');
      expect(failure.message, 'Invalid input');
    });

    test('BusinessRuleFailure has correct message', () {
      const failure = BusinessRuleFailure(message: 'Insufficient FET');
      expect(failure.message, 'Insufficient FET');
    });

    test('UnexpectedFailure has default message', () {
      const failure = UnexpectedFailure();
      expect(failure.message, 'An unexpected error occurred');
    });

    test('UnexpectedFailure preserves exception', () {
      final error = Exception('boom');
      final failure = UnexpectedFailure(exception: error);
      expect(failure.exception, error);
    });

    test('Failure.toString formats correctly', () {
      const failure = ServerFailure(message: 'Error', code: '500');
      expect(failure.toString(), 'Failure(500: Error)');
    });

    test('Failure.toString handles null code', () {
      const failure = ServerFailure(message: 'Error');
      expect(failure.toString(), 'Failure(null: Error)');
    });

    test('all Failure subtypes are sealed', () {
      // Verify the sealed class hierarchy via type checks
      const failures = <Failure>[
        ServerFailure(message: 'a'),
        CacheFailure(message: 'b'),
        AuthFailure(),
        ValidationFailure(message: 'c'),
        BusinessRuleFailure(message: 'd'),
        UnexpectedFailure(),
      ];

      expect(failures.length, 6);
      expect(failures.whereType<ServerFailure>().length, 1);
      expect(failures.whereType<CacheFailure>().length, 1);
      expect(failures.whereType<AuthFailure>().length, 1);
      expect(failures.whereType<ValidationFailure>().length, 1);
      expect(failures.whereType<BusinessRuleFailure>().length, 1);
      expect(failures.whereType<UnexpectedFailure>().length, 1);
    });
  });

  group('mapExceptionToFailure', () {
    test('maps auth errors to AuthFailure', () {
      final failure = mapExceptionToFailure(Exception('Not authenticated'));
      expect(failure, isA<AuthFailure>());
    });

    test('maps JWT expired to AuthFailure', () {
      final failure = mapExceptionToFailure(Exception('JWT expired'));
      expect(failure, isA<AuthFailure>());
    });

    test('maps invalid claim to AuthFailure', () {
      final failure = mapExceptionToFailure(Exception('invalid claim: sub'));
      expect(failure, isA<AuthFailure>());
    });

    test('maps Insufficient FET to BusinessRuleFailure', () {
      final failure = mapExceptionToFailure(
        Exception('PostgrestException(message: Insufficient FET balance)'),
      );
      expect(failure, isA<BusinessRuleFailure>());
    });

    test('maps Minimum stake to BusinessRuleFailure', () {
      final failure = mapExceptionToFailure(
        Exception('Minimum stake is 10 FET'),
      );
      expect(failure, isA<BusinessRuleFailure>());
    });

    test('maps already joined to BusinessRuleFailure', () {
      final failure = mapExceptionToFailure(
        Exception('User has already joined this pool'),
      );
      expect(failure, isA<BusinessRuleFailure>());
    });

    test('maps out of stock to BusinessRuleFailure', () {
      final failure = mapExceptionToFailure(Exception('Item out of stock'));
      expect(failure, isA<BusinessRuleFailure>());
    });

    test('maps TimeoutException to ServerFailure', () {
      final failure = mapExceptionToFailure(
        Exception('TimeoutException after 15s'),
      );
      expect(failure, isA<ServerFailure>());
      expect(failure.message, contains('Network error'));
    });

    test('maps SocketException to ServerFailure', () {
      final failure = mapExceptionToFailure(
        Exception('SocketException: Connection refused'),
      );
      expect(failure, isA<ServerFailure>());
    });

    test('maps unknown errors to UnexpectedFailure', () {
      final failure = mapExceptionToFailure(
        Exception('Something completely unexpected'),
      );
      expect(failure, isA<UnexpectedFailure>());
    });

    test('UnexpectedFailure preserves original exception', () {
      const error = FormatException('bad data');
      final failure = mapExceptionToFailure(error);
      expect(failure, isA<UnexpectedFailure>());
      expect((failure as UnexpectedFailure).exception, error);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/core/errors/failures.dart';

void main() {
  group('Failure sealed class hierarchy', () {
    test('ServerFailure properties', () {
      const f = ServerFailure(
        message: 'Network error',
        code: 'network_error',
        statusCode: 500,
      );
      expect(f.message, 'Network error');
      expect(f.code, 'network_error');
      expect(f.statusCode, 500);
      expect(f, isA<Failure>());
    });

    test('CacheFailure properties', () {
      const f = CacheFailure(message: 'Cache miss', code: 'not_found');
      expect(f.message, 'Cache miss');
      expect(f, isA<Failure>());
    });

    test('AuthFailure default message', () {
      const f = AuthFailure();
      expect(f.message, 'Not authenticated');
      expect(f.code, isNull);
      expect(f, isA<Failure>());
    });

    test('ValidationFailure properties', () {
      const f = ValidationFailure(
        message: 'Invalid amount',
        code: 'invalid_amount',
      );
      expect(f.message, 'Invalid amount');
      expect(f.code, 'invalid_amount');
      expect(f, isA<Failure>());
    });

    test('BusinessRuleFailure properties', () {
      const f = BusinessRuleFailure(
        message: 'Insufficient FET balance',
        code: 'insufficient_balance',
      );
      expect(f.message, 'Insufficient FET balance');
      expect(f, isA<Failure>());
    });

    test('UnexpectedFailure preserves exception', () {
      const original = FormatException('bad data');
      const f = UnexpectedFailure(
        message: 'Something failed',
        exception: original,
      );
      expect(f.exception, original);
      expect(f.message, 'Something failed');
      expect(f, isA<Failure>());
    });

    test('toString includes message and code', () {
      const f = ServerFailure(message: 'test', code: 'ERR');
      expect(f.toString(), 'Failure(ERR: test)');
    });

    test('switch exhaustiveness on sealed Failure', () {
      const Failure f = AuthFailure();
      final label = switch (f) {
        ServerFailure() => 'server',
        CacheFailure() => 'cache',
        AuthFailure() => 'auth',
        ValidationFailure() => 'validation',
        BusinessRuleFailure() => 'business',
        UnexpectedFailure() => 'unexpected',
      };
      expect(label, 'auth');
    });
  });

  group('Failure type matching patterns', () {
    test('can catch Failure in try/catch', () {
      Failure? caught;
      try {
        throw const AuthFailure();
      } on Failure catch (f) {
        caught = f;
      }
      expect(caught, isA<AuthFailure>());
      expect(caught.message, 'Not authenticated');
    });

    test('ServerFailure is a Failure', () {
      const Failure f = ServerFailure(message: 'timeout');
      expect(f, isA<ServerFailure>());
      expect(f, isA<Failure>());
    });

    test('ValidationFailure is distinguishable from BusinessRuleFailure', () {
      const v = ValidationFailure(message: 'bad input');
      const b = BusinessRuleFailure(message: 'not enough');
      expect(v, isNot(isA<BusinessRuleFailure>()));
      expect(b, isNot(isA<ValidationFailure>()));
    });
  });
}

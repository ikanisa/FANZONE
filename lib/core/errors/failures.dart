/// Typed failure classes for domain-layer error handling.
///
/// Use instead of raw exceptions so that UI can map to user-friendly messages
/// without parsing strings.
sealed class Failure {
  const Failure({required this.message, this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'Failure($code: $message)';
}

/// Server / network returned an error.
class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code, this.statusCode});
  final int? statusCode;
}

/// Local cache miss or corruption.
class CacheFailure extends Failure {
  const CacheFailure({required super.message, super.code});
}

/// User is not authenticated when the operation requires it.
class AuthFailure extends Failure {
  const AuthFailure({super.message = 'Not authenticated', super.code});
}

/// Validation of input data failed.
class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.code});
}

/// A business rule was violated (e.g. insufficient balance).
class BusinessRuleFailure extends Failure {
  const BusinessRuleFailure({required super.message, super.code});
}

/// An unknown / unexpected error.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure({
    super.message = 'An unexpected error occurred',
    super.code,
    this.exception,
  });
  final Object? exception;
}

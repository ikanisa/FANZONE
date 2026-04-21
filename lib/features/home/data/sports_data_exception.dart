class SportsDataException implements Exception {
  const SportsDataException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class SportsDataUnavailableException extends SportsDataException {
  const SportsDataUnavailableException([
    super.message = 'Sports data is unavailable right now.',
  ]);
}

class SportsDataQueryException extends SportsDataException {
  const SportsDataQueryException(super.message, {super.cause});
}

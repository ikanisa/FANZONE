import 'failures.dart';

/// Converts raw Supabase / platform exceptions into typed [Failure]s.
///
/// Call from repository implementations to normalise errors before
/// they reach the domain layer.
Failure mapExceptionToFailure(Object error, [StackTrace? stack]) {
  final message = error.toString();

  // Supabase auth errors
  if (message.contains('Not authenticated') ||
      message.contains('JWT expired') ||
      message.contains('invalid claim')) {
    return const AuthFailure();
  }

  // Supabase RPC business-rule exceptions (RAISE EXCEPTION in plpgsql)
  if (message.contains('Insufficient FET') ||
      message.contains('Insufficient balance') ||
      message.contains('Amount must be greater than zero') ||
      message.contains('exactly 6 digits') ||
      message.contains('Fan ID not found') ||
      message.contains('not enabled') ||
      message.contains('not found or inactive') ||
      message.contains('no longer open') ||
      message.contains('already joined') ||
      message.contains('already submitted a prediction') ||
      message.contains('out of stock')) {
    return BusinessRuleFailure(message: _extractRpcMessage(message));
  }

  // Network / timeout
  if (message.contains('TimeoutException') ||
      message.contains('SocketException') ||
      message.contains('Connection refused') ||
      message.contains('Failed host lookup') ||
      message.contains('unavailable right now')) {
    return const ServerFailure(
      message: 'Network error. Check your connection and try again.',
      code: 'network_error',
    );
  }

  return UnexpectedFailure(message: message, exception: error);
}

/// Extracts the user-readable message from a Supabase RPC exception string.
///
/// Format: `PostgrestException(message: <msg>, code: <code>, ...)`
String _extractRpcMessage(String raw) {
  final match = RegExp(r'message:\s*(.+?)(?:,|\))').firstMatch(raw);
  return match?.group(1)?.trim() ?? raw;
}

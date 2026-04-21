import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

String extractAuthFunctionErrorMessage(
  Object error, {
  required String fallbackMessage,
}) {
  if (error is AuthException && error.message.isNotEmpty) {
    return error.message;
  }

  if (error is FunctionException) {
    final message = _extractFunctionDetailsMessage(error.details);
    if (message != null && message.isNotEmpty) {
      return message;
    }
    if (error.reasonPhrase != null && error.reasonPhrase!.isNotEmpty) {
      return error.reasonPhrase!;
    }
  }

  return fallbackMessage;
}

String? _extractFunctionDetailsMessage(dynamic details) {
  if (details == null) return null;

  if (details is Map) {
    final error = details['error'];
    if (error is String && error.isNotEmpty) {
      return error;
    }

    final message = details['message'];
    if (message is String && message.isNotEmpty) {
      return message;
    }

    return null;
  }

  if (details is String) {
    final trimmed = details.trim();
    if (trimmed.isEmpty) return null;

    try {
      final decoded = jsonDecode(trimmed);
      return _extractFunctionDetailsMessage(decoded);
    } catch (_) {
      return trimmed;
    }
  }

  return null;
}

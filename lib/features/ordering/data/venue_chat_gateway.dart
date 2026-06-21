import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/app_config.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/hospitality/venue_chat_model.dart';

abstract interface class VenueChatGateway {
  Future<List<VenueChatThreadModel>> fetchVenueChatThreads(String venueId);

  Future<VenueChatThreadModel> createVenueChatThread({
    required String venueId,
    required String initialMessage,
    String topic = 'general',
    String? subject,
    String? orderId,
    String? supportRequestId,
  });

  Future<VenueChatMessageModel> sendVenueChatMessage({
    required String threadId,
    required String body,
  });
}

class SupabaseVenueChatGateway implements VenueChatGateway {
  SupabaseVenueChatGateway(this._connection);

  final SupabaseConnection _connection;

  @override
  Future<List<VenueChatThreadModel>> fetchVenueChatThreads(
    String venueId,
  ) async {
    final client = _requireClient();

    final threadRows = await client
        .from('venue_chat_threads')
        .select()
        .eq('venue_id', venueId)
        .order('last_message_at', ascending: false)
        .limit(50);

    final threads = (threadRows as List)
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
    if (threads.isEmpty) return const [];

    final threadIds = threads
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    final messageRows = await client
        .from('venue_chat_messages')
        .select()
        .eq('venue_id', venueId)
        .inFilter('thread_id', threadIds)
        .order('created_at', ascending: true);

    final messagesByThread = <String, List<VenueChatMessageModel>>{};
    for (final row in (messageRows as List).whereType<Map>()) {
      final message = VenueChatMessageModel.fromJson(
        Map<String, dynamic>.from(row),
      );
      messagesByThread.putIfAbsent(message.threadId, () => []).add(message);
    }

    return threads
        .map(
          (row) => VenueChatThreadModel.fromJson(
            row,
            messages: messagesByThread[row['id']?.toString()] ?? const [],
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<VenueChatThreadModel> createVenueChatThread({
    required String venueId,
    required String initialMessage,
    String topic = 'general',
    String? subject,
    String? orderId,
    String? supportRequestId,
  }) async {
    _assertReviewMutationAllowed('Venue chat');
    final client = _requireClient();

    try {
      final payload = await client.rpc(
        'create_venue_chat_thread',
        params: {
          'p_venue_id': venueId,
          'p_initial_message': initialMessage.trim(),
          'p_topic': topic.trim(),
          'p_subject': subject?.trim(),
          'p_order_id': _blankToNull(orderId),
          'p_support_request_id': _blankToNull(supportRequestId),
        },
      );
      return _threadFromRpc(payload);
    } catch (error) {
      AppLogger.w('Failed to create venue chat thread: $error');
      rethrow;
    }
  }

  @override
  Future<VenueChatMessageModel> sendVenueChatMessage({
    required String threadId,
    required String body,
  }) async {
    _assertReviewMutationAllowed('Venue chat');
    final client = _requireClient();

    try {
      final payload = await client.rpc(
        'send_venue_chat_message',
        params: {'p_thread_id': threadId, 'p_body': body.trim()},
      );
      return _messageFromRpc(payload);
    } catch (error) {
      AppLogger.w('Failed to send venue chat message: $error');
      rethrow;
    }
  }

  SupabaseClient _requireClient() {
    final client = _connection.client;
    final userId = _connection.currentUser?.id;
    if (client == null || userId == null) {
      throw const AuthException('Sign in to chat with venue staff.');
    }
    return client;
  }

  void _assertReviewMutationAllowed(String action) {
    if (!AppConfig.isReviewMode) return;
    throw StateError(
      '$action is disabled in the FANZONE review PWA. Use staging-safe test data for browser review.',
    );
  }
}

VenueChatThreadModel _threadFromRpc(Object? payload) {
  final map = Map<String, dynamic>.from(payload as Map);
  final thread = Map<String, dynamic>.from(map['thread'] as Map);
  final message = map['message'] is Map
      ? VenueChatMessageModel.fromJson(
          Map<String, dynamic>.from(map['message']),
        )
      : null;
  return VenueChatThreadModel.fromJson(thread, messages: [?message]);
}

VenueChatMessageModel _messageFromRpc(Object? payload) {
  final map = Map<String, dynamic>.from(payload as Map);
  return VenueChatMessageModel.fromJson(
    Map<String, dynamic>.from(map['message'] as Map),
  );
}

String? _blankToNull(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

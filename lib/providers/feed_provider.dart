import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/supabase_provider.dart';
import '../models/feed_message_model.dart';

/// Realtime messages for a given channel.
/// Key format: "{channelType}:{channelId}" (e.g. "match:abc123")
final AutoDisposeStreamProviderFamily<List<FeedMessage>, String>
feedMessagesProvider = StreamProvider.family
    .autoDispose<List<FeedMessage>, String>((ref, channelKey) async* {
      final client = ref.watch(supabaseClientProvider);
      if (client == null) {
        yield const [];
        return;
      }

      final parts = channelKey.split(':');
      if (parts.length < 2) {
        yield const [];
        return;
      }
      final channelType = parts[0];
      final channelId = parts.sublist(1).join(':');

      yield* client
          .from('feed_messages')
          .stream(primaryKey: ['id'])
          .eq('channel_type', channelType)
          .map((rows) {
            final messages =
                rows
                    .where((row) =>
                        row['channel_id'] == channelId &&
                        row['is_deleted'] == false)
                    .map(
                      (row) =>
                          FeedMessage.fromJson(Map<String, dynamic>.from(row)),
                    )
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return messages.take(100).toList(growable: false);
          });
    });

// ─── Send Message (RPC) ────────────────────────────────────────────

/// Send a message to a channel using the rate-limited RPC.
Future<void> sendFeedMessage({
  required dynamic client,
  required String channelType,
  required String channelId,
  required String content,
  String? replyTo,
}) async {
  await client.rpc(
    'send_feed_message',
    params: {
      'p_channel_type': channelType,
      'p_channel_id': channelId,
      'p_content': content,
      'p_reply_to': ?replyTo,
    },
  );
}

// ─── React to Message (RPC) ────────────────────────────────────────

/// Add a reaction emoji to a message.
Future<void> reactToMessage({
  required dynamic client,
  required String messageId,
  required String emoji,
}) async {
  await client.rpc(
    'react_to_message',
    params: {'p_message_id': messageId, 'p_emoji': emoji},
  );
}

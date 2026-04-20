import 'dart:async';

import '../../../core/cache/cache_service.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/feed_message_model.dart';
import 'community_gateway_shared.dart';

abstract interface class FeedGateway {
  Stream<List<FeedMessage>> watchFeedMessages(
    String channelType,
    String channelId,
  );

  Future<void> sendFeedMessage({
    required String channelType,
    required String channelId,
    required String content,
    String? replyTo,
  });

  Future<void> reactToMessage({
    required String messageId,
    required String emoji,
  });
}

class SupabaseFeedGateway implements FeedGateway {
  SupabaseFeedGateway(this._cache, this._connection);

  static const _feedPrefix = 'community.feed.';
  static const _pollInterval = Duration(seconds: 10);

  final CacheService _cache;
  final SupabaseConnection _connection;

  @override
  Stream<List<FeedMessage>> watchFeedMessages(
    String channelType,
    String channelId,
  ) async* {
    yield await _loadFeedMessages(channelType, channelId);
    while (true) {
      await Future<void>.delayed(_pollInterval);
      yield await _loadFeedMessages(channelType, channelId);
    }
  }

  @override
  Future<void> sendFeedMessage({
    required String channelType,
    required String channelId,
    required String content,
    String? replyTo,
  }) async {
    _requireUserId();
    final client = _connection.client;

    if (client == null) {
      _throwUnavailable('Sending a feed message');
    }

    try {
      await client.rpc(
        'send_feed_message',
        params: {
          'p_channel_type': channelType,
          'p_channel_id': channelId,
          'p_content': content,
          'p_reply_to': replyTo,
        },
      );
    } catch (error) {
      AppLogger.d('Failed to send feed message remotely: $error');
      rethrow;
    }
  }

  @override
  Future<void> reactToMessage({
    required String messageId,
    required String emoji,
  }) async {
    final userId = _connection.currentUser?.id;
    final client = _connection.client;
    if (client == null || userId == null) {
      _throwUnavailable('Reacting to a feed message');
    }

    try {
      await client.rpc(
        'react_to_message',
        params: {'p_message_id': messageId, 'p_emoji': emoji},
      );
    } catch (error) {
      AppLogger.d('Failed to react to message: $error');
      rethrow;
    }
  }

  Future<List<FeedMessage>> _loadFeedMessages(
    String channelType,
    String channelId,
  ) async {
    final client = _connection.client;
    if (client != null) {
      try {
        final rows = await client
            .from('feed_messages')
            .select()
            .eq('channel_type', channelType)
            .eq('channel_id', channelId)
            .order('created_at');
        final messages = (rows as List)
            .whereType<Map>()
            .map((row) => FeedMessage.fromJson(Map<String, dynamic>.from(row)))
            .toList(growable: false);
        await _cache.setJson(
          _feedKey(channelType, channelId),
          messages.map(feedMessageToJson).toList(growable: false),
        );
        return messages;
      } catch (error) {
        AppLogger.d('Failed to load feed messages: $error');
      }
    }

    final rows = await _cache.getJsonList(
      _feedKey(channelType, channelId),
      debugLabel: 'community feed',
    );
    return rows.map(FeedMessage.fromJson).toList(growable: false);
  }

  String _feedKey(String channelType, String channelId) =>
      '$_feedPrefix$channelType.$channelId';

  String _requireUserId() {
    final userId = _connection.currentUser?.id;
    if (userId == null) {
      throw StateError('Not authenticated');
    }
    return userId;
  }

  Never _throwUnavailable(String action) {
    throw StateError('$action is unavailable right now. Please try again.');
  }
}

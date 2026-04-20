import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/gateway_providers.dart';
import '../models/feed_message_model.dart';

final AutoDisposeStreamProviderFamily<List<FeedMessage>, String>
feedMessagesProvider = StreamProvider.family
    .autoDispose<List<FeedMessage>, String>((ref, channelKey) {
      final parts = channelKey.split(':');
      if (parts.length < 2) {
        return Stream<List<FeedMessage>>.value(const []);
      }

      final channelType = parts[0];
      final channelId = parts.sublist(1).join(':');
      return ref
          .read(feedGatewayProvider)
          .watchFeedMessages(channelType, channelId);
    });

Future<void> sendFeedMessage(
  WidgetRef ref, {
  required String channelType,
  required String channelId,
  required String content,
  String? replyTo,
}) {
  return ref
      .read(feedGatewayProvider)
      .sendFeedMessage(
        channelType: channelType,
        channelId: channelId,
        content: content,
        replyTo: replyTo,
      );
}

Future<void> reactToMessage(
  WidgetRef ref, {
  required String messageId,
  required String emoji,
}) {
  return ref
      .read(feedGatewayProvider)
      .reactToMessage(messageId: messageId, emoji: emoji);
}

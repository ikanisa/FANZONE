import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/injection.dart';
import '../features/community/data/community_gateway.dart';
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
      return getIt<CommunityGateway>().watchFeedMessages(channelType, channelId);
    });

Future<void> sendFeedMessage({
  required String channelType,
  required String channelId,
  required String content,
  String? replyTo,
}) {
  return getIt<CommunityGateway>().sendFeedMessage(
    channelType: channelType,
    channelId: channelId,
    content: content,
    replyTo: replyTo,
  );
}

Future<void> reactToMessage({
  required String messageId,
  required String emoji,
}) {
  return getIt<CommunityGateway>().reactToMessage(
    messageId: messageId,
    emoji: emoji,
  );
}

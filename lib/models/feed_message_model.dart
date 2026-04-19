/// Social feed message (pool chat, match chat, team chat, global).
/// Maps to `public.feed_messages` (migration 014).
class FeedMessage {
  final String id;
  final String channelType; // 'pool', 'match', 'team', 'global'
  final String channelId;
  final String userId;
  final String messageType; // 'text', 'prediction', 'reaction', 'system'
  final String content;
  final String? replyTo;
  final Map<String, int> reactions;
  final bool isDeleted;
  final DateTime createdAt;

  const FeedMessage({
    required this.id,
    required this.channelType,
    required this.channelId,
    required this.userId,
    this.messageType = 'text',
    required this.content,
    this.replyTo,
    this.reactions = const {},
    this.isDeleted = false,
    required this.createdAt,
  });

  factory FeedMessage.fromJson(Map<String, dynamic> json) {
    final rawReactions = json['reactions'];
    final reactions = <String, int>{};
    if (rawReactions is Map) {
      for (final entry in rawReactions.entries) {
        reactions[entry.key.toString()] =
            (entry.value is int) ? entry.value : int.tryParse('${entry.value}') ?? 0;
      }
    }

    return FeedMessage(
      id: json['id'] as String,
      channelType: json['channel_type'] as String,
      channelId: json['channel_id'] as String,
      userId: json['user_id'] as String,
      messageType: json['message_type'] as String? ?? 'text',
      content: json['content'] as String,
      replyTo: json['reply_to'] as String?,
      reactions: reactions,
      isDeleted: json['is_deleted'] as bool? ?? false,
      createdAt: DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  bool get isSystem => messageType == 'system';
  bool get isPrediction => messageType == 'prediction';
  bool get hasReactions => reactions.isNotEmpty;

  /// Total reactions count.
  int get totalReactions =>
      reactions.values.fold(0, (sum, count) => sum + count);
}

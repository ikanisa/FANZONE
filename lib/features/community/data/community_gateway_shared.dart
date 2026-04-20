import '../../../models/feed_message_model.dart';
import '../../../models/team_contribution_model.dart';

/// Serializes a [TeamContributionModel] for local cache storage.
Map<String, dynamic> teamContributionToJson(
  TeamContributionModel contribution,
) {
  return {
    'id': contribution.id,
    'team_id': contribution.teamId,
    'contribution_type': contribution.contributionType,
    'amount_fet': contribution.amountFet,
    'amount_money': contribution.amountMoney,
    'currency_code': contribution.currencyCode,
    'status': contribution.status,
    'provider': contribution.provider,
    'created_at': contribution.createdAt.toIso8601String(),
  };
}

/// Serializes a [FeedMessage] for local cache storage.
Map<String, dynamic> feedMessageToJson(FeedMessage message) {
  return {
    'id': message.id,
    'channel_type': message.channelType,
    'channel_id': message.channelId,
    'user_id': message.userId,
    'message_type': message.messageType,
    'content': message.content,
    'reply_to': message.replyTo,
    'reactions': message.reactions,
    'is_deleted': message.isDeleted,
    'created_at': message.createdAt.toIso8601String(),
  };
}

/// Generates a deterministic anonymous fan ID from a user ID.
String fallbackAnonymousFanId(String userId) {
  final digits = userId.replaceAll(RegExp(r'[^0-9]'), '');
  final suffix = digits.isEmpty
      ? '0000'
      : digits.padLeft(4, '0').substring(0, 4);
  return 'FAN$suffix';
}

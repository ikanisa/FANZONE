import '../../../models/feed_message_model.dart';
import '../../../models/team_contribution_model.dart';
import '../../../models/team_news_model.dart';

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

List<TeamNewsModel> seedTeamNews(String teamId) {
  return [
    TeamNewsModel(
      id: 'news_${teamId}_1',
      teamId: teamId,
      title: '${communityTeamName(teamId)} build momentum for the run-in',
      summary: 'Form, confidence, and supporter noise are all trending upward.',
      content:
          'The squad enters the next matchday with a strong recent record and positive momentum from the fan base.',
      category: TeamNewsCategory.general,
      status: 'published',
      sourceName: 'FANZONE Wire',
      publishedAt: DateTime.now().subtract(const Duration(hours: 6)),
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
    ),
  ];
}

String communityTeamName(String teamId) {
  switch (teamId) {
    case 'arsenal':
      return 'Arsenal';
    case 'barcelona':
      return 'Barcelona';
    case 'real-madrid':
      return 'Real Madrid';
    default:
      return 'Liverpool';
  }
}

String fallbackAnonymousFanId(String userId) {
  final digits = userId.replaceAll(RegExp(r'[^0-9]'), '');
  final suffix = digits.isEmpty
      ? '0000'
      : digits.padLeft(4, '0').substring(0, 4);
  return 'FAN$suffix';
}

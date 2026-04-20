import '../../../models/feed_message_model.dart';
import '../../../models/team_contribution_model.dart';
import '../../../models/team_news_model.dart';
import '../../../models/team_supporter_model.dart';
import 'feed_gateway.dart';
import 'team_news_gateway.dart';
import 'team_support_gateway.dart';

export 'feed_gateway.dart';
export 'team_news_gateway.dart';
export 'team_support_gateway.dart';

abstract interface class CommunityGateway
    implements TeamSupportGateway, TeamNewsGateway, FeedGateway {}

class SupabaseCommunityGateway implements CommunityGateway {
  SupabaseCommunityGateway(this._support, this._news, this._feed);

  final TeamSupportGateway _support;
  final TeamNewsGateway _news;
  final FeedGateway _feed;

  @override
  Future<int> contributeFet(String teamId, int amount) {
    return _support.contributeFet(teamId, amount);
  }

  @override
  Future<List<Map<String, dynamic>>> getFeaturedTeamsRaw() {
    return _support.getFeaturedTeamsRaw();
  }

  @override
  Future<List<AnonymousFanRecord>> getTeamAnonymousFans(
    String teamId, {
    int limit = 50,
  }) {
    return _support.getTeamAnonymousFans(teamId, limit: limit);
  }

  @override
  Future<TeamCommunityStats?> getTeamCommunityStats(String teamId) {
    return _support.getTeamCommunityStats(teamId);
  }

  @override
  Future<List<TeamContributionModel>> getTeamContributionHistory(
    String userId,
    String teamId,
  ) {
    return _support.getTeamContributionHistory(userId, teamId);
  }

  @override
  Future<List<TeamNewsModel>> getTeamNews(
    String teamId, {
    String? category,
    int limit = 20,
  }) {
    return _news.getTeamNews(teamId, category: category, limit: limit);
  }

  @override
  Future<TeamNewsModel?> getTeamNewsDetail(String newsId) {
    return _news.getTeamNewsDetail(newsId);
  }

  @override
  Future<Set<String>> getSupportedTeamIds(String userId) {
    return _support.getSupportedTeamIds(userId);
  }

  @override
  Future<void> reactToMessage({
    required String messageId,
    required String emoji,
  }) {
    return _feed.reactToMessage(messageId: messageId, emoji: emoji);
  }

  @override
  Future<void> sendFeedMessage({
    required String channelType,
    required String channelId,
    required String content,
    String? replyTo,
  }) {
    return _feed.sendFeedMessage(
      channelType: channelType,
      channelId: channelId,
      content: content,
      replyTo: replyTo,
    );
  }

  @override
  Future<String?> supportTeam(String teamId) {
    return _support.supportTeam(teamId);
  }

  @override
  Future<void> unsupportTeam(String teamId) {
    return _support.unsupportTeam(teamId);
  }

  @override
  Stream<List<FeedMessage>> watchFeedMessages(
    String channelType,
    String channelId,
  ) {
    return _feed.watchFeedMessages(channelType, channelId);
  }
}

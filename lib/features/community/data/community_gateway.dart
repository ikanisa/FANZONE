import 'dart:async';

import 'package:injectable/injectable.dart';

import '../../../core/cache/cache_service.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/feed_message_model.dart';
import '../../../models/team_contribution_model.dart';
import '../../../models/team_news_model.dart';
import '../../../models/team_supporter_model.dart';

abstract interface class CommunityGateway {
  Future<Set<String>> getSupportedTeamIds(String userId);

  Future<String?> supportTeam(String teamId);

  Future<void> unsupportTeam(String teamId);

  Future<TeamCommunityStats?> getTeamCommunityStats(String teamId);

  Future<List<AnonymousFanRecord>> getTeamAnonymousFans(
    String teamId, {
    int limit,
  });

  Future<int> contributeFet(String teamId, int amount);

  Future<List<TeamContributionModel>> getTeamContributionHistory(
    String userId,
    String teamId,
  );

  Future<List<TeamNewsModel>> getTeamNews(
    String teamId, {
    String? category,
    int limit,
  });

  Future<TeamNewsModel?> getTeamNewsDetail(String newsId);

  Future<List<Map<String, dynamic>>> getFeaturedTeamsRaw();

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

@LazySingleton(as: CommunityGateway)
class SupabaseCommunityGateway implements CommunityGateway {
  SupabaseCommunityGateway(this._cache, this._connection);

  static const _supportedPrefix = 'community.supported.';
  static const _contributionPrefix = 'community.contributions.';
  static const _feedPrefix = 'community.feed.';
  static const _balancePrefix = 'community.balance.';

  final CacheService _cache;
  final SupabaseConnection _connection;
  final Map<String, StreamController<List<FeedMessage>>> _feedControllers =
      <String, StreamController<List<FeedMessage>>>{};

  @override
  Future<Set<String>> getSupportedTeamIds(String userId) async {
    final cached = (await _cache.getStringList('$_supportedPrefix$userId'))
        .toSet();
    final client = _connection.client;
    if (client == null) return cached;

    try {
      final rows = await client
          .from('team_supporters')
          .select('team_id')
          .eq('user_id', userId)
          .eq('is_active', true);
      final supported = (rows as List)
          .whereType<Map>()
          .map((row) => row['team_id']?.toString())
          .whereType<String>()
          .toSet();
      if (supported.isNotEmpty) {
        await _cache.setStringList(
          '$_supportedPrefix$userId',
          supported.toList()..sort(),
        );
        return supported;
      }
      return cached;
    } catch (error) {
      AppLogger.d('Failed to load supported teams: $error');
      return cached;
    }
  }

  @override
  Future<String?> supportTeam(String teamId) async {
    final userId = _requireUserId();
    final next = {...await getSupportedTeamIds(userId), teamId}.toList()..sort();
    await _cache.setStringList('$_supportedPrefix$userId', next);

    final client = _connection.client;
    if (client == null) {
      return _fallbackAnonymousFanId(userId);
    }

    try {
      final row = await client
          .from('team_supporters')
          .upsert(
            {
              'team_id': teamId,
              'user_id': userId,
              'anonymous_fan_id': _fallbackAnonymousFanId(userId),
              'joined_at': DateTime.now().toUtc().toIso8601String(),
              'is_active': true,
            },
            onConflict: 'team_id,user_id',
          )
          .select('anonymous_fan_id')
          .single();
      return row['anonymous_fan_id']?.toString();
    } catch (error) {
      AppLogger.d('Failed to support team: $error');
      return _fallbackAnonymousFanId(userId);
    }
  }

  @override
  Future<void> unsupportTeam(String teamId) async {
    final userId = _requireUserId();
    final next = {...await getSupportedTeamIds(userId)}..remove(teamId);
    await _cache.setStringList(
      '$_supportedPrefix$userId',
      next.toList()..sort(),
    );

    final client = _connection.client;
    if (client == null) return;

    try {
      await client
          .from('team_supporters')
          .update({'is_active': false})
          .eq('user_id', userId)
          .eq('team_id', teamId);
    } catch (error) {
      AppLogger.d('Failed to unsupport team: $error');
    }
  }

  @override
  Future<TeamCommunityStats?> getTeamCommunityStats(String teamId) async {
    final client = _connection.client;
    if (client != null) {
      try {
        final row = await client
            .from('team_community_stats')
            .select()
            .eq('team_id', teamId)
            .maybeSingle();
        if (row != null) {
          return TeamCommunityStats.fromJson(Map<String, dynamic>.from(row));
        }
      } catch (error) {
        AppLogger.d('Failed to load team community stats: $error');
      }
    }

    final supporters = await getTeamAnonymousFans(teamId);
    final totalFet = await _cachedContributionTotal(teamId);
    return TeamCommunityStats(
      teamId: teamId,
      teamName: _teamName(teamId),
      fanCount: supporters.length + 120,
      totalFetContributed: totalFet,
      contributionCount: supporters.isEmpty ? 0 : 4,
      supportersLast30d: 18,
    );
  }

  @override
  Future<List<AnonymousFanRecord>> getTeamAnonymousFans(
    String teamId, {
    int limit = 50,
  }) async {
    final client = _connection.client;
    if (client != null) {
      try {
        final rows = await client
            .from('team_supporters')
            .select('anonymous_fan_id, joined_at')
            .eq('team_id', teamId)
            .eq('is_active', true)
            .order('joined_at', ascending: false)
            .limit(limit);
        final supporters = (rows as List)
            .whereType<Map>()
            .map(
              (row) => AnonymousFanRecord.fromJson(
                Map<String, dynamic>.from(row),
              ),
            )
            .toList(growable: false);
        if (supporters.isNotEmpty) return supporters;
      } catch (error) {
        AppLogger.d('Failed to load anonymous fans: $error');
      }
    }

    final count = limit.clamp(0, 6);
    return List<AnonymousFanRecord>.generate(
      count,
      (index) => AnonymousFanRecord(
        anonymousFanId: 'FAN${1000 + index}',
        joinedAt: DateTime.now().subtract(Duration(days: index + 1)),
      ),
      growable: false,
    );
  }

  @override
  Future<int> contributeFet(String teamId, int amount) async {
    final userId = _requireUserId();
    final history = await getTeamContributionHistory(userId, teamId);
    final contribution = TeamContributionModel(
      id: 'contribution_${DateTime.now().millisecondsSinceEpoch}',
      teamId: teamId,
      contributionType: 'fet',
      amountFet: amount,
      status: 'completed',
      createdAt: DateTime.now(),
    );

    final next = [contribution, ...history];
    await _cache.setJson(
      _contributionKey(userId, teamId),
      next.map((row) => _contributionToJson(row)).toList(growable: false),
    );

    final balanceKey = '$_balancePrefix$userId';
    final currentBalance =
        int.tryParse(await _cache.getString(balanceKey) ?? '') ?? 1000;
    final balanceAfter = (currentBalance - amount).clamp(0, 100000);
    await _cache.setString(balanceKey, '$balanceAfter');

    final client = _connection.client;
    if (client != null) {
      try {
        await client.from('team_contributions').insert({
          'team_id': teamId,
          'user_id': userId,
          'contribution_type': 'fet',
          'amount_fet': amount,
          'status': 'completed',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (error) {
        AppLogger.d('Failed to persist team contribution: $error');
      }
    }

    return balanceAfter;
  }

  @override
  Future<List<TeamContributionModel>> getTeamContributionHistory(
    String userId,
    String teamId,
  ) async {
    final cachedRows = await _cache.getJsonList(
      _contributionKey(userId, teamId),
      debugLabel: 'team contributions',
    );
    final cached = cachedRows
        .map(TeamContributionModel.fromJson)
        .toList(growable: false);

    final client = _connection.client;
    if (client == null) return cached;

    try {
      final rows = await client
          .from('team_contributions')
          .select()
          .eq('user_id', userId)
          .eq('team_id', teamId)
          .order('created_at', ascending: false);
      final contributions = (rows as List)
          .whereType<Map>()
          .map(
            (row) => TeamContributionModel.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(growable: false);
      if (contributions.isNotEmpty) {
        await _cache.setJson(
          _contributionKey(userId, teamId),
          contributions
              .map((row) => _contributionToJson(row))
              .toList(growable: false),
        );
        return contributions;
      }
      return cached;
    } catch (error) {
      AppLogger.d('Failed to load contribution history: $error');
      return cached;
    }
  }

  @override
  Future<List<TeamNewsModel>> getTeamNews(
    String teamId, {
    String? category,
    int limit = 20,
  }) async {
    final client = _connection.client;
    if (client != null) {
      try {
        var query = client
            .from('team_news')
            .select()
            .eq('team_id', teamId)
            .eq('status', 'published');
        if (category != null && category.isNotEmpty) {
          query = query.eq('category', category);
        }
        final rows = await query.order('published_at', ascending: false).limit(limit);
        final news = (rows as List)
            .whereType<Map>()
            .map((row) => TeamNewsModel.fromJson(Map<String, dynamic>.from(row)))
            .toList(growable: false);
        if (news.isNotEmpty) return news;
      } catch (error) {
        AppLogger.d('Failed to load team news: $error');
      }
    }

    final seeded = _seedNews(teamId);
    final filtered = category == null || category.isEmpty
        ? seeded
        : seeded.where((item) => item.category == category).toList(growable: false);
    return filtered.take(limit).toList(growable: false);
  }

  @override
  Future<TeamNewsModel?> getTeamNewsDetail(String newsId) async {
    final client = _connection.client;
    if (client != null) {
      try {
        final row = await client
            .from('team_news')
            .select()
            .eq('id', newsId)
            .maybeSingle();
        if (row != null) {
          return TeamNewsModel.fromJson(Map<String, dynamic>.from(row));
        }
      } catch (error) {
        AppLogger.d('Failed to load team news detail: $error');
      }
    }

    for (final item in [
      ..._seedNews('liverpool'),
      ..._seedNews('arsenal'),
      ..._seedNews('barcelona'),
    ]) {
      if (item.id == newsId) return item;
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> getFeaturedTeamsRaw() async {
    final client = _connection.client;
    if (client != null) {
      try {
        final rows = await client
            .from('teams')
            .select('id, name, fan_count, country, league_name, crest_url')
            .eq('is_featured', true)
            .order('fan_count', ascending: false)
            .limit(6);
        final teams = (rows as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false);
        if (teams.isNotEmpty) return teams;
      } catch (error) {
        AppLogger.d('Failed to load featured teams: $error');
      }
    }

    return const [
      {'id': 'liverpool', 'name': 'Liverpool', 'fan_count': 24000},
      {'id': 'arsenal', 'name': 'Arsenal', 'fan_count': 22000},
      {'id': 'barcelona', 'name': 'Barcelona', 'fan_count': 26000},
    ];
  }

  @override
  Stream<List<FeedMessage>> watchFeedMessages(
    String channelType,
    String channelId,
  ) {
    final feedKey = '$channelType:$channelId';
    final controller = _feedControllers.putIfAbsent(
      feedKey,
      () => StreamController<List<FeedMessage>>.broadcast(),
    );
    unawaited(_emitFeed(channelType, channelId));
    return controller.stream;
  }

  @override
  Future<void> sendFeedMessage({
    required String channelType,
    required String channelId,
    required String content,
    String? replyTo,
  }) async {
    final userId = _requireUserId();
    final client = _connection.client;

    if (client != null) {
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
        await _emitFeed(channelType, channelId);
        return;
      } catch (error) {
        AppLogger.d('Failed to send feed message remotely: $error');
      }
    }

    final existing = await _loadFeedMessages(channelType, channelId);
    final next = [
      ...existing,
      FeedMessage(
        id: 'message_${DateTime.now().millisecondsSinceEpoch}',
        channelType: channelType,
        channelId: channelId,
        userId: userId,
        content: content,
        replyTo: replyTo,
        createdAt: DateTime.now(),
      ),
    ];
    await _cache.setJson(
      _feedKey(channelType, channelId),
      next.map(_messageToJson).toList(growable: false),
    );
    await _emitFeed(channelType, channelId, override: next);
  }

  @override
  Future<void> reactToMessage({
    required String messageId,
    required String emoji,
  }) async {
    final userId = _connection.currentUser?.id;
    final client = _connection.client;
    if (client == null || userId == null) return;

    try {
      final channelRow = await client
          .from('feed_messages')
          .select('channel_type, channel_id')
          .eq('id', messageId)
          .maybeSingle();
      await client.rpc(
        'react_to_message',
        params: {'p_message_id': messageId, 'p_emoji': emoji},
      );
      if (channelRow != null) {
        await _emitFeed(
          channelRow['channel_type'].toString(),
          channelRow['channel_id'].toString(),
        );
      }
    } catch (error) {
      AppLogger.d('Failed to react to message: $error');
    }
  }

  Future<void> _emitFeed(
    String channelType,
    String channelId, {
    List<FeedMessage>? override,
  }) async {
    final controller = _feedControllers['$channelType:$channelId'];
    if (controller == null || controller.isClosed) return;
    controller.add(override ?? await _loadFeedMessages(channelType, channelId));
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
          messages.map(_messageToJson).toList(growable: false),
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

  String _contributionKey(String userId, String teamId) =>
      '$_contributionPrefix$userId.$teamId';

  String _feedKey(String channelType, String channelId) =>
      '$_feedPrefix$channelType.$channelId';

  Future<int> _cachedContributionTotal(String teamId) async {
    final userId = _connection.currentUser?.id;
    if (userId == null) return 0;
    final history = await getTeamContributionHistory(userId, teamId);
    return history.fold<int>(0, (sum, item) => sum + (item.amountFet ?? 0));
  }

  String _requireUserId() {
    final userId = _connection.currentUser?.id;
    if (userId == null) {
      throw StateError('Not authenticated');
    }
    return userId;
  }

  String _fallbackAnonymousFanId(String userId) {
    final digits = userId.replaceAll(RegExp(r'[^0-9]'), '');
    final suffix = digits.isEmpty ? '0000' : digits.padLeft(4, '0').substring(0, 4);
    return 'FAN$suffix';
  }
}

Map<String, dynamic> _contributionToJson(TeamContributionModel contribution) {
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

Map<String, dynamic> _messageToJson(FeedMessage message) {
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

List<TeamNewsModel> _seedNews(String teamId) {
  return [
    TeamNewsModel(
      id: 'news_${teamId}_1',
      teamId: teamId,
      title: '${_teamName(teamId)} build momentum for the run-in',
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

String _teamName(String teamId) {
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

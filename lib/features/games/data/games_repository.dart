import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/gateway_providers.dart';
import '../../../providers/profile_country_provider.dart';

class GameSessionSummary {
  const GameSessionSummary({
    required this.id,
    required this.venueId,
    required this.templateId,
    required this.templateName,
    required this.templateCategory,
    required this.status,
    required this.scheduledStartAt,
    required this.rewardFet,
    required this.selectedQuestionCount,
    required this.venueName,
    this.countryCode,
    this.currentQuestionOrdinal,
    this.metadata = const {},
  });

  factory GameSessionSummary.fromJson(Map<String, dynamic> json) {
    final template = json['game_templates'] is Map
        ? Map<String, dynamic>.from(json['game_templates'] as Map)
        : const <String, dynamic>{};
    final venue = json['venues'] is Map
        ? Map<String, dynamic>.from(json['venues'] as Map)
        : const <String, dynamic>{};

    return GameSessionSummary(
      id: json['id']?.toString() ?? '',
      venueId: json['venue_id']?.toString() ?? '',
      templateId: json['template_id']?.toString() ?? '',
      templateName:
          template['name']?.toString() ??
          _templateLabel(json['template_id']?.toString()),
      templateCategory: template['category']?.toString() ?? 'trivia',
      status: json['status']?.toString() ?? 'scheduled',
      scheduledStartAt:
          DateTime.tryParse(json['scheduled_start_at']?.toString() ?? '') ??
          DateTime.now(),
      rewardFet: (json['reward_fet'] as num?)?.toInt() ?? 0,
      selectedQuestionCount:
          (json['selected_question_count'] as num?)?.toInt() ?? 0,
      currentQuestionOrdinal: (json['current_question_ordinal'] as num?)
          ?.toInt(),
      venueName: venue['name']?.toString() ?? 'Linked bar',
      countryCode: venue['country_code']?.toString(),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
    );
  }

  final String id;
  final String venueId;
  final String templateId;
  final String templateName;
  final String templateCategory;
  final String status;
  final DateTime scheduledStartAt;
  final int rewardFet;
  final int selectedQuestionCount;
  final int? currentQuestionOrdinal;
  final String venueName;
  final String? countryCode;
  final Map<String, dynamic> metadata;

  bool get isJoinable => status == 'scheduled' || status == 'lobby';
  bool get isLive => status == 'live';
  bool get isMusicBingo => templateId == 'music_bingo';
  bool get usesQuestions =>
      templateCategory == 'trivia' || templateCategory == 'song_guess';
}

class GameTeam {
  const GameTeam({
    required this.id,
    required this.sessionId,
    required this.name,
    required this.scoreFet,
    required this.inviteCode,
  });

  factory GameTeam.fromJson(Map<String, dynamic> json) {
    return GameTeam(
      id: json['id']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Team',
      scoreFet: (json['score_fet'] as num?)?.toInt() ?? 0,
      inviteCode: json['invite_code']?.toString() ?? '',
    );
  }

  final String id;
  final String sessionId;
  final String name;
  final int scoreFet;
  final String inviteCode;
}

class GameQuestion {
  const GameQuestion({
    required this.questionId,
    required this.ordinal,
    required this.prompt,
    required this.options,
  });

  factory GameQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    final options = rawOptions is List
        ? rawOptions
              .map((item) {
                if (item is Map && item['label'] != null) {
                  return item['label'].toString();
                }
                return item.toString();
              })
              .where((item) => item.trim().isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    return GameQuestion(
      questionId: json['question_id']?.toString() ?? '',
      ordinal: (json['ordinal'] as num?)?.toInt() ?? 1,
      prompt: json['prompt']?.toString() ?? '',
      options: options,
    );
  }

  final String questionId;
  final int ordinal;
  final String prompt;
  final List<String> options;
}

class MusicBingoCard {
  const MusicBingoCard({
    required this.id,
    required this.tiles,
    required this.marks,
  });

  factory MusicBingoCard.fromRpc(Map<String, dynamic> json) {
    final card = json['card'] is Map
        ? Map<String, dynamic>.from(json['card'] as Map)
        : const <String, dynamic>{};
    final rawTiles = card['tiles'];
    final rawMarks = json['marks'];
    return MusicBingoCard(
      id: json['card_id']?.toString() ?? '',
      tiles: rawTiles is List
          ? rawTiles
                .whereType<Map>()
                .map(
                  (tile) => BingoTile.fromJson(Map<String, dynamic>.from(tile)),
                )
                .toList(growable: false)
          : const <BingoTile>[],
      marks: rawMarks is List
          ? rawMarks.map((mark) => mark.toString()).toSet()
          : const <String>{},
    );
  }

  final String id;
  final List<BingoTile> tiles;
  final Set<String> marks;
}

class BingoTile {
  const BingoTile({required this.key, required this.label});

  factory BingoTile.fromJson(Map<String, dynamic> json) {
    return BingoTile(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Track',
    );
  }

  final String key;
  final String label;
}

class GameDetail {
  const GameDetail({
    required this.session,
    required this.teams,
    this.myTeam,
    this.currentQuestion,
    this.bingoCard,
    this.isEligible = false,
  });

  final GameSessionSummary session;
  final List<GameTeam> teams;
  final GameTeam? myTeam;
  final GameQuestion? currentQuestion;
  final MusicBingoCard? bingoCard;
  final bool isEligible;
}

abstract interface class GamesRepository {
  Future<List<GameSessionSummary>> listGames({String? countryCode});

  Future<Set<String>> myJoinedSessionIds();

  Future<GameDetail?> getGameDetail(String sessionId);

  Future<Map<String, dynamic>> createTeam({
    required String sessionId,
    required String name,
  });

  Future<Map<String, dynamic>> joinTeam(String teamId);

  Future<Map<String, dynamic>> submitAnswer({
    required String sessionId,
    required String questionId,
    required String teamId,
    required String answer,
  });

  Future<MusicBingoCard> markBingoTile({
    required String cardId,
    required String tileKey,
    required bool marked,
  });

  Future<Map<String, dynamic>> submitBingoClaim(String cardId);
}

class SupabaseGamesRepository implements GamesRepository {
  SupabaseGamesRepository(this.ref);

  final Ref ref;

  static const _sessionColumns =
      'id,venue_id,template_id,status,scheduled_start_at,started_at,ended_at,'
      'reward_fet,selected_question_count,current_question_ordinal,metadata,'
      'created_at,game_templates(id,name,category),'
      'venues!inner(id,name,country_code)';

  SupabaseClient get _client {
    final client = ref.watch(supabaseConnectionProvider).client;
    if (client == null) {
      throw StateError(
        'Games are unavailable until the backend is configured.',
      );
    }
    return client;
  }

  @override
  Future<List<GameSessionSummary>> listGames({String? countryCode}) async {
    var request = _client
        .from('game_sessions')
        .select(_sessionColumns)
        .inFilter('status', ['scheduled', 'lobby', 'live', 'ended', 'settled']);

    if (countryCode != null && countryCode.trim().isNotEmpty) {
      request = request.eq(
        'venues.country_code',
        countryCode.trim().toUpperCase(),
      );
    }

    final rows = await request
        .order('scheduled_start_at', ascending: true)
        .limit(60);

    return (rows as List)
        .whereType<Map>()
        .map(
          (row) => GameSessionSummary.fromJson(Map<String, dynamic>.from(row)),
        )
        .where((session) => session.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<Set<String>> myJoinedSessionIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const <String>{};

    final rows = await _client
        .from('game_team_members')
        .select('session_id')
        .eq('user_id', userId);

    return (rows as List)
        .whereType<Map>()
        .map((row) => row['session_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  @override
  Future<GameDetail?> getGameDetail(String sessionId) async {
    final row = await _client
        .from('game_sessions')
        .select(_sessionColumns)
        .eq('id', sessionId)
        .maybeSingle();
    if (row == null) return null;

    final session = GameSessionSummary.fromJson(row);
    final teams = await _loadTeams(sessionId);
    final myTeam = await _loadMyTeam(sessionId);
    final question = session.isLive && session.usesQuestions
        ? await _loadCurrentQuestion(session)
        : null;
    final bingoCard = session.isMusicBingo && myTeam != null
        ? await _getOrCreateBingoCard(session.id, myTeam.id)
        : null;
    final isEligible = await _loadEligibility(session);

    return GameDetail(
      session: session,
      teams: teams,
      myTeam: myTeam,
      currentQuestion: question,
      bingoCard: bingoCard,
      isEligible: isEligible,
    );
  }

  @override
  Future<Map<String, dynamic>> createTeam({
    required String sessionId,
    required String name,
  }) async {
    final result = await _client.rpc(
      'create_game_team',
      params: {'p_session_id': sessionId, 'p_name': name},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  @override
  Future<Map<String, dynamic>> joinTeam(String teamId) async {
    final result = await _client.rpc(
      'join_game_team',
      params: {'p_team_id': teamId},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  @override
  Future<Map<String, dynamic>> submitAnswer({
    required String sessionId,
    required String questionId,
    required String teamId,
    required String answer,
  }) async {
    final result = await _client.rpc(
      'submit_game_answer',
      params: {
        'p_session_id': sessionId,
        'p_question_id': questionId,
        'p_team_id': teamId,
        'p_answer': answer,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  @override
  Future<MusicBingoCard> markBingoTile({
    required String cardId,
    required String tileKey,
    required bool marked,
  }) async {
    final result = await _client.rpc(
      'mark_music_bingo_tile',
      params: {'p_card_id': cardId, 'p_tile_key': tileKey, 'p_marked': marked},
    );
    final payload = Map<String, dynamic>.from(result as Map);
    final current = await _client
        .from('music_bingo_cards')
        .select('id,card,marks')
        .eq('id', payload['card_id'].toString())
        .single();
    return MusicBingoCard.fromRpc({
      'card_id': current['id'],
      'card': current['card'],
      'marks': current['marks'],
    });
  }

  @override
  Future<Map<String, dynamic>> submitBingoClaim(String cardId) async {
    final result = await _client.rpc(
      'submit_music_bingo_claim',
      params: {
        'p_card_id': cardId,
        'p_metadata': {'source': 'flutter_app'},
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<GameTeam>> _loadTeams(String sessionId) async {
    final rows = await _client
        .from('game_teams')
        .select('id,session_id,name,score_fet,invite_code,created_at')
        .eq('session_id', sessionId)
        .order('score_fet', ascending: false)
        .order('created_at', ascending: true);

    return (rows as List)
        .whereType<Map>()
        .map((row) => GameTeam.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<GameTeam?> _loadMyTeam(String sessionId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final rows = await _client
        .from('game_team_members')
        .select('game_teams(id,session_id,name,score_fet,invite_code)')
        .eq('session_id', sessionId)
        .eq('user_id', userId)
        .limit(1);

    if ((rows as List).isEmpty) return null;
    final team = (rows.first as Map)['game_teams'];
    if (team is! Map) return null;
    return GameTeam.fromJson(Map<String, dynamic>.from(team));
  }

  Future<GameQuestion?> _loadCurrentQuestion(GameSessionSummary session) async {
    final ordinal = session.currentQuestionOrdinal;
    if (ordinal == null) return null;

    final result = await _client.rpc(
      'get_game_session_question',
      params: {'p_session_id': session.id, 'p_ordinal': ordinal},
    );
    final rows = result is List ? result : const [];
    if (rows.isEmpty || rows.first is! Map) return null;
    return GameQuestion.fromJson(Map<String, dynamic>.from(rows.first as Map));
  }

  Future<MusicBingoCard> _getOrCreateBingoCard(
    String sessionId,
    String teamId,
  ) async {
    final result = await _client.rpc(
      'get_or_create_music_bingo_card',
      params: {'p_session_id': sessionId, 'p_team_id': teamId},
    );
    return MusicBingoCard.fromRpc(Map<String, dynamic>.from(result as Map));
  }

  Future<bool> _loadEligibility(GameSessionSummary session) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final result = await _client.rpc(
      'user_has_qualifying_order',
      params: {
        'p_user_id': userId,
        'p_venue_id': session.venueId,
        'p_scheduled_start_at': session.scheduledStartAt.toIso8601String(),
      },
    );
    return result == true;
  }
}

final gamesRepositoryProvider = Provider<GamesRepository>((ref) {
  return SupabaseGamesRepository(ref);
});

final gamesProvider = FutureProvider.autoDispose<List<GameSessionSummary>>((
  ref,
) {
  final countryCode = ref.watch(profileCountryProvider);
  return ref.watch(gamesRepositoryProvider).listGames(countryCode: countryCode);
});

final myJoinedGameIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) {
  return ref.watch(gamesRepositoryProvider).myJoinedSessionIds();
});

final gameDetailProvider = FutureProvider.autoDispose
    .family<GameDetail?, String>((ref, sessionId) {
      return ref.watch(gamesRepositoryProvider).getGameDetail(sessionId);
    });

final gameDetailRealtimeProvider = StreamProvider.autoDispose
    .family<GameDetail?, String>((ref, sessionId) {
      final repository = ref.watch(gamesRepositoryProvider);
      final connection = ref.watch(supabaseConnectionProvider);
      final controller = StreamController<GameDetail?>();

      Future<void> emitLatest() async {
        if (controller.isClosed) return;
        controller.add(await repository.getGameDetail(sessionId));
      }

      unawaited(emitLatest());

      final client = connection.client;
      final channel = client
          ?.channel('game_detail_$sessionId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'game_sessions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: sessionId,
            ),
            callback: (_) => unawaited(emitLatest()),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'game_teams',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'session_id',
              value: sessionId,
            ),
            callback: (_) => unawaited(emitLatest()),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'music_bingo_cards',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'session_id',
              value: sessionId,
            ),
            callback: (_) => unawaited(emitLatest()),
          )
          .subscribe();

      ref.onDispose(() {
        if (channel != null && client != null) {
          unawaited(client.removeChannel(channel));
        }
        unawaited(controller.close());
      });

      return controller.stream;
    });

String _templateLabel(String? templateId) {
  switch (templateId) {
    case 'bar_trivia':
      return 'Bar Trivia';
    case 'fan_trivia':
      return 'Fan Trivia';
    case 'music_bingo':
      return 'Music Bingo';
    case 'song_guess':
      return 'Song Guess';
    default:
      return 'Game';
  }
}

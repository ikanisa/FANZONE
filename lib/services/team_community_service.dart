import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/logging/app_logger.dart';
import '../main.dart' show supabaseInitialized;
import '../providers/auth_provider.dart';
import '../models/team_supporter_model.dart';
import '../models/team_contribution_model.dart';
import '../models/team_news_model.dart';

part 'team_community_service.g.dart';

// ─────────────────────────────────────────────────────────────
// Supported Teams —  tracks which teams the current user supports
// ─────────────────────────────────────────────────────────────

@riverpod
class SupportedTeamsService extends _$SupportedTeamsService {
  @override
  FutureOr<Set<String>> build() async {
    ref.watch(authStateProvider);

    if (!supabaseInitialized) return const {};

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return const {};

    final data = await client
        .from('team_supporters')
        .select('team_id')
        .eq('user_id', userId)
        .eq('is_active', true);

    return (data as List).map((row) => row['team_id'] as String).toSet();
  }

  /// Join a team's fan community.
  Future<String?> supportTeam(String teamId) async {
    if (!supabaseInitialized) return null;

    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      throw StateError('Not authenticated');
    }

    try {
      final result = await client.rpc(
        'support_team',
        params: {'p_team_id': teamId},
      );

      final response = result as Map<String, dynamic>?;
      final fanId = response?['anonymous_fan_id'] as String?;

      // Optimistic update
      final current = state.valueOrNull ?? {};
      state = AsyncValue.data({...current, teamId});

      return fanId;
    } on PostgrestException catch (e) {
      AppLogger.d('Support team failed: ${e.message}');
      rethrow;
    }
  }

  /// Leave a team's fan community (deactivate, not delete).
  Future<void> unsupportTeam(String teamId) async {
    if (!supabaseInitialized) return;

    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      throw StateError('Not authenticated');
    }

    try {
      await client.rpc('unsupport_team', params: {'p_team_id': teamId});

      // Optimistic update
      final current = state.valueOrNull ?? {};
      state = AsyncValue.data({...current}..remove(teamId));
    } on PostgrestException catch (e) {
      AppLogger.d('Unsupport team failed: ${e.message}');
      rethrow;
    }
  }

  /// Toggle support for a team.
  Future<void> toggleSupport(String teamId) async {
    final supported = state.valueOrNull ?? {};
    if (supported.contains(teamId)) {
      await unsupportTeam(teamId);
    } else {
      await supportTeam(teamId);
    }
  }

  bool isSupporting(String teamId) {
    return state.valueOrNull?.contains(teamId) ?? false;
  }
}

// ─────────────────────────────────────────────────────────────
// Team Community Stats
// ─────────────────────────────────────────────────────────────

@riverpod
FutureOr<TeamCommunityStats?> teamCommunityStats(
  TeamCommunityStatsRef ref,
  String teamId,
) async {
  if (!supabaseInitialized) return null;

  final data = await Supabase.instance.client
      .from('team_community_stats')
      .select()
      .eq('team_id', teamId)
      .maybeSingle();

  if (data == null) return null;
  return TeamCommunityStats.fromJson(data);
}

// ─────────────────────────────────────────────────────────────
// Anonymous Fan Registry
// ─────────────────────────────────────────────────────────────

@riverpod
FutureOr<List<AnonymousFanRecord>> teamAnonymousFans(
  TeamAnonymousFansRef ref,
  String teamId, {
  int limit = 50,
}) async {
  if (!supabaseInitialized) return const [];

  final data = await Supabase.instance.client.rpc(
    'get_team_anonymous_fans',
    params: {'p_team_id': teamId, 'p_limit': limit, 'p_offset': 0},
  );

  return (data as List)
      .map(
        (row) =>
            AnonymousFanRecord.fromJson(Map<String, dynamic>.from(row as Map)),
      )
      .toList();
}

// ─────────────────────────────────────────────────────────────
// FET Contribution
// ─────────────────────────────────────────────────────────────

@riverpod
class TeamContributionService extends _$TeamContributionService {
  @override
  FutureOr<void> build() {}

  /// Contribute FET to a team. Returns the new balance.
  Future<int> contributeFet(String teamId, int amount) async {
    if (!supabaseInitialized) {
      throw StateError('Supabase not initialized');
    }

    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      throw StateError('Not authenticated');
    }

    if (amount <= 0) {
      throw ArgumentError('Amount must be greater than zero');
    }

    state = const AsyncValue.loading();

    try {
      final result = await client.rpc(
        'contribute_fet_to_team',
        params: {'p_team_id': teamId, 'p_amount_fet': amount},
      );

      final response = result as Map<String, dynamic>?;
      final balanceAfter = (response?['balance_after'] as num?)?.toInt() ?? 0;

      state = const AsyncValue.data(null);
      return balanceAfter;
    } on PostgrestException catch (e) {
      AppLogger.d('FET contribution failed: ${e.message}');
      state = AsyncValue.error(e.message, StackTrace.current);
      rethrow;
    } catch (e) {
      AppLogger.d('FET contribution failed: $e');
      state = AsyncValue.error('Contribution failed', StackTrace.current);
      rethrow;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Contribution History
// ─────────────────────────────────────────────────────────────

@riverpod
FutureOr<List<TeamContributionModel>> teamContributionHistory(
  TeamContributionHistoryRef ref,
  String teamId,
) async {
  ref.watch(authStateProvider);

  if (!supabaseInitialized) return const [];

  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return const [];

  final data = await client
      .from('team_contributions')
      .select()
      .eq('user_id', userId)
      .eq('team_id', teamId)
      .order('created_at', ascending: false)
      .limit(50);

  return (data as List)
      .map((row) => TeamContributionModel.fromJson(row))
      .toList();
}

// ─────────────────────────────────────────────────────────────
// Team News
// ─────────────────────────────────────────────────────────────

@riverpod
FutureOr<List<TeamNewsModel>> teamNews(
  TeamNewsRef ref,
  String teamId, {
  String? category,
  int limit = 20,
}) async {
  if (!supabaseInitialized) return const [];

  var query = Supabase.instance.client
      .from('team_news')
      .select()
      .eq('team_id', teamId)
      .eq('status', 'published');

  if (category != null) {
    query = query.eq('category', category);
  }

  final data = await query.order('published_at', ascending: false).limit(limit);

  return (data as List).map((row) => TeamNewsModel.fromJson(row)).toList();
}

@riverpod
FutureOr<TeamNewsModel?> teamNewsDetail(
  TeamNewsDetailRef ref,
  String newsId,
) async {
  if (!supabaseInitialized) return null;

  final data = await Supabase.instance.client
      .from('team_news')
      .select()
      .eq('id', newsId)
      .eq('status', 'published')
      .maybeSingle();

  if (data == null) return null;
  return TeamNewsModel.fromJson(data);
}

// ─────────────────────────────────────────────────────────────
// Featured Teams
// ─────────────────────────────────────────────────────────────

@riverpod
FutureOr<List<Map<String, dynamic>>> featuredTeamsRaw(
  FeaturedTeamsRawRef ref,
) async {
  if (!supabaseInitialized) return const [];

  final data = await Supabase.instance.client
      .from('teams')
      .select()
      .eq('is_active', true)
      .eq('is_featured', true)
      .order('name');

  return (data as List).cast<Map<String, dynamic>>();
}

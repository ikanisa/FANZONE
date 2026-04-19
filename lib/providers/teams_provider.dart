import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/supabase_provider.dart';
import '../models/team_model.dart';

/// Provider for all teams — returns TeamModel DTOs for backward compatibility.
final teamsProvider = FutureProvider.autoDispose<List<TeamModel>>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const [];

  final data = await client
      .from('teams')
      .select()
      .order('name')
      .timeout(supabaseTimeout);

  return (data as List).map((row) => TeamModel.fromJson(row)).toList();
});

/// Provider for teams filtered by competition.
final teamsByCompetitionProvider = FutureProvider.family
    .autoDispose<List<TeamModel>, String>((ref, competitionId) async {
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return const [];

      final data = await client
          .from('teams')
          .select()
          .contains('competition_ids', [competitionId])
          .order('name')
          .timeout(supabaseTimeout);

      return (data as List).map((row) => TeamModel.fromJson(row)).toList();
    });

/// Provider for a single team by ID.
final teamProvider = FutureProvider.family.autoDispose<TeamModel?, String>((
  ref,
  teamId,
) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;

  final data = await client
      .from('teams')
      .select()
      .eq('id', teamId)
      .maybeSingle()
      .timeout(supabaseTimeout);

  if (data == null) return null;
  return TeamModel.fromJson(data);
});

/// Provider for featured teams.
final featuredTeamsProvider = FutureProvider.autoDispose<List<TeamModel>>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const [];

  final data = await client
      .from('teams')
      .select()
      .eq('is_active', true)
      .eq('is_featured', true)
      .order('name')
      .timeout(supabaseTimeout);

  return (data as List).map((row) => TeamModel.fromJson(row)).toList();
});

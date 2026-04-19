import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/supabase_provider.dart';
import '../models/competition_model.dart';

/// Provider for all competitions.
/// Returns CompetitionModel DTOs for backward compatibility.
final competitionsProvider = FutureProvider.autoDispose<List<CompetitionModel>>(
  (ref) async {
    ref.keepAlive();
    final client = ref.watch(supabaseClientProvider);
    if (client == null) return const [];

    final data = await client
        .from('competitions')
        .select()
        .order('name')
        .timeout(supabaseTimeout);

    return (data as List).map((row) => CompetitionModel.fromJson(row)).toList();
  },
);

/// Provider for tier-1 competitions only.
final topCompetitionsProvider =
    FutureProvider.autoDispose<List<CompetitionModel>>((ref) async {
      ref.keepAlive();
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return const [];

      final data = await client
          .from('competitions')
          .select()
          .eq('tier', 1)
          .order('name')
          .timeout(supabaseTimeout);

      return (data as List).map((row) => CompetitionModel.fromJson(row)).toList();
    });

/// Provider for a single competition by ID.
final competitionProvider = FutureProvider.family
    .autoDispose<CompetitionModel?, String>((ref, competitionId) async {
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return null;

      final data = await client
          .from('competitions')
          .select()
          .eq('id', competitionId)
          .maybeSingle()
          .timeout(supabaseTimeout);

      if (data == null) return null;
      return CompetitionModel.fromJson(data);
    });

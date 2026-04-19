import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/supabase_provider.dart';
import '../models/standing_row_model.dart';

/// Filter for competition standings lookup.
class CompetitionStandingsFilter {
  const CompetitionStandingsFilter({required this.competitionId, this.season});

  final String competitionId;
  final String? season;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CompetitionStandingsFilter &&
            other.competitionId == competitionId &&
            other.season == season;
  }

  @override
  int get hashCode => Object.hash(competitionId, season);
}

/// Provider for competition standings — returns StandingRowModel DTOs.
final competitionStandingsProvider = FutureProvider.family
    .autoDispose<List<StandingRowModel>, CompetitionStandingsFilter>((
      ref,
      filter,
    ) async {
      final client = ref.watch(supabaseClientProvider);
      if (client == null) return const [];

      var query = client
          .from('competition_standings')
          .select()
          .eq('competition_id', filter.competitionId);

      if (filter.season != null && filter.season!.isNotEmpty) {
        query = query.eq('season', filter.season!);
      }

      final data = await query.order('position').timeout(supabaseTimeout);
      return (data as List).map((row) => StandingRowModel.fromJson(row)).toList();
    });

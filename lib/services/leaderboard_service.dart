import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart' show supabaseInitialized;
import '../providers/auth_provider.dart';

part 'leaderboard_service.g.dart';

@riverpod
class GlobalLeaderboard extends _$GlobalLeaderboard {
  @override
  FutureOr<List<Map<String, dynamic>>> build() async {
    if (!supabaseInitialized) return const [];

    final client = Supabase.instance.client;
    // Let errors propagate — don't mask as empty
    final data = await client
        .from('public_leaderboard')
        .select('user_id, display_name, total_fet')
        .order('total_fet', ascending: false)
        .limit(50);

    return (data as List).asMap().entries.map((entry) {
      final row = entry.value;
      return <String, dynamic>{
        'rank': entry.key + 1,
        'name': row['display_name']?.toString() ?? 'Fan',
        'fet': _formatFet((row['total_fet'] as num?)?.toInt() ?? 0),
        'user_id': row['user_id']?.toString() ?? '',
      };
    }).toList();
  }

  String _formatFet(int fet) {
    if (fet >= 1000) {
      final k = fet / 1000;
      return '${k.toStringAsFixed(k == k.roundToDouble() ? 0 : 1)}k';
    }
    return '$fet';
  }
}

/// Provider for the current user's rank.
/// Uses a server-side approach to avoid O(n) client-side scanning.
@riverpod
FutureOr<int?> userRank(Ref ref) async {
  ref.watch(authStateProvider);

  if (!supabaseInitialized) return null;

  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;

  // Query only the current user's row — O(1) instead of O(n)
  final data = await client
      .from('public_leaderboard')
      .select('total_fet')
      .eq('user_id', userId)
      .maybeSingle();

  if (data == null) return null;

  final userFet = (data['total_fet'] as num?)?.toInt() ?? 0;

  // Count how many users have more FET = rank
  final countResult = await client
      .from('public_leaderboard')
      .select('user_id')
      .gt('total_fet', userFet);

  return (countResult as List).length + 1;
}

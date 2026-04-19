import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/supabase_provider.dart';
import '../models/fan_identity_model.dart';
import 'auth_provider.dart';

// ─── Level Definitions (public, cacheable) ─────────────────────────

/// All fan levels from the database.
final fanLevelsProvider = FutureProvider<List<FanLevel>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const [];

  final data = await client
      .from('fan_levels')
      .select()
      .order('level')
      .timeout(supabaseTimeout);

  return (data as List)
      .map((row) => FanLevel.fromJson(Map<String, dynamic>.from(row)))
      .toList();
});

// ─── Badge Definitions (public) ────────────────────────────────────

/// All available badges.
final fanBadgesProvider = FutureProvider<List<FanBadge>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const [];

  final data = await client
      .from('fan_badges')
      .select()
      .eq('is_active', true)
      .order('category')
      .timeout(supabaseTimeout);

  return (data as List)
      .map((row) => FanBadge.fromJson(Map<String, dynamic>.from(row)))
      .toList();
});

// ─── Current User Fan Profile ──────────────────────────────────────

/// Current authenticated user's fan profile with resolved level.
final fanProfileProvider = FutureProvider.autoDispose<FanProfile?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(currentUserProvider);
  if (client == null || user == null) return null;

  final data = await client
      .from('fan_profiles')
      .select()
      .eq('user_id', user.id)
      .maybeSingle()
      .timeout(supabaseTimeout);

  if (data == null) return null;

  final profile = FanProfile.fromJson(data);

  // Resolve level name
  final levels = ref.read(fanLevelsProvider).valueOrNull ?? [];
  final level = levels.cast<FanLevel?>().firstWhere(
        (l) => l!.level == profile.currentLevel,
        orElse: () => null,
      );

  return level != null ? profile.withLevel(level) : profile;
});

// ─── User Earned Badges ────────────────────────────────────────────

/// Badges earned by the current user (with badge definitions joined).
final earnedBadgesProvider =
    FutureProvider.autoDispose<List<EarnedBadge>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(currentUserProvider);
  if (client == null || user == null) return const [];

  final data = await client
      .from('fan_earned_badges')
      .select('*, fan_badges(*)')
      .eq('user_id', user.id)
      .order('earned_at', ascending: false)
      .timeout(supabaseTimeout);

  return (data as List)
      .map((row) => EarnedBadge.fromJson(Map<String, dynamic>.from(row)))
      .toList();
});

// ─── XP History ────────────────────────────────────────────────────

/// Recent XP transactions for the current user.
final xpHistoryProvider =
    FutureProvider.autoDispose<List<XpLogEntry>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final user = ref.watch(currentUserProvider);
  if (client == null || user == null) return const [];

  final data = await client
      .from('fan_xp_log')
      .select()
      .eq('user_id', user.id)
      .order('created_at', ascending: false)
      .limit(50)
      .timeout(supabaseTimeout);

  return (data as List)
      .map((row) => XpLogEntry.fromJson(Map<String, dynamic>.from(row)))
      .toList();
});

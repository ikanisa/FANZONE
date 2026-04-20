import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/fan_identity_model.dart';

abstract interface class FanProfileGateway {
  Future<List<FanLevel>> getFanLevels();

  Future<List<FanBadge>> getFanBadges();

  Future<FanProfile?> getFanProfile(String userId);

  Future<List<EarnedBadge>> getEarnedBadges(String userId);

  Future<List<XpLogEntry>> getXpHistory(String userId);
}

class SupabaseFanProfileGateway implements FanProfileGateway {
  SupabaseFanProfileGateway(this._connection);

  final SupabaseConnection _connection;

  @override
  Future<List<FanLevel>> getFanLevels() async {
    final client = _connection.client;
    if (client == null) return const <FanLevel>[];

    try {
      final rows = await client.from('fan_levels').select().order('level');
      return (rows as List)
          .whereType<Map>()
          .map((row) => FanLevel.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } catch (error) {
      AppLogger.d('Failed to load fan levels: $error');
      return const <FanLevel>[];
    }
  }

  @override
  Future<List<FanBadge>> getFanBadges() async {
    final client = _connection.client;
    if (client == null) return const <FanBadge>[];

    try {
      final rows = await client
          .from('fan_badges')
          .select()
          .eq('is_active', true);
      return (rows as List)
          .whereType<Map>()
          .map((row) => FanBadge.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } catch (error) {
      AppLogger.d('Failed to load fan badges: $error');
      return const <FanBadge>[];
    }
  }

  @override
  Future<FanProfile?> getFanProfile(String userId) async {
    final client = _connection.client;
    if (client == null) return null;

    try {
      final row = await client
          .from('fan_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return row == null
          ? null
          : FanProfile.fromJson(Map<String, dynamic>.from(row));
    } catch (error) {
      AppLogger.d('Failed to load fan profile: $error');
      return null;
    }
  }

  @override
  Future<List<EarnedBadge>> getEarnedBadges(String userId) async {
    final client = _connection.client;
    if (client == null) return const <EarnedBadge>[];

    try {
      final rows = await client
          .from('fan_earned_badges')
          .select('*, fan_badges(*)')
          .eq('user_id', userId)
          .order('earned_at', ascending: false);
      return (rows as List)
          .whereType<Map>()
          .map((row) => EarnedBadge.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } catch (error) {
      AppLogger.d('Failed to load earned badges: $error');
      return const <EarnedBadge>[];
    }
  }

  @override
  Future<List<XpLogEntry>> getXpHistory(String userId) async {
    final client = _connection.client;
    if (client == null) return const <XpLogEntry>[];

    try {
      final rows = await client
          .from('fan_xp_log')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (rows as List)
          .whereType<Map>()
          .map((row) => XpLogEntry.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } catch (error) {
      AppLogger.d('Failed to load XP history: $error');
      return const <XpLogEntry>[];
    }
  }
}


import '../../../core/logging/app_logger.dart';
import '../../../core/supabase/supabase_connection.dart';
import '../../../models/fan_identity_model.dart';
import 'engagement_gateway_shared.dart';

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
    if (client == null) return _fallbackFanLevels();

    try {
      final rows = await client.from('fan_levels').select().order('level');
      final levels = (rows as List)
          .whereType<Map>()
          .map((row) => FanLevel.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      return levels;
    } catch (error) {
      AppLogger.d('Failed to load fan levels: $error');
      return _fallbackFanLevels();
    }
  }

  @override
  Future<List<FanBadge>> getFanBadges() async {
    final client = _connection.client;
    if (client == null) return _fallbackFanBadges();

    try {
      final rows = await client
          .from('fan_badges')
          .select()
          .eq('is_active', true);
      final badges = (rows as List)
          .whereType<Map>()
          .map((row) => FanBadge.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      return badges;
    } catch (error) {
      AppLogger.d('Failed to load fan badges: $error');
      return _fallbackFanBadges();
    }
  }

  @override
  Future<FanProfile?> getFanProfile(String userId) async {
    final client = _connection.client;
    if (client == null) return _fallbackFanProfile(userId);

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
      return _fallbackFanProfile(userId);
    }
  }

  @override
  Future<List<EarnedBadge>> getEarnedBadges(String userId) async {
    final client = _connection.client;
    if (client == null) return _fallbackEarnedBadges(userId);

    try {
      final rows = await client
          .from('fan_earned_badges')
          .select('*, fan_badges(*)')
          .eq('user_id', userId)
          .order('earned_at', ascending: false);
      final badges = (rows as List)
          .whereType<Map>()
          .map((row) => EarnedBadge.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      return badges;
    } catch (error) {
      AppLogger.d('Failed to load earned badges: $error');
      return _fallbackEarnedBadges(userId);
    }
  }

  @override
  Future<List<XpLogEntry>> getXpHistory(String userId) async {
    final client = _connection.client;
    if (client == null) return _fallbackXpHistory(userId);

    try {
      final rows = await client
          .from('fan_xp_log')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      final history = (rows as List)
          .whereType<Map>()
          .map((row) => XpLogEntry.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      return history;
    } catch (error) {
      AppLogger.d('Failed to load XP history: $error');
      return _fallbackXpHistory(userId);
    }
  }

  List<FanLevel> _fallbackFanLevels() {
    return allowEngagementSeedFallback ? fallbackFanLevels() : const <FanLevel>[];
  }

  List<FanBadge> _fallbackFanBadges() {
    return allowEngagementSeedFallback ? fallbackFanBadges() : const <FanBadge>[];
  }

  FanProfile? _fallbackFanProfile(String userId) {
    return allowEngagementSeedFallback ? fallbackFanProfileOrNull(userId) : null;
  }

  List<EarnedBadge> _fallbackEarnedBadges(String userId) {
    return allowEngagementSeedFallback
        ? fallbackEarnedBadges(userId)
        : const <EarnedBadge>[];
  }

  List<XpLogEntry> _fallbackXpHistory(String userId) {
    return allowEngagementSeedFallback
        ? fallbackXpHistory(userId)
        : const <XpLogEntry>[];
  }
}

import 'package:injectable/injectable.dart';

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

@LazySingleton(as: FanProfileGateway)
class SupabaseFanProfileGateway implements FanProfileGateway {
  SupabaseFanProfileGateway(this._connection);

  final SupabaseConnection _connection;

  @override
  Future<List<FanLevel>> getFanLevels() async {
    final client = _connection.client;
    if (client == null) return fallbackFanLevels();

    try {
      final rows = await client.from('fan_levels').select().order('level');
      final levels = (rows as List)
          .whereType<Map>()
          .map((row) => FanLevel.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      return levels.isEmpty ? fallbackFanLevels() : levels;
    } catch (error) {
      AppLogger.d('Failed to load fan levels: $error');
      return fallbackFanLevels();
    }
  }

  @override
  Future<List<FanBadge>> getFanBadges() async {
    final client = _connection.client;
    if (client == null) return fallbackFanBadges();

    try {
      final rows = await client
          .from('fan_badges')
          .select()
          .eq('is_active', true);
      final badges = (rows as List)
          .whereType<Map>()
          .map((row) => FanBadge.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      return badges.isEmpty ? fallbackFanBadges() : badges;
    } catch (error) {
      AppLogger.d('Failed to load fan badges: $error');
      return fallbackFanBadges();
    }
  }

  @override
  Future<FanProfile?> getFanProfile(String userId) async {
    final client = _connection.client;
    if (client == null) return fallbackFanProfileOrNull(userId);

    try {
      final row = await client
          .from('fan_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return row == null
          ? fallbackFanProfileOrNull(userId)
          : FanProfile.fromJson(Map<String, dynamic>.from(row));
    } catch (error) {
      AppLogger.d('Failed to load fan profile: $error');
      return fallbackFanProfileOrNull(userId);
    }
  }

  @override
  Future<List<EarnedBadge>> getEarnedBadges(String userId) async {
    final client = _connection.client;
    if (client == null) return fallbackEarnedBadges(userId);

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
      return badges.isEmpty ? fallbackEarnedBadges(userId) : badges;
    } catch (error) {
      AppLogger.d('Failed to load earned badges: $error');
      return fallbackEarnedBadges(userId);
    }
  }

  @override
  Future<List<XpLogEntry>> getXpHistory(String userId) async {
    final client = _connection.client;
    if (client == null) return fallbackXpHistory(userId);

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
      return history.isEmpty ? fallbackXpHistory(userId) : history;
    } catch (error) {
      AppLogger.d('Failed to load XP history: $error');
      return fallbackXpHistory(userId);
    }
  }
}

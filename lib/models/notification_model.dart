import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_model.freezed.dart';
part 'notification_model.g.dart';

@freezed
class NotificationItem with _$NotificationItem {
  const factory NotificationItem({
    required String id,
    required String type,
    required String title,
    @Default('') String body,
    @Default({}) Map<String, dynamic> data,
    required DateTime sentAt,
    DateTime? readAt,
  }) = _NotificationItem;

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      _$NotificationItemFromJson(json);
}

@freezed
class NotificationPreferences with _$NotificationPreferences {
  const factory NotificationPreferences({
    @Default(true) bool goalAlerts,
    @Default(true) bool poolUpdates,
    @Default(true) bool dailyChallenge,
    @Default(true) bool walletActivity,
    @Default(true) bool communityNews,
    @Default(false) bool marketing,
  }) = _NotificationPreferences;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      _$NotificationPreferencesFromJson(json);
}

@freezed
class UserStats with _$UserStats {
  const factory UserStats({
    @Default(0) int predictionStreak,
    @Default(0) int longestStreak,
    @Default(0) int totalPredictions,
    @Default(0) int totalPoolsEntered,
    @Default(0) int totalPoolsWon,
    @Default(0) int totalFetEarned,
    @Default(0) int totalFetSpent,
  }) = _UserStats;

  factory UserStats.fromJson(Map<String, dynamic> json) =>
      _$UserStatsFromJson(json);
}

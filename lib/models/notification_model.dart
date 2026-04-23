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
    @JsonKey(name: 'sent_at') required DateTime sentAt,
    @JsonKey(name: 'read_at') DateTime? readAt,
  }) = _NotificationItem;

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      _$NotificationItemFromJson(json);
}

@freezed
class NotificationPreferences with _$NotificationPreferences {
  const factory NotificationPreferences({
    @JsonKey(name: 'goal_alerts') @Default(true) bool goalAlerts,
    @JsonKey(name: 'prediction_updates')
    @Default(true)
    bool predictionUpdates,
    @JsonKey(name: 'reward_updates') @Default(true) bool rewardUpdates,
    @JsonKey(name: 'marketing') @Default(false) bool marketing,
  }) = _NotificationPreferences;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      _$NotificationPreferencesFromJson(json);
}

@freezed
class UserStats with _$UserStats {
  const factory UserStats({
    @JsonKey(name: 'prediction_streak') @Default(0) int predictionStreak,
    @JsonKey(name: 'longest_streak') @Default(0) int longestStreak,
    @JsonKey(name: 'total_predictions') @Default(0) int totalPredictions,
    @JsonKey(name: 'correct_predictions') @Default(0) int correctPredictions,
    @JsonKey(name: 'total_fet_earned') @Default(0) int totalFetEarned,
    @JsonKey(name: 'total_fet_spent') @Default(0) int totalFetSpent,
  }) = _UserStats;

  factory UserStats.fromJson(Map<String, dynamic> json) =>
      _$UserStatsFromJson(json);
}

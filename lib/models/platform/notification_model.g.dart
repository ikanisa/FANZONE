// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NotificationItemImpl _$$NotificationItemImplFromJson(
  Map<String, dynamic> json,
) => _$NotificationItemImpl(
  id: json['id'] as String,
  type: json['type'] as String,
  title: json['title'] as String,
  body: json['body'] as String? ?? '',
  data: json['data'] as Map<String, dynamic>? ?? const {},
  sentAt: DateTime.parse(json['sent_at'] as String),
  readAt: json['read_at'] == null
      ? null
      : DateTime.parse(json['read_at'] as String),
);

Map<String, dynamic> _$$NotificationItemImplToJson(
  _$NotificationItemImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': instance.type,
  'title': instance.title,
  'body': instance.body,
  'data': instance.data,
  'sent_at': instance.sentAt.toIso8601String(),
  'read_at': instance.readAt?.toIso8601String(),
};

_$NotificationPreferencesImpl _$$NotificationPreferencesImplFromJson(
  Map<String, dynamic> json,
) => _$NotificationPreferencesImpl(
  goalAlerts: json['goal_alerts'] as bool? ?? true,
  poolUpdates: json['pool_updates'] as bool? ?? true,
  rewardUpdates: json['reward_updates'] as bool? ?? true,
  marketing: json['marketing'] as bool? ?? false,
);

Map<String, dynamic> _$$NotificationPreferencesImplToJson(
  _$NotificationPreferencesImpl instance,
) => <String, dynamic>{
  'goal_alerts': instance.goalAlerts,
  'pool_updates': instance.poolUpdates,
  'reward_updates': instance.rewardUpdates,
  'marketing': instance.marketing,
};

_$UserStatsImpl _$$UserStatsImplFromJson(Map<String, dynamic> json) =>
    _$UserStatsImpl(
      poolStreak: (json['pool_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      totalPools: (json['total_pools'] as num?)?.toInt() ?? 0,
      poolWins: (json['pool_wins'] as num?)?.toInt() ?? 0,
      totalFetEarned: (json['total_fet_earned'] as num?)?.toInt() ?? 0,
      totalFetSpent: (json['total_fet_spent'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$UserStatsImplToJson(_$UserStatsImpl instance) =>
    <String, dynamic>{
      'pool_streak': instance.poolStreak,
      'longest_streak': instance.longestStreak,
      'total_pools': instance.totalPools,
      'pool_wins': instance.poolWins,
      'total_fet_earned': instance.totalFetEarned,
      'total_fet_spent': instance.totalFetSpent,
    };

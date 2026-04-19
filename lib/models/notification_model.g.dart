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
  sentAt: DateTime.parse(json['sentAt'] as String),
  readAt: json['readAt'] == null
      ? null
      : DateTime.parse(json['readAt'] as String),
);

Map<String, dynamic> _$$NotificationItemImplToJson(
  _$NotificationItemImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': instance.type,
  'title': instance.title,
  'body': instance.body,
  'data': instance.data,
  'sentAt': instance.sentAt.toIso8601String(),
  'readAt': instance.readAt?.toIso8601String(),
};

_$NotificationPreferencesImpl _$$NotificationPreferencesImplFromJson(
  Map<String, dynamic> json,
) => _$NotificationPreferencesImpl(
  goalAlerts: json['goalAlerts'] as bool? ?? true,
  poolUpdates: json['poolUpdates'] as bool? ?? true,
  dailyChallenge: json['dailyChallenge'] as bool? ?? true,
  walletActivity: json['walletActivity'] as bool? ?? true,
  communityNews: json['communityNews'] as bool? ?? true,
  marketing: json['marketing'] as bool? ?? false,
);

Map<String, dynamic> _$$NotificationPreferencesImplToJson(
  _$NotificationPreferencesImpl instance,
) => <String, dynamic>{
  'goalAlerts': instance.goalAlerts,
  'poolUpdates': instance.poolUpdates,
  'dailyChallenge': instance.dailyChallenge,
  'walletActivity': instance.walletActivity,
  'communityNews': instance.communityNews,
  'marketing': instance.marketing,
};

_$UserStatsImpl _$$UserStatsImplFromJson(Map<String, dynamic> json) =>
    _$UserStatsImpl(
      predictionStreak: (json['predictionStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      totalPredictions: (json['totalPredictions'] as num?)?.toInt() ?? 0,
      totalPoolsEntered: (json['totalPoolsEntered'] as num?)?.toInt() ?? 0,
      totalPoolsWon: (json['totalPoolsWon'] as num?)?.toInt() ?? 0,
      totalFetEarned: (json['totalFetEarned'] as num?)?.toInt() ?? 0,
      totalFetSpent: (json['totalFetSpent'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$UserStatsImplToJson(_$UserStatsImpl instance) =>
    <String, dynamic>{
      'predictionStreak': instance.predictionStreak,
      'longestStreak': instance.longestStreak,
      'totalPredictions': instance.totalPredictions,
      'totalPoolsEntered': instance.totalPoolsEntered,
      'totalPoolsWon': instance.totalPoolsWon,
      'totalFetEarned': instance.totalFetEarned,
      'totalFetSpent': instance.totalFetSpent,
    };

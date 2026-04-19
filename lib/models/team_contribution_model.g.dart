// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_contribution_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TeamContributionModelImpl _$$TeamContributionModelImplFromJson(
  Map<String, dynamic> json,
) => _$TeamContributionModelImpl(
  id: json['id'] as String,
  teamId: json['team_id'] as String,
  contributionType: json['contribution_type'] as String,
  amountFet: (json['amount_fet'] as num?)?.toInt(),
  amountMoney: (json['amount_money'] as num?)?.toDouble(),
  currencyCode: json['currency_code'] as String?,
  status: json['status'] as String,
  provider: json['provider'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$$TeamContributionModelImplToJson(
  _$TeamContributionModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'team_id': instance.teamId,
  'contribution_type': instance.contributionType,
  'amount_fet': instance.amountFet,
  'amount_money': instance.amountMoney,
  'currency_code': instance.currencyCode,
  'status': instance.status,
  'provider': instance.provider,
  'created_at': instance.createdAt.toIso8601String(),
};

_$TeamCommunityStatsImpl _$$TeamCommunityStatsImplFromJson(
  Map<String, dynamic> json,
) => _$TeamCommunityStatsImpl(
  teamId: json['team_id'] as String,
  teamName: json['team_name'] as String,
  fanCount: (json['fan_count'] as num?)?.toInt() ?? 0,
  totalFetContributed: (json['total_fet_contributed'] as num?)?.toInt() ?? 0,
  contributionCount: (json['contribution_count'] as num?)?.toInt() ?? 0,
  supportersLast30d: (json['supporters_last_30d'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$$TeamCommunityStatsImplToJson(
  _$TeamCommunityStatsImpl instance,
) => <String, dynamic>{
  'team_id': instance.teamId,
  'team_name': instance.teamName,
  'fan_count': instance.fanCount,
  'total_fet_contributed': instance.totalFetContributed,
  'contribution_count': instance.contributionCount,
  'supporters_last_30d': instance.supportersLast30d,
};

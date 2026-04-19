// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_challenge_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DailyChallengeImpl _$$DailyChallengeImplFromJson(Map<String, dynamic> json) =>
    _$DailyChallengeImpl(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      matchId: json['matchId'] as String,
      matchName: json['matchName'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      rewardFet: (json['rewardFet'] as num).toInt(),
      bonusExactFet: (json['bonusExactFet'] as num).toInt(),
      status: json['status'] as String,
      officialHomeScore: (json['officialHomeScore'] as num?)?.toInt(),
      officialAwayScore: (json['officialAwayScore'] as num?)?.toInt(),
      totalEntries: (json['totalEntries'] as num?)?.toInt() ?? 0,
      totalWinners: (json['totalWinners'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$DailyChallengeImplToJson(
  _$DailyChallengeImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'date': instance.date.toIso8601String(),
  'matchId': instance.matchId,
  'matchName': instance.matchName,
  'title': instance.title,
  'description': instance.description,
  'rewardFet': instance.rewardFet,
  'bonusExactFet': instance.bonusExactFet,
  'status': instance.status,
  'officialHomeScore': instance.officialHomeScore,
  'officialAwayScore': instance.officialAwayScore,
  'totalEntries': instance.totalEntries,
  'totalWinners': instance.totalWinners,
};

_$DailyChallengeEntryImpl _$$DailyChallengeEntryImplFromJson(
  Map<String, dynamic> json,
) => _$DailyChallengeEntryImpl(
  id: json['id'] as String,
  challengeId: json['challengeId'] as String,
  userId: json['userId'] as String,
  predictedHomeScore: (json['predictedHomeScore'] as num).toInt(),
  predictedAwayScore: (json['predictedAwayScore'] as num).toInt(),
  result: json['result'] as String,
  payoutFet: (json['payoutFet'] as num?)?.toInt() ?? 0,
  submittedAt: json['submittedAt'] == null
      ? null
      : DateTime.parse(json['submittedAt'] as String),
);

Map<String, dynamic> _$$DailyChallengeEntryImplToJson(
  _$DailyChallengeEntryImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'challengeId': instance.challengeId,
  'userId': instance.userId,
  'predictedHomeScore': instance.predictedHomeScore,
  'predictedAwayScore': instance.predictedAwayScore,
  'result': instance.result,
  'payoutFet': instance.payoutFet,
  'submittedAt': instance.submittedAt?.toIso8601String(),
};

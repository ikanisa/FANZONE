class UserPredictionModel {
  const UserPredictionModel({
    required this.id,
    required this.userId,
    required this.matchId,
    required this.predictedResultCode,
    required this.predictedOver25,
    required this.predictedBtts,
    required this.predictedHomeGoals,
    required this.predictedAwayGoals,
    required this.pointsAwarded,
    required this.rewardStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String matchId;
  final String? predictedResultCode;
  final bool? predictedOver25;
  final bool? predictedBtts;
  final int? predictedHomeGoals;
  final int? predictedAwayGoals;
  final int pointsAwarded;
  final String rewardStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  String? get scorelineLabel {
    if (predictedHomeGoals == null || predictedAwayGoals == null) return null;
    return '$predictedHomeGoals - $predictedAwayGoals';
  }

  factory UserPredictionModel.fromJson(Map<String, dynamic> json) {
    int? parseOptionalInt(Object? value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    }

    return UserPredictionModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      matchId: json['match_id']?.toString() ?? '',
      predictedResultCode: json['predicted_result_code']?.toString(),
      predictedOver25: json['predicted_over25'] as bool?,
      predictedBtts: json['predicted_btts'] as bool?,
      predictedHomeGoals: parseOptionalInt(json['predicted_home_goals']),
      predictedAwayGoals: parseOptionalInt(json['predicted_away_goals']),
      pointsAwarded: parseOptionalInt(json['points_awarded']) ?? 0,
      rewardStatus: json['reward_status']?.toString() ?? 'pending',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

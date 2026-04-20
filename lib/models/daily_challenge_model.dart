import 'package:freezed_annotation/freezed_annotation.dart';

part 'daily_challenge_model.freezed.dart';
part 'daily_challenge_model.g.dart';

@freezed
class DailyChallenge with _$DailyChallenge {
  const factory DailyChallenge({
    required String id,
    required DateTime date,
    required String matchId,
    required String matchName,
    required String title,
    @Default('') String description,
    required int rewardFet,
    required int bonusExactFet,
    required String status, // 'active' | 'settled' | 'cancelled'
    int? officialHomeScore,
    int? officialAwayScore,
    @Default(0) int totalEntries,
    @Default(0) int totalWinners,
  }) = _DailyChallenge;

  factory DailyChallenge.fromJson(Map<String, dynamic> json) =>
      _$DailyChallengeFromJson(json);
}

@freezed
class DailyChallengeEntry with _$DailyChallengeEntry {
  const factory DailyChallengeEntry({
    required String id,
    required String challengeId,
    required String userId,
    required int predictedHomeScore,
    required int predictedAwayScore,
    required String
    result, // 'pending' | 'correct_result' | 'exact_score' | 'wrong'
    @Default(0) int payoutFet,
    DateTime? submittedAt,
  }) = _DailyChallengeEntry;

  factory DailyChallengeEntry.fromJson(Map<String, dynamic> json) =>
      _$DailyChallengeEntryFromJson(json);
}

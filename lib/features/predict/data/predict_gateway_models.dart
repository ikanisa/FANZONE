import '../../../models/prediction_slip_model.dart';
import '../../../providers/prediction_slip_provider.dart';

class PoolCreateRequestDto {
  const PoolCreateRequestDto({
    required this.matchId,
    required this.homeScore,
    required this.awayScore,
    required this.stake,
  });

  final String matchId;
  final int homeScore;
  final int awayScore;
  final int stake;
}

class PoolJoinRequestDto {
  const PoolJoinRequestDto({
    required this.poolId,
    required this.homeScore,
    required this.awayScore,
  });

  final String poolId;
  final int homeScore;
  final int awayScore;
}

class PredictionSlipSubmissionDto {
  const PredictionSlipSubmissionDto({
    required this.selections,
    required this.stake,
  });

  final List<PredictionSelection> selections;
  final int stake;
}

class GlobalLeaderboardEntryDto {
  const GlobalLeaderboardEntryDto({
    required this.rank,
    required this.name,
    required this.fet,
    this.level,
  });

  factory GlobalLeaderboardEntryDto.fromJson(Map<String, dynamic> json) {
    return GlobalLeaderboardEntryDto(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'Fan',
      fet: (json['fet'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt(),
    );
  }

  final int rank;
  final String name;
  final int fet;
  final int? level;

  Map<String, dynamic> toJson() {
    return {'rank': rank, 'name': name, 'fet': fet, 'level': level};
  }
}

typedef PredictionSlipRows = List<PredictionSlipModel>;

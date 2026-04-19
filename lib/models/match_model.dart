import 'package:freezed_annotation/freezed_annotation.dart';

part 'match_model.freezed.dart';
part 'match_model.g.dart';

/// Core match model — maps directly to Supabase `matches` table.
@freezed
class MatchModel with _$MatchModel {
  const factory MatchModel({
    required String id,
    @JsonKey(name: 'competition_id') required String competitionId,
    required String season,
    String? round,
    @JsonKey(name: 'match_group') String? matchGroup,
    required DateTime date,
    @JsonKey(name: 'kickoff_time') String? kickoffTime,
    @JsonKey(name: 'home_team_id') String? homeTeamId,
    @JsonKey(name: 'away_team_id') String? awayTeamId,
    @JsonKey(name: 'home_team') required String homeTeam,
    @JsonKey(name: 'away_team') required String awayTeam,
    @JsonKey(name: 'ft_home') int? ftHome,
    @JsonKey(name: 'ft_away') int? ftAway,
    @JsonKey(name: 'ht_home') int? htHome,
    @JsonKey(name: 'ht_away') int? htAway,
    @JsonKey(name: 'et_home') int? etHome,
    @JsonKey(name: 'et_away') int? etAway,
    @Default('upcoming') String status,
    String? venue,
    @JsonKey(name: 'data_source') required String dataSource,
    @JsonKey(name: 'source_url') String? sourceUrl,
    @JsonKey(name: 'home_logo_url') String? homeLogoUrl,
    @JsonKey(name: 'away_logo_url') String? awayLogoUrl,
  }) = _MatchModel;

  const MatchModel._();

  factory MatchModel.fromJson(Map<String, dynamic> json) =>
      _$MatchModelFromJson(json);

  /// Full-time score display string (e.g. "3 - 1").
  String? get scoreDisplay {
    if (ftHome == null || ftAway == null) return null;
    return '$ftHome - $ftAway';
  }

  String get normalizedStatus {
    final value = status.trim().toLowerCase().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );

    switch (value) {
      case 'live':
      case 'in_play':
      case 'inprogress':
      case 'in_progress':
      case 'playing':
        return 'live';
      case 'finished':
      case 'complete':
      case 'completed':
      case 'full_time':
      case 'ft':
        return 'finished';
      case 'scheduled':
      case 'not_started':
      case 'notstarted':
      case 'pending':
      case 'upcoming':
        return 'upcoming';
      default:
        return value;
    }
  }

  /// Whether the match is currently live.
  bool get isLive => normalizedStatus == 'live';

  /// Whether the match is finished.
  bool get isFinished => normalizedStatus == 'finished';

  /// Whether the match is upcoming.
  bool get isUpcoming => normalizedStatus == 'upcoming';

  /// Kickoff label (time or status).
  String get kickoffLabel {
    if (isLive) return 'LIVE';
    if (isFinished) return 'FT';
    return kickoffTime ?? '--:--';
  }
}

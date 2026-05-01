import 'package:fanzone/models/sports/competition_model.dart';
import 'package:fanzone/models/sports/match_model.dart';
import 'package:fanzone/models/auth_and_user/wallet.dart';

CompetitionModel sampleCompetition({
  String id = 'competition_alpha',
  String name = 'Test Competition',
  String shortName = 'TC1',
  String country = 'TC',
}) {
  return CompetitionModel(
    id: id,
    name: name,
    shortName: shortName,
    country: country,
    currentSeasonLabel: '2025/26',
  );
}

MatchModel sampleMatch({
  String id = 'match_1',
  String competitionId = 'competition_alpha',
  String homeTeam = 'Test Club A',
  String awayTeam = 'Test Club B',
  String? homeTeamId,
  String? awayTeamId,
  DateTime? date,
  String status = 'scheduled',
  int? ftHome,
  int? ftAway,
  String kickoffTime = '18:00',
}) {
  return MatchModel(
    id: id,
    competitionId: competitionId,
    seasonLabel: '2025/26',
    date: date ?? DateTime(2026, 4, 19),
    kickoffTime: kickoffTime,
    homeTeamId: homeTeamId,
    awayTeamId: awayTeamId,
    homeTeam: homeTeam,
    awayTeam: awayTeam,
    ftHome: ftHome,
    ftAway: ftAway,
    status: status,
    dataSource: 'test',
  );
}

WalletTransaction sampleWalletTransaction({
  String id = 'tx_1',
  String title = 'Pool reward',
  int amount = 420,
  String type = 'earn',
  DateTime? date,
  String dateStr = '2h ago',
}) {
  return WalletTransaction(
    id: id,
    title: title,
    amount: amount,
    type: type,
    date: date ?? DateTime(2026, 4, 19, 11),
    dateStr: dateStr,
  );
}

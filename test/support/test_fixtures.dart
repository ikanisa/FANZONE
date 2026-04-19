import 'package:fanzone/models/competition_model.dart';
import 'package:fanzone/models/match_model.dart';
import 'package:fanzone/models/pool.dart';
import 'package:fanzone/models/wallet.dart';

CompetitionModel sampleCompetition({
  String id = 'epl',
  String name = 'Premier League',
  String shortName = 'EPL',
  String country = 'GB',
}) {
  return CompetitionModel(
    id: id,
    name: name,
    shortName: shortName,
    country: country,
    dataSource: 'test',
  );
}

MatchModel sampleMatch({
  String id = 'match_1',
  String competitionId = 'epl',
  String homeTeam = 'Liverpool',
  String awayTeam = 'Arsenal',
  DateTime? date,
  String status = 'upcoming',
  int? ftHome,
  int? ftAway,
  String kickoffTime = '18:00',
}) {
  return MatchModel(
    id: id,
    competitionId: competitionId,
    season: '2025/26',
    date: date ?? DateTime(2026, 4, 19),
    kickoffTime: kickoffTime,
    homeTeam: homeTeam,
    awayTeam: awayTeam,
    ftHome: ftHome,
    ftAway: ftAway,
    status: status,
    dataSource: 'test',
  );
}

ScorePool samplePool({
  String id = 'pool_1',
  String status = 'open',
  DateTime? lockAt,
}) {
  return ScorePool(
    id: id,
    matchId: 'match_1',
    matchName: 'Liverpool vs Arsenal',
    creatorId: 'creator_1',
    creatorName: 'Fan Prime',
    creatorPrediction: 'Liverpool 2 - 1 Arsenal',
    stake: 150,
    totalPool: 1200,
    participantsCount: 18,
    status: status,
    lockAt: lockAt ?? DateTime(2026, 4, 19, 18),
  );
}

PoolEntry sampleEntry({
  String id = 'entry_1',
  String poolId = 'pool_1',
  String status = 'active',
}) {
  return PoolEntry(
    id: id,
    poolId: poolId,
    userId: 'user_1',
    userName: 'You',
    predictedHomeScore: 2,
    predictedAwayScore: 1,
    stake: 150,
    status: status,
    payout: 0,
  );
}

WalletTransaction sampleWalletTransaction({
  String id = 'tx_1',
  String title = 'Challenge payout',
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

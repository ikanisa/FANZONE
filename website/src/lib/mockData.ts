import { type Match, type FanClub, type Pool, type ScorePool, type PoolEntry } from '../types';

export const mockMatches: Match[] = [
  {
    id: 'm1',
    homeTeam: 'APR FC',
    awayTeam: 'Rayon Sports',
    startTime: new Date().toISOString(),
    status: 'live',
    score: '1 - 0',
    time: "63'",
    league: 'Rwanda Premier',
    odds: { home: 1.85, draw: 3.40, away: 4.20 }
  },
  {
    id: 'm2',
    homeTeam: 'Kiyovu Sports',
    awayTeam: 'Police FC',
    startTime: new Date().toISOString(),
    status: 'live',
    score: '0 - 0',
    time: "12'",
    league: 'Rwanda Premier',
    odds: { home: 2.10, draw: 3.20, away: 3.50 }
  },
  {
    id: 'm3',
    homeTeam: 'Real Madrid',
    awayTeam: 'AC Milan',
    startTime: new Date(Date.now() + 86400000).toISOString(),
    status: 'upcoming',
    time: '21:00',
    league: 'UCL',
    odds: { home: 1.50, draw: 4.00, away: 6.00 }
  },
  {
    id: 'm4',
    homeTeam: 'Juventus',
    awayTeam: 'Inter Milan',
    startTime: new Date(Date.now() + 86400000).toISOString(),
    status: 'upcoming',
    time: '20:30',
    league: 'Serie A',
    odds: { home: 2.30, draw: 3.40, away: 2.80 }
  },
  {
    id: 'm5',
    homeTeam: 'Liverpool',
    awayTeam: 'Arsenal',
    startTime: new Date(Date.now() + 172800000).toISOString(),
    status: 'upcoming',
    time: 'Tomorrow',
    league: 'EPL',
    odds: { home: 1.40, draw: 4.50, away: 7.00 }
  },
  {
    id: 'm6',
    homeTeam: 'Mukura VS',
    awayTeam: 'AS Kigali',
    startTime: new Date(Date.now() + 172800000).toISOString(),
    status: 'upcoming',
    time: 'Tomorrow',
    league: 'Rwanda Premier',
    odds: { home: 1.60, draw: 4.20, away: 5.00 }
  }
];

export const mockFanClubs: FanClub[] = [
  { id: 'apr', name: 'APR FC', members: 12400, totalPool: 1620000, crest: '🛡️', league: 'Rwanda Premier League', rank: 1 },
  { id: 'rayon', name: 'Rayon Sports', members: 29800, totalPool: 2450000, crest: '🦁', league: 'Rwanda Premier League', rank: 2 },
  { id: 'amavubi', name: 'Amavubi', members: 82250, totalPool: 3100000, crest: '🇷🇼', league: 'National Team', rank: 3 },
  { id: 'arsenal', name: 'Arsenal Rwanda', members: 38900, totalPool: 2800000, crest: '🔴', league: 'Local Chapter', rank: 4 },
  { id: 'chelsea', name: 'Chelsea Kigali', members: 21000, totalPool: 2100000, crest: '🔵', league: 'Local Chapter', rank: 5 }
];

export const mockPools: Pool[] = [
  {
    id: 'c1',
    poolrId: 'u1',
    poolrName: 'VallettaUltra',
    targetId: 'me',
    targetName: 'You',
    matchId: 'm1',
    matchName: 'Hamrun vs Valletta',
    wager: 500,
    status: 'pending'
  },
  {
    id: 'c2',
    poolrId: 'me',
    poolrName: 'You',
    targetId: 'u2',
    targetName: 'MalteseFalcon',
    matchId: 'm3',
    matchName: 'RMA vs ACM',
    wager: 1000,
    status: 'accepted'
  }
];

export const mockScorePools: ScorePool[] = [
  {
    id: 'sc1',
    matchId: 'm3',
    matchName: 'Real Madrid vs AC Milan',
    creatorId: 'u3',
    creatorName: 'BigPredictor',
    creatorPrediction: 'Real Madrid 3:1 AC Milan',
    stake: 500,
    totalPool: 1500,
    participantsCount: 3,
    status: 'open',
    lockAt: new Date(Date.now() + 86400000).toISOString()
  },
  {
    id: 'sc2',
    matchId: 'm1',
    matchName: 'Hamrun Spartans vs Valletta',
    creatorId: 'u4',
    creatorName: 'StJulianBoss',
    creatorPrediction: 'Hamrun Spartans 1:2 Valletta',
    stake: 2000,
    totalPool: 4000,
    participantsCount: 2,
    status: 'open',
    lockAt: new Date(Date.now() + 86400000).toISOString()
  }
];

export const mockPoolEntries: PoolEntry[] = [
  {
    id: 'e1',
    poolId: 'sc1',
    userId: 'u3',
    userName: 'BigPredictor',
    predictedHomeScore: 3,
    predictedAwayScore: 1,
    stake: 500,
    status: 'active',
    payout: 0
  },
  {
    id: 'e2',
    poolId: 'sc1',
    userId: 'u5',
    userName: 'PacevillePro',
    predictedHomeScore: 2,
    predictedAwayScore: 2,
    stake: 500,
    status: 'active',
    payout: 0
  },
  {
    id: 'e3',
    poolId: 'sc1',
    userId: 'u6',
    userName: 'GozoFan',
    predictedHomeScore: 1,
    predictedAwayScore: 0,
    stake: 500,
    status: 'active',
    payout: 0
  },
  {
    id: 'e4',
    poolId: 'sc2',
    userId: 'u4',
    userName: 'StJulianBoss',
    predictedHomeScore: 1,
    predictedAwayScore: 2,
    stake: 2000,
    status: 'active',
    payout: 0
  },
  {
    id: 'e5',
    poolId: 'sc2',
    userId: 'u7',
    userName: 'SmartBettor',
    predictedHomeScore: 0,
    predictedAwayScore: 0,
    stake: 2000,
    status: 'active',
    payout: 0
  }
];

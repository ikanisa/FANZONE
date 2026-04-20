export interface User {
  id: string;
  name: string;
  phone: string;
  isVerified: boolean;
}

export interface Match {
  id: string;
  homeTeam: string;
  awayTeam: string;
  startTime: string;
  status: 'upcoming' | 'live' | 'finished';
  score?: string;
  time?: string;
  league: string;
  odds: {
    home: number;
    draw: number;
    away: number;
  };
}

export interface FanClub {
  id: string;
  name: string;
  members: number;
  totalPool: number;
  crest: string;
  league: string;
  rank: number;
}

export interface ScorePool {
  id: string;
  matchId: string;
  matchName: string; // e.g., 'RMA vs FCB'
  creatorId: string;
  creatorName: string;
  creatorPrediction: string; // e.g. "RMA 2:1 FCB"
  stake: number;
  totalPool: number;
  participantsCount: number;
  status: 'open' | 'locked' | 'settled' | 'void';
  lockAt: string; // ISO string 
}

export interface PoolEntry {
  id: string;
  poolId: string;
  userId: string;
  userName: string;
  predictedHomeScore: number;
  predictedAwayScore: number;
  stake: number;
  status: 'active' | 'winner' | 'loser' | 'refunded';
  payout: number;
}

// Keeping original Pool in case used in SocialHub
export interface Pool {
  id: string;
  poolrId: string;
  poolrName: string;
  targetId: string;
  targetName: string;
  matchId: string;
  matchName: string;
  wager: number;
  status: 'pending' | 'accepted' | 'declined' | 'settled';
}

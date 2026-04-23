export type MatchStatus = 'upcoming' | 'live' | 'finished' | string;

export interface User {
  id: string;
  name: string;
  phone: string;
  isVerified: boolean;
}

export interface Match {
  id: string;
  competitionId: string;
  competitionName: string;
  competitionLabel: string;
  seasonId?: string | null;
  seasonLabel?: string | null;
  stage?: string | null;
  round?: string | null;
  matchdayOrRound?: string | null;
  date: string;
  startTime?: string;
  kickoffTime?: string | null;
  kickoffLabel: string;
  dateLabel: string;
  timeLabel: string;
  homeTeamId?: string | null;
  awayTeamId?: string | null;
  homeTeam: string;
  awayTeam: string;
  homeLogoUrl?: string | null;
  awayLogoUrl?: string | null;
  ftHome?: number | null;
  ftAway?: number | null;
  score?: string | null;
  liveMinute?: number | null;
  status: MatchStatus;
  resultCode?: string | null;
  isNeutral: boolean;
  dataSource: string;
  notes?: string | null;
  isLive: boolean;
  isFinished: boolean;
  isUpcoming: boolean;
}

export interface Competition {
  id: string;
  name: string;
  shortName: string;
  country: string;
  tier: number;
  competitionType?: string | null;
  isFeatured: boolean;
  isInternational: boolean;
  isActive: boolean;
  currentSeasonId?: string | null;
  currentSeasonLabel?: string | null;
  futureMatchCount: number;
  catalogRank?: number | null;
}

export interface Team {
  id: string;
  name: string;
  shortName: string;
  slug: string;
  country?: string | null;
  countryCode?: string | null;
  teamType: string;
  description?: string | null;
  leagueName?: string | null;
  region?: string | null;
  competitionIds: string[];
  aliases: string[];
  searchTerms: string[];
  logoUrl?: string | null;
  crestUrl?: string | null;
  coverImageUrl?: string | null;
  isActive: boolean;
  isFeatured: boolean;
  isPopularPick: boolean;
  popularPickRank?: number | null;
  fanCount: number;
}

export interface StandingRow {
  id: string;
  competitionId: string;
  seasonId: string;
  season: string;
  snapshotType: string;
  snapshotDate: string;
  teamId: string;
  teamName: string;
  position: number;
  played: number;
  won: number;
  drawn: number;
  lost: number;
  goalsFor: number;
  goalsAgainst: number;
  goalDifference: number;
  points: number;
}

export interface TeamFormFeature {
  matchId: string;
  teamId: string;
  last5Points: number;
  last5Wins: number;
  last5Draws: number;
  last5Losses: number;
  last5GoalsFor: number;
  last5GoalsAgainst: number;
  last5CleanSheets: number;
  last5FailedToScore: number;
  homeFormLast5: number;
  awayFormLast5: number;
  over25Last5: number;
  bttsLast5: number;
}

export interface PredictionEngineOutput {
  id: string;
  matchId: string;
  modelVersion: string;
  homeWinScore: number;
  drawScore: number;
  awayWinScore: number;
  over25Score: number;
  bttsScore: number;
  predictedHomeGoals?: number | null;
  predictedAwayGoals?: number | null;
  confidenceLabel: string;
  generatedAt: string;
}

export interface PredictionConsensus {
  matchId: string;
  totalPredictions: number;
  homePickCount: number;
  drawPickCount: number;
  awayPickCount: number;
  homePct: number;
  drawPct: number;
  awayPct: number;
}

export interface UserPrediction {
  id: string;
  matchId: string;
  predictedResultCode?: string | null;
  predictedOver25?: boolean | null;
  predictedBtts?: boolean | null;
  predictedHomeGoals?: number | null;
  predictedAwayGoals?: number | null;
  pointsAwarded: number;
  rewardStatus: string;
  createdAt: string;
  updatedAt: string;
}

export interface LeaderboardEntry {
  userId: string;
  displayName: string;
  predictionCount: number;
  totalPoints: number;
  totalFet: number;
  correctResults: number;
  exactScores: number;
}

export interface ViewerProfile {
  userId: string;
  fanId: string;
  displayName: string;
  favoriteTeamId?: string | null;
  favoriteTeamName?: string | null;
  onboardingCompleted: boolean;
  isAnonymous: boolean;
  authMethod: string;
}

export interface ViewerWallet {
  availableBalanceFet: number;
  lockedBalanceFet: number;
  fanId?: string | null;
  displayName?: string | null;
}

export interface ViewerNotification {
  id: string;
  type: string;
  title: string;
  body: string;
  data: Record<string, unknown>;
  sentAt: string;
  readAt?: string | null;
}

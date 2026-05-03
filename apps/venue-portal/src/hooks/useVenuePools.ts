import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import type {
  AppMatchRow,
  Json,
  MatchPool,
  MatchPoolCamp,
  MatchPoolStatsRow,
} from '@fanzone/core';

export type VenuePool = MatchPool & {
  matchName: string;
  kickoffAt: string | null;
  competitionName?: string | null;
  endorsementStatus: 'not_required' | 'pending' | 'endorsed' | 'rejected';
  barStakeFet: number;
};

export interface VenuePoolMatchOption {
  match_id: string;
  match_label: string;
  competition_name: string | null;
  kickoff_at: string | null;
  match_status: string | null;
  country_code: string | null;
  venue_id: string | null;
  curation_reason: string | null;
  priority_score: number;
  official_pool_id: string | null;
}

export interface CreateVenueOfficialPoolInput {
  venueId: string;
  matchId: string;
  title?: string | null;
  entryFeeFet: number;
  stakeMinFet: number;
  stakeMaxFet: number;
  creatorRewardFet: number;
  barStakeFet: number;
}

function mapCamps(value: Json): MatchPoolCamp[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .filter((item): item is Record<string, Json | undefined> => !!item && typeof item === 'object' && !Array.isArray(item))
    .map((item) => ({
      id: String(item.id ?? ''),
      poolId: '',
      code: String(item.code ?? ''),
      label: String(item.label ?? ''),
      resultCode: typeof item.result_code === 'string' ? item.result_code : null,
      memberCount: Number(item.member_count ?? 0),
      totalStakedFet: Number(item.total_staked_fet ?? 0),
      displayOrder: Number(item.display_order ?? 0),
      isWinningCamp: item.is_winning_camp === true,
    }))
    .filter((camp) => camp.id.length > 0);
}

function mapPool(row: MatchPoolStatsRow, match?: AppMatchRow): VenuePool {
  const homeTeam = match?.home_team || 'Home';
  const awayTeam = match?.away_team || 'Away';
  const metadata = row.metadata && typeof row.metadata === 'object' && !Array.isArray(row.metadata)
    ? row.metadata
    : {};
  const endorsement = String(metadata.venue_endorsement_status ?? (row.is_official ? 'endorsed' : 'not_required'));
  const rawBarStake = metadata.bar_stake_fet;
  const barStakeFet = typeof rawBarStake === 'number' ? rawBarStake : Number(rawBarStake ?? 0);

  return {
    id: row.id,
    matchId: row.match_id,
    scope: row.scope,
    countryCode: row.country_code,
    venueId: row.venue_id,
    creatorUserId: row.creator_user_id,
    title: row.title,
    status: row.status,
    isOfficial: row.is_official,
    entryFeeFet: row.entry_fee_fet,
    stakeMinFet: row.stake_min_fet,
    stakeMaxFet: row.stake_max_fet,
    totalMembers: row.total_members,
    totalStakedFet: row.total_staked_fet,
    creatorRewardFet: row.creator_reward_fet,
    rulesJson: row.rules_json,
    shareUrl: row.share_url,
    socialCardUrl: row.social_card_url,
    camps: mapCamps(row.camps),
    lockedAt: row.locked_at,
    settledAt: row.settled_at,
    metadata: row.metadata,
    createdAt: row.created_at,
    matchName: `${homeTeam} vs ${awayTeam}`,
    kickoffAt: match?.match_date ?? null,
    competitionName: match?.competition_name,
    barStakeFet: Number.isFinite(barStakeFet) ? Math.max(0, barStakeFet) : 0,
    endorsementStatus:
      endorsement === 'pending' || endorsement === 'endorsed' || endorsement === 'rejected'
        ? endorsement
        : 'not_required',
  };
}

export function useVenuePools(venueId: string | undefined) {
  const [pools, setPools] = useState<VenuePool[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [refreshToken, setRefreshToken] = useState(0);

  useEffect(() => {
    if (!venueId) return;

    let isMounted = true;

    const fetchPools = async () => {
      setLoading(true);
      setError(null);

      try {
        const { data: poolRows, error: poolError } = await supabase
          .from('match_pool_stats')
          .select('*')
          .eq('venue_id', venueId)
          .order('created_at', { ascending: false });

        if (poolError) throw poolError;

        const rows = (poolRows ?? []) as MatchPoolStatsRow[];
        const matchIds = [...new Set(rows.map((row) => row.match_id))];
        let matchById = new Map<string, AppMatchRow>();

        if (matchIds.length > 0) {
          const { data: matchRows, error: matchError } = await supabase
            .from('app_matches')
            .select('id, competition_id, competition_name, match_date, home_team, away_team, status, match_status')
            .in('id', matchIds);

          if (matchError) throw matchError;
          matchById = new Map(((matchRows ?? []) as AppMatchRow[]).map((match) => [match.id, match]));
        }

        if (isMounted) {
          setPools(rows.map((row) => mapPool(row, matchById.get(row.match_id))));
        }
      } catch (err) {
        if (isMounted) {
          setError(err instanceof Error ? err.message : 'Failed to load venue pools.');
        }
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    };

    fetchPools();

    const channel = supabase
      .channel(`venue-pools-${venueId}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'match_pools', filter: `venue_id=eq.${venueId}` },
        () => fetchPools(),
      )
      .subscribe();

    return () => {
      isMounted = false;
      supabase.removeChannel(channel);
    };
  }, [venueId, refreshToken]);

  return {
    pools: venueId ? pools : [],
    loading: venueId ? loading : false,
    error: venueId ? error : null,
    refresh: () => setRefreshToken((value) => value + 1),
  };
}

export function useVenuePoolMatchOptions(venueId: string | undefined) {
  const [options, setOptions] = useState<VenuePoolMatchOption[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [refreshToken, setRefreshToken] = useState(0);

  useEffect(() => {
    if (!venueId) return;

    const currentVenueId = venueId;
    let isMounted = true;

    async function fetchOptions() {
      setLoading(true);
      setError(null);

      try {
        const { data, error: rpcError } = await supabase.rpc(
          'venue_pool_match_options',
          { p_venue_id: currentVenueId, p_limit: 50 },
        );
        if (rpcError) throw rpcError;
        if (isMounted) {
          setOptions((data ?? []) as VenuePoolMatchOption[]);
        }
      } catch (err) {
        if (isMounted) {
          setError(err instanceof Error ? err.message : 'Failed to load curated match options.');
        }
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    }

    fetchOptions();

    return () => {
      isMounted = false;
    };
  }, [venueId, refreshToken]);

  return {
    options: venueId ? options : [],
    loading: venueId ? loading : false,
    error: venueId ? error : null,
    refresh: () => setRefreshToken((value) => value + 1),
  };
}

export async function createVenueOfficialPool(input: CreateVenueOfficialPoolInput) {
  const { data, error } = await supabase.rpc('create_venue_official_match_pool', {
    p_venue_id: input.venueId,
    p_match_id: input.matchId,
    p_title: input.title?.trim() || null,
    p_entry_fee_fet: input.entryFeeFet,
    p_stake_min_fet: input.stakeMinFet,
    p_stake_max_fet: input.stakeMaxFet,
    p_creator_reward_fet: input.creatorRewardFet,
    p_bar_stake_fet: input.barStakeFet,
  });

  if (error) throw error;
  return data;
}

export async function generateVenuePoolSocialCard(poolId: string) {
  const { data, error } = await supabase.functions.invoke(
    'generate-pool-social-card',
    { body: { pool_id: poolId } },
  );

  if (error) throw error;
  return data;
}

export async function endorseVenuePool(poolId: string, venueId: string) {
  const { data, error } = await supabase.rpc('venue_endorse_pool', {
    p_pool_id: poolId,
    p_venue_id: venueId,
  });

  if (error) throw error;
  return data;
}

export async function rejectVenuePool(poolId: string, venueId: string, reason?: string) {
  const { data, error } = await supabase.rpc('venue_reject_pool', {
    p_pool_id: poolId,
    p_venue_id: venueId,
    p_reason: reason?.trim() || null,
  });

  if (error) throw error;
  return data;
}

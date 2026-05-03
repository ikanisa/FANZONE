import type { Json, MenuItemRow, Venue, VenueRow } from '@fanzone/core';
import { supabase } from '../lib/supabase';

export type VenueScreenMode =
  | 'welcome'
  | 'qr'
  | 'pool'
  | 'game_lobby'
  | 'game_question'
  | 'leaderboard'
  | 'winners'
  | 'menu'
  | 'promo';

export interface VenueScreenState {
  venueId: string;
  mode: VenueScreenMode;
  activePoolId: string | null;
  activeGameSessionId: string | null;
  payload: Json | null;
  updatedAt: string;
}

export interface TvPoolCamp {
  id: string;
  label: string;
  memberCount: number;
  totalStakedFet: number;
  isWinningCamp: boolean;
}

export interface TvPoolDisplay {
  id: string;
  title: string;
  status: string;
  matchLabel: string;
  totalMembers: number;
  totalStakedFet: number;
  camps: TvPoolCamp[];
}

export interface TvGameSession {
  id: string;
  venueId: string;
  templateName: string;
  templateCategory: string;
  status: string;
  scheduledStartAt: string;
  rewardFet: number;
  selectedQuestionCount: number;
  currentQuestionOrdinal: number | null;
}

export interface TvGameTeam {
  id: string;
  name: string;
  scoreFet: number;
  memberCount: number;
}

export interface TvGameQuestion {
  ordinal: number;
  prompt: string;
  options: Json;
}

export interface TvGameDisplay {
  session: TvGameSession;
  teams: TvGameTeam[];
  currentQuestion: TvGameQuestion | null;
}

type ScreenStateRow = {
  venue_id: string;
  mode: VenueScreenMode;
  active_pool_id: string | null;
  active_game_session_id: string | null;
  payload: Json | null;
  updated_at: string;
};

type PoolStatsRow = {
  id: string;
  venue_id?: string | null;
  title: string | null;
  status: string;
  total_members: number;
  total_staked_fet: number;
  camps: Json;
  match_label?: string | null;
  competition_name?: string | null;
};

type GameSessionRow = {
  id: string;
  venue_id: string;
  status: string;
  scheduled_start_at: string;
  reward_fet: number;
  selected_question_count: number;
  current_question_ordinal: number | null;
  template?: { name?: string | null; category?: string | null } | Array<{ name?: string | null; category?: string | null }> | null;
};

type GameTeamRow = {
  id: string;
  name: string;
  score_fet: number;
  members?: Array<{ user_id: string }> | null;
};

type QuestionRow = {
  ordinal: number;
  prompt: string;
  options: Json;
};

function isUuid(value: string) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function toNumber(value: unknown, fallback = 0) {
  const parsed = Number(value ?? fallback);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function asObject(value: Json | null | undefined): Record<string, Json | undefined> {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, Json | undefined>)
    : {};
}

function mapVenue(row: VenueRow): Venue {
  return {
    id: row.id,
    name: row.name,
    slug: row.slug,
    description: row.description,
    address: row.address_line1,
    country: row.country_code,
    logoUrl: row.logo_url,
    coverUrl: row.cover_url,
    isOpen: row.is_open,
    hoursJson:
      row.hours_json && typeof row.hours_json === 'object' && !Array.isArray(row.hours_json)
        ? (row.hours_json as Record<string, Json>)
        : undefined,
    revolutLink: row.revolut_link,
    momoCode: row.momo_code,
    whatsapp: row.whatsapp,
    primaryCategory: row.primary_category,
    rating: row.rating,
    priceLevel: row.price_level,
  };
}

function mapScreenState(row: ScreenStateRow): VenueScreenState {
  return {
    venueId: row.venue_id,
    mode: row.mode,
    activePoolId: row.active_pool_id,
    activeGameSessionId: row.active_game_session_id,
    payload: row.payload,
    updatedAt: row.updated_at,
  };
}

function templateFrom(row: GameSessionRow) {
  if (Array.isArray(row.template)) return row.template[0] ?? {};
  return row.template ?? {};
}

function mapGameSession(row: GameSessionRow): TvGameSession {
  const template = templateFrom(row);
  return {
    id: row.id,
    venueId: row.venue_id,
    templateName: template.name ?? 'Venue game',
    templateCategory: template.category ?? 'game',
    status: row.status,
    scheduledStartAt: row.scheduled_start_at,
    rewardFet: toNumber(row.reward_fet),
    selectedQuestionCount: toNumber(row.selected_question_count),
    currentQuestionOrdinal:
      row.current_question_ordinal == null ? null : toNumber(row.current_question_ordinal),
  };
}

function mapCamp(value: Json): TvPoolCamp | null {
  const record = asObject(value);
  const id = typeof record.id === 'string' ? record.id : null;
  const label = typeof record.label === 'string' ? record.label : null;
  if (!id || !label) return null;

  return {
    id,
    label,
    memberCount: toNumber(record.member_count),
    totalStakedFet: toNumber(record.total_staked_fet),
    isWinningCamp: Boolean(record.is_winning_camp),
  };
}

function mapPool(row: PoolStatsRow): TvPoolDisplay {
  return {
    id: row.id,
    title: row.title ?? 'Prediction pool',
    status: row.status,
    matchLabel: row.match_label ?? row.competition_name ?? 'Venue-linked match',
    totalMembers: toNumber(row.total_members),
    totalStakedFet: toNumber(row.total_staked_fet),
    camps: Array.isArray(row.camps) ? row.camps.map(mapCamp).filter((camp): camp is TvPoolCamp => Boolean(camp)) : [],
  };
}

export async function resolveVenue(venueKey: string): Promise<Venue> {
  const query = supabase.from('venues').select('*').limit(1);
  const { data, error } = isUuid(venueKey)
    ? await query.eq('id', venueKey).maybeSingle()
    : await query.eq('slug', venueKey).maybeSingle();

  if (error) throw error;
  if (!data) throw new Error('Venue screen could not find this venue.');
  return mapVenue(data as VenueRow);
}

export async function fetchScreenState(venueId: string): Promise<VenueScreenState | null> {
  const { data, error } = await supabase
    .from('venue_screen_states' as never)
    .select('*')
    .eq('venue_id', venueId)
    .maybeSingle();

  if (error) throw error;
  return data ? mapScreenState(data as unknown as ScreenStateRow) : null;
}

export async function fetchPoolDisplay(venueId: string, poolId: string): Promise<TvPoolDisplay | null> {
  const { data, error } = await supabase
    .from('match_pool_stats')
    .select('*')
    .eq('id', poolId)
    .maybeSingle();

  if (error) throw error;
  if (!data) return null;

  const row = data as unknown as PoolStatsRow;
  if (row.venue_id && row.venue_id !== venueId) return null;
  return mapPool(row);
}

export async function fetchGameDisplay(venueId: string, sessionId: string): Promise<TvGameDisplay | null> {
  const { data: sessionData, error: sessionError } = await supabase
    .from('game_sessions' as never)
    .select('*, template:game_templates(name, category)')
    .eq('id', sessionId)
    .eq('venue_id', venueId)
    .maybeSingle();

  if (sessionError) throw sessionError;
  if (!sessionData) return null;

  const session = mapGameSession(sessionData as unknown as GameSessionRow);
  const { data: teamRows, error: teamError } = await supabase
    .from('game_teams' as never)
    .select('*, members:game_team_members(user_id)')
    .eq('session_id', sessionId)
    .eq('venue_id', venueId)
    .order('score_fet', { ascending: false });

  if (teamError) throw teamError;

  let currentQuestion: TvGameQuestion | null = null;
  if (session.currentQuestionOrdinal) {
    const { data: questionRows, error: questionError } = await supabase.rpc('get_game_session_question' as never, {
      p_session_id: sessionId,
      p_ordinal: session.currentQuestionOrdinal,
    } as never);
    if (questionError) throw questionError;
    const question = Array.isArray(questionRows) ? (questionRows[0] as QuestionRow | undefined) : undefined;
    if (question) {
      currentQuestion = {
        ordinal: toNumber(question.ordinal),
        prompt: question.prompt,
        options: question.options,
      };
    }
  }

  return {
    session,
    teams: ((teamRows ?? []) as unknown as GameTeamRow[]).map((team) => ({
      id: team.id,
      name: team.name,
      scoreFet: toNumber(team.score_fet),
      memberCount: team.members?.length ?? 0,
    })),
    currentQuestion,
  };
}

export async function fetchMenuHighlights(venueId: string): Promise<MenuItemRow[]> {
  const { data, error } = await supabase
    .from('menu_items')
    .select('*')
    .eq('venue_id', venueId)
    .eq('is_available', true)
    .order('is_featured', { ascending: false })
    .order('display_order', { ascending: true })
    .limit(6);

  if (error) throw error;
  return (data ?? []) as MenuItemRow[];
}

export function subscribeToVenueScreen(venueId: string, onChange: () => void) {
  const channel = supabase
    .channel(`tv-display:${venueId}`)
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'venue_screen_states',
        filter: `venue_id=eq.${venueId}`,
      },
      onChange,
    )
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'game_teams',
        filter: `venue_id=eq.${venueId}`,
      },
      onChange,
    )
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'game_sessions',
        filter: `venue_id=eq.${venueId}`,
      },
      onChange,
    )
    .subscribe();

  return () => {
    void supabase.removeChannel(channel);
  };
}

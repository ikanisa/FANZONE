export interface MatchRow {
  id: string;
  date: string;
  status: string | null;
  home_team: string | null;
  away_team: string | null;
  ft_home?: number | null;
  ft_away?: number | null;
}

export interface GoalEventRow {
  id: string;
  match_id: string;
  minute: number | null;
  team: string | null;
  player: string | null;
  details: string | null;
  created_at: string;
}

export function singleMatch(
  value: MatchRow | MatchRow[] | null,
): MatchRow | null {
  if (Array.isArray(value)) {
    return value[0] ?? null;
  }

  return value ?? null;
}

export function uniqueUserIds(userIds: string[]): string[] {
  return [...new Set(userIds)];
}

export function buildGoalAlertTitle(event: GoalEventRow): string {
  return `Goal at ${event.minute ?? 0}'`;
}

export function buildGoalAlertBody(event: GoalEventRow): string {
  const scorer = event.player?.trim();
  const team = event.team?.trim();

  if (scorer && team) {
    return `${scorer} scored for ${team}.`;
  }

  if (team) {
    return `${team} just scored.`;
  }

  return "A goal was just scored.";
}

export function buildResultDispatchKey(
  match: Pick<MatchRow, "ft_home" | "ft_away">,
): string {
  return `result:${match.ft_home ?? 0}-${match.ft_away ?? 0}`;
}

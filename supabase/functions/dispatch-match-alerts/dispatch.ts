export interface MatchRow {
  id: string;
  date: string;
  status: string | null;
  home_team: string | null;
  away_team: string | null;
  ft_home?: number | null;
  ft_away?: number | null;
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

export function buildResultDispatchKey(
  match: Pick<MatchRow, "ft_home" | "ft_away">,
): string {
  return `result:${match.ft_home ?? 0}-${match.ft_away ?? 0}`;
}

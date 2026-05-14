import type { Match } from "../types";
import {
  ensureClient,
  maybeSingle,
  selectList,
  type JsonRecord,
} from "./apiClient";
import { normalizeMatchRow } from "./apiMappers";

export async function getLiveMatches(limit = 12): Promise<Match[]> {
  const client = await ensureClient();
  if (!client) return [];

  try {
    const rows = await selectList<JsonRecord>(
      client
        .from("curated_active_matches")
        .select("*")
        .eq("status", "live")
        .order("date", { ascending: true })
        .limit(limit),
    );
    return rows.map(normalizeMatchRow);
  } catch (error) {
    console.warn("Failed to load live matches", error);
    return [];
  }
}

export async function getUpcomingMatches(limit = 12): Promise<Match[]> {
  const client = await ensureClient();
  if (!client) return [];

  try {
    const rows = await selectList<JsonRecord>(
      client
        .from("curated_active_matches")
        .select("*")
        .in("status", ["scheduled", "upcoming"])
        .gte("date", new Date().toISOString())
        .order("date", { ascending: true })
        .limit(limit),
    );
    return rows.map(normalizeMatchRow);
  } catch (error) {
    console.warn("Failed to load upcoming matches", error);
    return [];
  }
}

export async function getMatchDetail(matchId: string): Promise<Match | null> {
  const client = await ensureClient();
  if (!client) return null;

  try {
    const row = await maybeSingle<JsonRecord>(
      client
        .from("curated_active_matches")
        .select("*")
        .eq("id", matchId)
        .maybeSingle(),
    );
    return row ? normalizeMatchRow(row) : null;
  } catch (error) {
    console.warn(`Failed to load match ${matchId}`, error);
    return null;
  }
}

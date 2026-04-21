/**
 * Fuzzy team name matcher.
 * Matches extracted fixture team names against existing matches in the database.
 * Uses normalized string similarity to handle name variations
 * (e.g. "Man Utd" vs "Manchester United", "Real" vs "Real Madrid").
 */

import type { DbMatch, ExtractedFixtureOdds, MatchResult } from "./types.ts";

/**
 * Normalize a team name for fuzzy comparison.
 * Strips accents, removes common suffixes, lowercases.
 */
function normalize(name: string): string {
  return name
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "") // strip accents
    .toLowerCase()
    .replace(/\b(fc|cf|sc|ac|as|us|rc|cd|ud|afc|bfc|fk|sk|nk)\b/gi, "")
    .replace(/[^a-z0-9\s]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * Build a set of tokens from a team name for bag-of-words matching.
 */
function tokenize(name: string): Set<string> {
  return new Set(normalize(name).split(" ").filter((t) => t.length > 1));
}

/**
 * Compute Jaccard similarity between two token sets.
 * Returns a value between 0 (no overlap) and 1 (identical).
 */
function jaccardSimilarity(a: Set<string>, b: Set<string>): number {
  if (a.size === 0 && b.size === 0) return 0;
  let intersection = 0;
  for (const token of a) {
    if (b.has(token)) intersection++;
  }
  const union = a.size + b.size - intersection;
  return union === 0 ? 0 : intersection / union;
}

/**
 * Check if one normalized name contains the other (substring match).
 * Helps with cases like "Real Madrid" matching "Real Madrid CF".
 */
function containsMatch(a: string, b: string): boolean {
  const normA = normalize(a);
  const normB = normalize(b);
  return normA.includes(normB) || normB.includes(normA);
}

/**
 * Score how well a fixture's teams match a database match.
 * Returns a score between 0 (no match) and 1 (perfect match).
 *
 * Strategy:
 * 1. Score home team matching (either direction allows for data inconsistencies)
 * 2. Score away team matching
 * 3. Combine both scores. Both must be > 0 for a valid match.
 */
function scoreFixtureMatch(
  fixture: ExtractedFixtureOdds,
  dbMatch: DbMatch,
): number {
  const fixtureHomeTok = tokenize(fixture.home_team);
  const fixtureAwayTok = tokenize(fixture.away_team);
  const dbHomeTok = tokenize(dbMatch.home_team);
  const dbAwayTok = tokenize(dbMatch.away_team);

  // Direct match: fixture.home → db.home AND fixture.away → db.away
  const directHomeScore = Math.max(
    jaccardSimilarity(fixtureHomeTok, dbHomeTok),
    containsMatch(fixture.home_team, dbMatch.home_team) ? 0.8 : 0,
  );
  const directAwayScore = Math.max(
    jaccardSimilarity(fixtureAwayTok, dbAwayTok),
    containsMatch(fixture.away_team, dbMatch.away_team) ? 0.8 : 0,
  );

  // Reversed match: fixture.home → db.away AND fixture.away → db.home
  // (handles cases where home/away order might differ between sources)
  const reversedHomeScore = Math.max(
    jaccardSimilarity(fixtureHomeTok, dbAwayTok),
    containsMatch(fixture.home_team, dbMatch.away_team) ? 0.8 : 0,
  );
  const reversedAwayScore = Math.max(
    jaccardSimilarity(fixtureAwayTok, dbHomeTok),
    containsMatch(fixture.away_team, dbMatch.home_team) ? 0.8 : 0,
  );

  const directScore =
    directHomeScore > 0 && directAwayScore > 0
      ? (directHomeScore + directAwayScore) / 2
      : 0;
  const reversedScore =
    reversedHomeScore > 0 && reversedAwayScore > 0
      ? ((reversedHomeScore + reversedAwayScore) / 2) * 0.95 // slight penalty for reversed
      : 0;

  return Math.max(directScore, reversedScore);
}

/** Minimum match score to consider a fixture linked to a DB match. */
const MIN_MATCH_SCORE = 0.5;

/**
 * Match extracted fixtures against database matches.
 * Returns only matches that score above the threshold, with the best match per fixture.
 */
export function matchFixturesToDb(
  fixtures: ExtractedFixtureOdds[],
  dbMatches: DbMatch[],
): MatchResult[] {
  const results: MatchResult[] = [];
  const usedDbMatchIds = new Set<string>();

  // Sort fixtures by confidence (highest first) to give priority to confident extractions
  const sortedFixtures = [...fixtures].sort(
    (a, b) => b.confidence - a.confidence,
  );

  for (const fixture of sortedFixtures) {
    if (!fixture.home_team || !fixture.away_team) continue;

    let bestMatch: { dbMatch: DbMatch; score: number } | null = null;

    for (const dbMatch of dbMatches) {
      // Skip already-matched DB entries (1:1 linking)
      if (usedDbMatchIds.has(dbMatch.id)) continue;

      const score = scoreFixtureMatch(fixture, dbMatch);

      if (score >= MIN_MATCH_SCORE && (!bestMatch || score > bestMatch.score)) {
        bestMatch = { dbMatch, score };
      }
    }

    if (bestMatch) {
      results.push({
        fixture,
        dbMatch: bestMatch.dbMatch,
        matchScore: bestMatch.score,
      });
      usedDbMatchIds.add(bestMatch.dbMatch.id);
    }
  }

  return results;
}

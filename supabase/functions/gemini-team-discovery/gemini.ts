import { GoogleGenerativeAI, type Tool } from "npm:@google/generative-ai";

import { DEFAULT_GEMINI_MODEL, type LeagueEntry } from "./constants.ts";
import { discoveredLeagueSchema } from "./schemas.ts";
import type {
  DiscoveredTeam,
  GroundingSummary,
  LeagueDiscoveryResult,
} from "./types.ts";

function requireEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing env: ${name}`);
  return value;
}

function getModel() {
  const genAI = new GoogleGenerativeAI(requireEnv("GEMINI_API_KEY"));
  const tools = [{ googleSearch: {} }] as unknown as Tool[];
  return genAI.getGenerativeModel({
    model: DEFAULT_GEMINI_MODEL,
    tools,
  });
}

function buildPrompt(entry: LeagueEntry): string {
  const seasonYear = new Date().getUTCFullYear();
  const seasonLabel = `${seasonYear - 1}/${seasonYear.toString().slice(2)}`;
  const leagueInstruction = entry.league == null
    ? [
      `First determine the current men's top-flight domestic football league in ${entry.country}.`,
      "Then return every club currently competing in that division.",
    ]
    : [
      `Use "${entry.league}" as the expected top-flight league for ${entry.country}, but verify it with Google Search before returning results.`,
      "If search evidence shows a different current top-flight league name, return the verified current name.",
    ];

  return [
    "You are a football data extraction worker using Google Search grounding.",
    ...leagueInstruction,
    `We need the CURRENT first-division teams for ${entry.country} (${entry.countryCode}) in the ${seasonLabel} / ${seasonYear} season.`,
    "",
    "Rules:",
    "- Return ONLY valid JSON matching the response schema.",
    "- Do not include markdown, prose, or code fences.",
    `- Return the complete top-flight roster. We expect around ${entry.expectedTeams} teams.`,
    `- 'country' must be exactly "${entry.country}".`,
    `- 'country_code' must be exactly "${entry.countryCode}".`,
    "- 'league_name' must be the verified current first-division league name.",
    "- 'short_name' should be a concise common abbreviation, usually 3-5 letters.",
    "- 'search_terms' should contain aliases, fan nicknames, abbreviations, and alternative club spellings.",
    "- 'crest_url' should be a direct HTTPS image URL when a reliable crest/badge/logo source is found. Prefer official club sites or Wikimedia Commons. Omit it when not available.",
    "- Never invent clubs. Only include teams verified by grounded search results.",
  ].join("\n");
}

function stripFences(raw: string): string {
  const trimmed = raw.trim();
  if (!trimmed.startsWith("```")) return trimmed;
  return trimmed
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();
}

function slugifyName(name: string): string {
  return name
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9\s-]/g, "")
    .trim()
    .replace(/\s+/g, "-")
    .replace(/-+/g, "-");
}

function sanitizeTeam(
  record: Record<string, unknown>,
  entry: LeagueEntry,
  leagueName: string,
): DiscoveredTeam | null {
  // Gemini grounded response may use 'team_name' instead of 'name'
  const rawName = typeof record.name === "string" ? record.name.trim()
    : typeof record.team_name === "string" ? (record.team_name as string).trim()
    : "";
  if (!rawName) return null;

  const shortName = typeof record.short_name === "string" &&
      record.short_name.trim().length > 0
    ? record.short_name.trim().toUpperCase().slice(0, 8)
    : rawName.slice(0, 5).toUpperCase();

  const crestUrl = typeof record.crest_url === "string" &&
      record.crest_url.trim().startsWith("https://")
    ? record.crest_url.trim()
    : null;

  const searchTerms = Array.isArray(record.search_terms)
    ? record.search_terms
      .map((term) => term == null ? "" : String(term).trim())
      .filter((term) => term.length > 0)
      .filter((term, index, list) => list.indexOf(term) === index)
    : [];

  const slug = slugifyName(rawName);
  if (!slug) return null;

  return {
    id: `${entry.countryCode.toLowerCase()}-${slug}`,
    name: rawName,
    short_name: shortName,
    country: entry.country,
    country_code: entry.countryCode,
    league_name: leagueName,
    search_terms: searchTerms,
    crest_url: crestUrl,
  };
}

function extractGroundingSummary(response: unknown): GroundingSummary {
  const candidates = (response as { candidates?: Array<Record<string, unknown>> })
    ?.candidates;
  const metadata = candidates?.[0]?.groundingMetadata as
    | Record<string, unknown>
    | undefined;

  const sources = new Map<string, { uri: string; title: string | null }>();
  const chunks = metadata?.groundingChunks;
  if (Array.isArray(chunks)) {
    for (const chunk of chunks) {
      if (typeof chunk !== "object" || chunk == null) continue;
      const web = (chunk as Record<string, unknown>).web;
      if (typeof web !== "object" || web == null) continue;
      const uri = String((web as Record<string, unknown>).uri ?? "").trim();
      if (!uri) continue;
      const title = String((web as Record<string, unknown>).title ?? "").trim();
      sources.set(uri, { uri, title: title || null });
    }
  }

  const queries = metadata?.webSearchQueries;
  return {
    webSearchQueries: Array.isArray(queries)
      ? queries
        .map((value) => String(value))
        .filter((value) => value.trim().length > 0)
      : [],
    sources: Array.from(sources.values()),
  };
}

/**
 * Step 2: Normalize grounded text into structured JSON using responseSchema.
 * This second call does NOT use search tools, so responseSchema is allowed.
 */
async function normalizeGroundedText(
  groundedText: string,
  entry: LeagueEntry,
): Promise<string> {
  const genAI = new GoogleGenerativeAI(requireEnv("GEMINI_API_KEY"));
  const normalizer = genAI.getGenerativeModel({
    model: DEFAULT_GEMINI_MODEL,
    // No tools — responseSchema is safe here
  });

  const normPrompt = [
    "Extract the football team data from the following grounded search results into the required JSON schema.",
    `Country: ${entry.country} (${entry.countryCode})`,
    `Expected league: ${entry.league ?? "top-flight domestic league"}`,
    "",
    "Rules:",
    "- Return ONLY the JSON, no prose or markdown.",
    `- 'country' must be exactly "${entry.country}".`,
    `- 'country_code' must be exactly "${entry.countryCode}".`,
    "- 'league_name' must be the verified current first-division league name.",
    "- 'short_name' should be a concise abbreviation (3-5 letters).",
    "- 'search_terms' should include aliases, fan nicknames, abbreviations.",
    "- Never invent clubs. Only include teams from the search results below.",
    "",
    "--- GROUNDED SEARCH RESULTS ---",
    groundedText,
  ].join("\n");

  const result = await normalizer.generateContent({
    contents: [{ role: "user", parts: [{ text: normPrompt }] }],
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: discoveredLeagueSchema,
      temperature: 0,
    },
  });

  return result.response.text();
}

export async function discoverTeamsForLeague(
  entry: LeagueEntry,
): Promise<LeagueDiscoveryResult> {
  // Step 1: Grounded search — no responseSchema/responseMimeType allowed
  const model = getModel();
  const result = await model.generateContent({
    contents: [{ role: "user", parts: [{ text: buildPrompt(entry) }] }],
    generationConfig: {
      temperature: 0.1,
    },
  });

  const grounding = extractGroundingSummary(result.response);
  const rawText = result.response.text();

  console.log(
    `[gemini-team-discovery] ${entry.country}: grounded response length=${rawText.length}, first 200 chars: ${rawText.substring(0, 200)}`,
  );
  
  // Try to parse the grounded response directly
  let parsed: Record<string, unknown>;
  try {
    const stripped = stripFences(rawText);
    parsed = JSON.parse(stripped) as Record<string, unknown>;
    console.log(
      `[gemini-team-discovery] ${entry.country}: direct parse OK, teams=${Array.isArray(parsed.teams) ? parsed.teams.length : "missing"}`,
    );
    if (!Array.isArray(parsed.teams) || parsed.teams.length === 0) {
      throw new Error("No teams array in direct parse");
    }
  } catch (directError) {
    // Step 2: Normalize grounded text → structured JSON via second Gemini call
    const directMsg = directError instanceof Error ? directError.message : String(directError);
    console.log(
      `[gemini-team-discovery] ${entry.country}: direct parse failed (${directMsg}), running normalization step...`,
    );
    const normalizedText = await normalizeGroundedText(rawText, entry);
    console.log(
      `[gemini-team-discovery] ${entry.country}: normalized response length=${normalizedText.length}, first 200 chars: ${normalizedText.substring(0, 200)}`,
    );
    const stripped = stripFences(normalizedText);
    parsed = JSON.parse(stripped) as Record<string, unknown>;
    console.log(
      `[gemini-team-discovery] ${entry.country}: normalized parse OK, teams=${Array.isArray(parsed.teams) ? parsed.teams.length : "missing"}`,
    );
  }

  const leagueName = typeof parsed.league_name === "string" &&
      parsed.league_name.trim().length > 0
    ? parsed.league_name.trim()
    : entry.league ?? `${entry.country} First Division`;

  const seen = new Set<string>();
  const teams = Array.isArray(parsed.teams)
    ? parsed.teams
      .map((item) => typeof item === "object" && item != null
        ? sanitizeTeam(item as Record<string, unknown>, entry, leagueName)
        : null)
      .filter((team): team is DiscoveredTeam => team != null)
      .filter((team) => {
        if (seen.has(team.id)) return false;
        seen.add(team.id);
        return true;
      })
    : [];

  const totalCount = typeof parsed.total_count === "number"
    ? parsed.total_count
    : teams.length;

  return {
    league_name: leagueName,
    total_count: totalCount,
    teams,
    grounding,
    debugRawText: rawText.substring(0, 500),
  };
}

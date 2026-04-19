import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  GoogleGenerativeAI,
  type Schema,
  SchemaType,
  type Tool,
} from "npm:@google/generative-ai";

const FUNCTION_NAME = "gemini-team-news";
const DEFAULT_GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ??
  "gemini-3.1-pro-preview";

// ── Types ──

type TeamNewsRequest = {
  teamId: string;
  teamName: string;
  categories?: string[];
  maxArticles?: number;
};

type CuratedNewsItem = {
  title: string;
  summary: string;
  content: string;
  category: string;
  source_url: string;
  source_name: string;
};

// ── Constants ──

const NEWS_CATEGORIES = [
  "breaking_news",
  "transfers",
  "match_updates",
  "club_announcements",
  "fan_community_news",
  "general",
] as const;

const corsHeaders = {
  "Access-Control-Allow-Origin": Deno.env.get("ALLOWED_ORIGIN")?.trim() || "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-team-news-sync-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ── Schema ──

const newsItemSchema: Schema = {
  type: SchemaType.OBJECT,
  properties: {
    title: {
      type: SchemaType.STRING,
      description: "Concise headline for the news article.",
    },
    summary: {
      type: SchemaType.STRING,
      description:
        "2-3 sentence summary of the article content. Grounded in source facts.",
    },
    content: {
      type: SchemaType.STRING,
      description:
        "Full article text, 3-5 paragraphs. Factual, concise, grounded in real sources.",
    },
    category: {
      type: SchemaType.STRING,
      format: "enum",
      enum: [...NEWS_CATEGORIES],
      description: "News category.",
    },
    source_url: {
      type: SchemaType.STRING,
      description:
        "URL of the primary source article. Must be a real, verifiable URL.",
    },
    source_name: {
      type: SchemaType.STRING,
      description:
        "Name of the source publication (e.g., BBC Sport, ESPN, Sky Sports).",
    },
  },
  required: [
    "title",
    "summary",
    "content",
    "category",
    "source_url",
    "source_name",
  ],
};

const responseSchema: Schema = {
  type: SchemaType.OBJECT,
  properties: {
    articles: {
      type: SchemaType.ARRAY,
      description: "List of curated news articles for the team.",
      items: newsItemSchema,
    },
  },
  required: ["articles"],
};

// ── Helpers ──

function requireEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing env var: ${name}`);
  return value;
}

function readBearerToken(req: Request): string | null {
  const authHeader = req.headers.get("authorization")?.trim();
  if (!authHeader) return null;

  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}

function assertAuthorized(req: Request) {
  const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
  const bearerToken = readBearerToken(req);
  if (bearerToken === serviceRoleKey) return;

  const syncSecret = Deno.env.get("TEAM_NEWS_SYNC_SECRET")?.trim();
  if (syncSecret) {
    const provided = req.headers.get("x-team-news-sync-secret")?.trim();
    if (provided === syncSecret) return;
  }

  throw new Error("Unauthorized");
}

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function asTrimmedString(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeNewsCategory(
  value: unknown,
): (typeof NEWS_CATEGORIES)[number] {
  const candidate = asTrimmedString(value);
  if (
    candidate &&
    NEWS_CATEGORIES.includes(candidate as (typeof NEWS_CATEGORIES)[number])
  ) {
    return candidate as (typeof NEWS_CATEGORIES)[number];
  }
  return "general";
}

function normalizeHttpUrl(value: unknown): string | null {
  const candidate = asTrimmedString(value);
  if (!candidate) return null;

  try {
    const parsed = new URL(candidate);
    if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
      return null;
    }
    return parsed.toString();
  } catch {
    return null;
  }
}

function extractGroundingUris(result: unknown): Set<string> {
  const candidates = isRecord(result) && Array.isArray(result.candidates)
    ? result.candidates
    : [];
  const uris = new Set<string>();

  for (const candidate of candidates) {
    if (!isRecord(candidate)) continue;
    const metadata = candidate.groundingMetadata;
    if (!isRecord(metadata) || !Array.isArray(metadata.groundingChunks)) {
      continue;
    }

    for (const chunk of metadata.groundingChunks) {
      if (!isRecord(chunk) || !isRecord(chunk.web)) continue;
      const uri = normalizeHttpUrl(chunk.web.uri);
      if (uri) uris.add(uri);
    }
  }

  return uris;
}

function sameHost(urlA: string, urlB: string): boolean {
  try {
    return new URL(urlA).host === new URL(urlB).host;
  } catch {
    return false;
  }
}

function sanitizeNewsItem(
  value: unknown,
  groundingUris: Set<string>,
): CuratedNewsItem | null {
  if (!isRecord(value)) return null;

  const title = asTrimmedString(value.title);
  const summary = asTrimmedString(value.summary);
  const content = asTrimmedString(value.content);
  const sourceUrl = normalizeHttpUrl(value.source_url);
  const sourceName = asTrimmedString(value.source_name);

  if (!title || title.length < 8 || title.length > 180) return null;
  if (!summary || summary.length < 24 || summary.length > 800) return null;
  if (!content || content.length < 80 || content.length > 10000) return null;
  if (!sourceUrl || !sourceName || sourceName.length > 120) return null;

  const grounded = Array.from(groundingUris).some((uri) =>
    uri === sourceUrl || sameHost(uri, sourceUrl)
  );
  if (!grounded) return null;

  return {
    title,
    summary,
    content,
    category: normalizeNewsCategory(value.category),
    source_url: sourceUrl,
    source_name: sourceName,
  };
}

function sanitizeArticles(
  rawArticles: unknown,
  groundingUris: Set<string>,
  maxArticles: number,
): CuratedNewsItem[] {
  if (!Array.isArray(rawArticles)) return [];

  const deduped = new Map<string, CuratedNewsItem>();

  for (const candidate of rawArticles) {
    const article = sanitizeNewsItem(candidate, groundingUris);
    if (!article) continue;

    const key =
      `${article.source_url.toLowerCase()}|${article.title.toLowerCase()}`;
    if (!deduped.has(key)) {
      deduped.set(key, article);
    }
  }

  return Array.from(deduped.values()).slice(0, maxArticles);
}

function getSupabaseAdmin() {
  return createClient(
    requireEnv("SUPABASE_URL"),
    requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
    { auth: { autoRefreshToken: false, persistSession: false } },
  );
}

function buildPrompt(teamName: string, categories: string[]): string {
  const today = new Date().toISOString().slice(0, 10);
  const categoryList = categories.join(", ");

  return [
    "You are a sports news curator for a football fan community platform.",
    `Today's UTC date is ${today}.`,
    `Use Google Search to find the latest news about the football team "${teamName}".`,
    "",
    "Rules:",
    "- Return ONLY valid JSON matching the response schema.",
    "- Each article MUST be grounded in a real, verifiable source. Include the source_url.",
    "- Do NOT hallucinate or fabricate any news stories.",
    "- If you cannot find any real news, return an empty articles array.",
    "- Write concise, factual summaries. No speculation.",
    "- Use the team name consistently.",
    `- Categorize each article into one of: ${categoryList}.`,
    "- Prefer recent news (last 7 days). Include older relevant news only if significant.",
    "- Do not duplicate articles.",
    "- Source must be reputable sport media (BBC Sport, ESPN, Sky Sports, The Athletic, local sports press, etc.).",
    "- Content must be suitable for a fan community — no offensive or controversial commentary.",
    `- Return up to 10 articles, ordered by relevance and recency.`,
  ].join("\n");
}

// ── Main Handler ──

Deno.serve(async (req) => {
  const requestId = crypto.randomUUID();

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, {
      success: false,
      requestId,
      error: "Method not allowed.",
    });
  }

  try {
    assertAuthorized(req);
  } catch (error) {
    return jsonResponse(401, {
      success: false,
      requestId,
      error: error instanceof Error ? error.message : "Unauthorized",
    });
  }

  let body: TeamNewsRequest;
  try {
    body = await req.json();
  } catch {
    return jsonResponse(400, {
      success: false,
      requestId,
      error: "Invalid JSON body.",
    });
  }

  if (!body.teamId || !body.teamName) {
    return jsonResponse(400, {
      success: false,
      requestId,
      error: "teamId and teamName are required.",
    });
  }

  const categories = body.categories?.length
    ? body.categories
    : [...NEWS_CATEGORIES];
  const maxArticles = Math.min(body.maxArticles ?? 10, 20);

  const supabase = getSupabaseAdmin();

  // Record ingestion run
  const { data: runRecord, error: runError } = await supabase
    .from("team_news_ingestion_runs")
    .insert({
      team_id: body.teamId,
      run_type: "gemini_grounded_search",
      status: "running",
    })
    .select("id")
    .single();

  if (runError) {
    console.error(`[${FUNCTION_NAME}] Failed to create run record:`, runError);
    return jsonResponse(500, {
      success: false,
      requestId,
      error: "Failed to start ingestion run.",
    });
  }

  const runId = runRecord.id;

  try {
    // Call Gemini
    const gemini = new GoogleGenerativeAI(requireEnv("GEMINI_API_KEY"));
    const tools = [{ googleSearch: {} }] as unknown as Tool[];
    const model = gemini.getGenerativeModel({
      model: DEFAULT_GEMINI_MODEL,
      tools,
    });

    const result = await model.generateContent({
      contents: [
        {
          role: "user",
          parts: [{ text: buildPrompt(body.teamName, categories) }],
        },
      ],
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: responseSchema,
        temperature: 0.15,
      },
    });

    const text = result.response.text();
    const groundingUris = extractGroundingUris(result.response);
    let parsed: { articles: CuratedNewsItem[] };

    try {
      const cleaned = text
        .trim()
        .replace(/^```(?:json)?/i, "")
        .replace(/```$/i, "")
        .trim();
      parsed = JSON.parse(cleaned);
    } catch {
      throw new Error("Gemini returned malformed JSON.");
    }

    const articles = sanitizeArticles(
      parsed.articles,
      groundingUris,
      maxArticles,
    );

    // Extract grounding metadata
    const groundingSources =
      result.response.candidates?.[0]?.groundingMetadata?.groundingChunks?.map(
        (chunk: { web?: { uri?: string; title?: string } }) => ({
          uri: chunk.web?.uri ?? null,
          title: chunk.web?.title ?? null,
        }),
      ) ?? [];

    // Store articles as draft (admin must publish)
    let articlesStored = 0;
    for (const article of articles) {
      const { error: insertError } = await supabase
        .from("team_news")
        .insert({
          team_id: body.teamId,
          title: article.title,
          summary: article.summary,
          content: article.content,
          category: article.category,
          source_url: article.source_url,
          source_name: article.source_name,
          status: "draft", // Admin must review and publish
          is_ai_curated: true,
          metadata: {
            run_id: runId,
            grounding_sources: groundingSources,
          },
        });

      if (!insertError) {
        articlesStored++;
      } else {
        console.error(
          `[${FUNCTION_NAME}] Failed to store article "${article.title}":`,
          insertError,
        );
      }
    }

    // Update run record
    await supabase
      .from("team_news_ingestion_runs")
      .update({
        status: "completed",
        articles_found: articles.length,
        articles_stored: articlesStored,
        result_summary:
          `Validated ${articles.length} grounded articles, stored ${articlesStored} as draft.`,
        metadata: { grounding_sources: groundingSources },
      })
      .eq("id", runId);

    return jsonResponse(200, {
      success: true,
      requestId,
      run_id: runId,
      articles_found: articles.length,
      articles_stored: articlesStored,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error.";
    console.error(`[${FUNCTION_NAME}] Error:`, message);

    // Update run as failed
    await supabase
      .from("team_news_ingestion_runs")
      .update({
        status: "failed",
        result_summary: message,
      })
      .eq("id", runId);

    return jsonResponse(502, {
      success: false,
      requestId,
      error: message,
    });
  }
});

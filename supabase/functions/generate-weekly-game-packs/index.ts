import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";
import { callGemini, GEMINI_MODELS, parseJSON } from "../_shared/gemini.ts";
import {
  cronAuditResponse,
  finishCronJobRun,
  startCronJobRun,
} from "../_shared/cron_audit.ts";
import {
  buildCorsHeaders,
  getErrorMessage,
  isAuthorizedEdgeRequest,
} from "../_shared/http.ts";

type TemplateId = "fan_trivia" | "song_guess" | "music_bingo";
type MarketCode = "MT" | "RW";

interface GenerateRequest {
  weekStart?: string;
  marketCodes?: MarketCode[];
  targetPackCount?: number;
  questionsPerPack?: number;
  templateIds?: TemplateId[];
  batchSize?: number;
  dryRun?: boolean;
  prompt?: string;
}

interface GeneratedQuestion {
  prompt: string;
  options?: string[];
  answer: string;
  explanation?: string;
  media_hint?: string;
}

interface GeneratedPack {
  template_id: TemplateId;
  market_code: MarketCode;
  title: string;
  questions: GeneratedQuestion[];
}

const allowedTemplates: TemplateId[] = [
  "fan_trivia",
  "song_guess",
  "music_bingo",
];
const allowedMarkets: MarketCode[] = ["MT", "RW"];
const restrictedTerms = [
  "bet",
  "betting",
  "cashout",
  "cash out",
  "gambling",
  "odds",
  "wager",
  "wagering",
];

function getServiceClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ||
      Deno.env.get("EDGE_SERVICE_ROLE_KEY")?.trim() || "",
  );
}

function mondayUtc(date = new Date()) {
  const copy = new Date(Date.UTC(
    date.getUTCFullYear(),
    date.getUTCMonth(),
    date.getUTCDate(),
  ));
  const day = copy.getUTCDay();
  const diff = day === 0 ? -6 : 1 - day;
  copy.setUTCDate(copy.getUTCDate() + diff);
  return copy.toISOString().slice(0, 10);
}

function boundedInt(value: unknown, fallback: number, min: number, max: number) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(min, Math.min(max, Math.floor(parsed)));
}

function normalizeMarkets(value: unknown): MarketCode[] {
  if (!Array.isArray(value)) return allowedMarkets;
  const next = value
    .map((entry) => String(entry).trim().toUpperCase())
    .filter((entry): entry is MarketCode =>
      allowedMarkets.includes(entry as MarketCode)
    );
  return next.length > 0 ? Array.from(new Set(next)) : allowedMarkets;
}

function normalizeTemplates(value: unknown): TemplateId[] {
  if (!Array.isArray(value)) return allowedTemplates;
  const next = value
    .map((entry) => String(entry).trim())
    .filter((entry): entry is TemplateId =>
      allowedTemplates.includes(entry as TemplateId)
    );
  return next.length > 0 ? Array.from(new Set(next)) : allowedTemplates;
}

function hasRestrictedTerms(pack: GeneratedPack) {
  const text = JSON.stringify(pack).toLowerCase();
  return restrictedTerms.filter((term) => text.includes(term));
}

function cleanQuestion(question: unknown): GeneratedQuestion | null {
  if (!question || typeof question !== "object") return null;
  const record = question as Record<string, unknown>;
  const prompt = String(record.prompt ?? "").trim();
  const answer = String(record.answer ?? "").trim();
  const options = Array.isArray(record.options)
    ? record.options.map((option) => String(option).trim()).filter(Boolean)
    : undefined;

  if (prompt.length < 8 || answer.length < 1) return null;
  if (options && (options.length < 2 || options.length > 6)) return null;

  return {
    prompt,
    ...(options ? { options } : {}),
    answer,
    explanation: String(record.explanation ?? "").trim() || undefined,
    media_hint: String(record.media_hint ?? "").trim() || undefined,
  };
}

function cleanPack(value: unknown, questionsPerPack: number): GeneratedPack | null {
  if (!value || typeof value !== "object") return null;
  const record = value as Record<string, unknown>;
  const templateId = String(record.template_id ?? "").trim() as TemplateId;
  const marketCode = String(record.market_code ?? "").trim().toUpperCase() as
    MarketCode;
  const title = String(record.title ?? "").trim();
  const questions = Array.isArray(record.questions)
    ? record.questions.map(cleanQuestion).filter(Boolean) as GeneratedQuestion[]
    : [];

  if (!allowedTemplates.includes(templateId)) return null;
  if (!allowedMarkets.includes(marketCode)) return null;
  if (title.length < 4) return null;
  if (questions.length !== questionsPerPack) return null;

  return {
    template_id: templateId,
    market_code: marketCode,
    title,
    questions,
  };
}

function buildPrompt(
  input: Required<
    Pick<
      GenerateRequest,
      "weekStart" | "targetPackCount" | "questionsPerPack" | "prompt"
    >
  > & { marketCodes: MarketCode[]; templateIds: TemplateId[]; batchSize: number },
  offset: number,
) {
  return `${input.prompt}

Create ${input.batchSize} FANZONE sports-bar game packs for week ${input.weekStart}.
Markets allowed: ${input.marketCodes.join(", ")}. Templates allowed: ${input.templateIds.join(", ")}.
Each pack must have exactly ${input.questionsPerPack} questions.

Return strict JSON only:
{
  "packs": [
    {
      "template_id": "fan_trivia | song_guess | music_bingo",
      "market_code": "MT | RW",
      "title": "short admin title",
      "questions": [
        {
          "prompt": "question text",
          "options": ["A", "B", "C", "D"],
          "answer": "exact correct answer",
          "explanation": "short explanation",
          "media_hint": "optional song/team/context hint"
        }
      ]
    }
  ]
}

Rules:
- Do not include betting, wagering, odds, gambling, cash-out, or real-money language.
- Keep questions safe for a public sports bar TV.
- Mix Malta, Rwanda, football, venue-safe music, and general sports culture.
- Make pack titles unique. Batch offset: ${offset}.`;
}

async function generateBatch(
  input: Required<
    Pick<
      GenerateRequest,
      "weekStart" | "targetPackCount" | "questionsPerPack" | "prompt"
    >
  > & { marketCodes: MarketCode[]; templateIds: TemplateId[]; batchSize: number },
  offset: number,
) {
  const result = await callGemini(GEMINI_MODELS.text, buildPrompt(input, offset), {
    temperature: 0.8,
    maxTokens: 8192,
    responseMimeType: "application/json",
  });
  const parsed = parseJSON(result.text, {});
  const rawPacks = Array.isArray(parsed?.packs) ? parsed.packs : [];
  return rawPacks
    .map((pack: unknown) => cleanPack(pack, input.questionsPerPack))
    .filter(Boolean) as GeneratedPack[];
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: buildCorsHeaders(
        "authorization, apikey, content-type, x-cron-secret",
        req,
      ),
    });
  }

  if (req.method !== "POST") {
    return Response.json({ error: "Method not allowed" }, { status: 405 });
  }

  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ||
    Deno.env.get("EDGE_SERVICE_ROLE_KEY")?.trim() || "";
  const cronSecret = Deno.env.get("CRON_SECRET")?.trim() || "";

  if (
    !isAuthorizedEdgeRequest({
      req,
      serviceRoleKey,
      allowServiceRoleBearer: true,
      sharedSecrets: [{ header: "x-cron-secret", value: cronSecret }],
    })
  ) {
    return Response.json({ error: "Unauthorized" }, {
      status: 401,
      headers: buildCorsHeaders(
        "authorization, apikey, content-type, x-cron-secret",
        req,
      ),
    });
  }

  let auditClient: ReturnType<typeof getServiceClient> | null = null;
  let audit: Awaited<ReturnType<typeof startCronJobRun>> | null = null;

  try {
    const body = await req.json().catch(() => ({})) as GenerateRequest;
    const weekStart = body.weekStart || mondayUtc();
    const marketCodes = normalizeMarkets(body.marketCodes);
    const templateIds = normalizeTemplates(body.templateIds);
    const targetPackCount = boundedInt(body.targetPackCount, 100, 1, 100);
    const questionsPerPack = boundedInt(body.questionsPerPack, 20, 20, 20);
    const batchSize = boundedInt(body.batchSize, 5, 1, 10);
    const prompt = body.prompt?.trim() ||
      "Generate FANZONE weekly sports-bar game content for Malta and Rwanda.";
    const generationInput = {
      weekStart,
      marketCodes,
      templateIds,
      targetPackCount,
      questionsPerPack,
      prompt,
      batchSize,
    };

    if (body.dryRun) {
      return Response.json({
        ok: true,
        dryRun: true,
        generationInput,
      }, {
        headers: buildCorsHeaders(
          "authorization, apikey, content-type, x-cron-secret",
          req,
        ),
      });
    }

    const supabase = getServiceClient();
    auditClient = supabase;
    audit = await startCronJobRun(supabase, "generate-weekly-game-packs", {
      week_start: weekStart,
      market_codes: marketCodes,
      target_pack_count: targetPackCount,
      questions_per_pack: questionsPerPack,
      edge_function: "generate-weekly-game-packs",
    });
    const { data: run, error: runError } = await supabase
      .from("game_content_generation_runs")
      .insert({
        week_start: weekStart,
        market_codes: marketCodes,
        target_pack_count: targetPackCount,
        questions_per_pack: questionsPerPack,
        generation_model: GEMINI_MODELS.text,
        prompt,
        status: "running",
        started_at: new Date().toISOString(),
        metadata: { source: "generate-weekly-game-packs" },
      })
      .select("*")
      .single();

    if (runError) throw new Error(runError.message);

    const accepted: GeneratedPack[] = [];
    const rejected: Array<{ title: string; reasons: string[] }> = [];

    for (let offset = 0; offset < targetPackCount; offset += batchSize) {
      const nextBatchSize = Math.min(batchSize, targetPackCount - offset);
      const packs = await generateBatch(
        { ...generationInput, batchSize: nextBatchSize },
        offset,
      );

      for (const pack of packs) {
        const restricted = hasRestrictedTerms(pack);
        if (restricted.length > 0) {
          rejected.push({ title: pack.title, reasons: restricted });
          continue;
        }
        accepted.push(pack);
      }
    }

    if (accepted.length > 0) {
      const { error: insertError } = await supabase
        .from("game_content_packs")
        .insert(accepted.map((pack) => ({
          generation_run_id: run.id,
          week_start: weekStart,
          template_id: pack.template_id,
          market_code: pack.market_code,
          title: pack.title,
          questions: pack.questions,
          status: "generated_pending_review",
          safety_labels: [],
          metadata: { source: "generate-weekly-game-packs" },
        })));
      if (insertError) throw new Error(insertError.message);
    }

    const status = accepted.length === targetPackCount
      ? "generated"
      : accepted.length > 0
      ? "partially_generated"
      : "failed";
    const { error: updateError } = await supabase
      .from("game_content_generation_runs")
      .update({
        status,
        generated_pack_count: accepted.length,
        error_message: rejected.length > 0
          ? `${rejected.length} generated pack(s) rejected by safety validation`
          : null,
        completed_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        metadata: {
          source: "generate-weekly-game-packs",
          rejected_count: rejected.length,
          rejected_titles: rejected.slice(0, 25).map((entry) => entry.title),
        },
      })
      .eq("id", run.id);
    if (updateError) throw new Error(updateError.message);

    audit = await finishCronJobRun(supabase, audit, "completed", {
      run_id: run.id,
      status,
      generated_pack_count: accepted.length,
      rejected_pack_count: rejected.length,
    });

    return Response.json({
      ok: true,
      runId: run.id,
      status,
      generatedPackCount: accepted.length,
      rejectedPackCount: rejected.length,
      weekStart,
      audit: cronAuditResponse(audit),
    }, {
      headers: buildCorsHeaders(
        "authorization, apikey, content-type, x-cron-secret",
        req,
      ),
    });
  } catch (error) {
    if (auditClient && audit) {
      audit = await finishCronJobRun(
        auditClient,
        audit,
        "failed",
        {},
        getErrorMessage(error),
      );
    }
    return Response.json({
      error: getErrorMessage(error),
      audit: audit ? cronAuditResponse(audit) : undefined,
    }, {
      status: 500,
      headers: buildCorsHeaders(
        "authorization, apikey, content-type, x-cron-secret",
        req,
      ),
    });
  }
});

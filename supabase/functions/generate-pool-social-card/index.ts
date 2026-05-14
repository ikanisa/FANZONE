import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

import { buildCorsHeaders, getErrorMessage } from "../_shared/http.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")?.trim() || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("EDGE_SERVICE_ROLE_KEY")
  ?.trim() || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() || "";
const SOCIAL_CARD_BUCKET = Deno.env.get("POOL_SOCIAL_CARD_BUCKET")?.trim() ||
  "pool-social-cards";
const PUBLIC_SITE_URL = (
  Deno.env.get("PUBLIC_SITE_URL")?.trim() ||
  Deno.env.get("APP_PUBLIC_URL")?.trim() ||
  "https://fanzone.guest.ikanisa.com"
).replace(/\/+$/, "");

interface PoolSocialCardPayload {
  pool_id?: string;
  title?: string;
  scope?: string;
  scope_label?: string | null;
  country_code?: string | null;
  venue_id?: string | null;
  venue_name?: string | null;
  share_slug?: string | null;
  share_url?: string | null;
  deep_link_url?: string | null;
  social_card_url?: string | null;
  social_card?: {
    fingerprint?: string | null;
    object_path?: string | null;
  } | null;
  match?: {
    home_team?: string | null;
    away_team?: string | null;
    competition?: string | null;
    date?: string | null;
    status?: string | null;
    score?: string | null;
  } | null;
  stats?: {
    total_members?: number | null;
    total_staked_fet?: number | null;
  } | null;
}

interface RequestBody {
  pool_id?: string;
  slug?: string;
  force?: boolean;
}

function escapeXml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

function cleanText(value: unknown, fallback: string): string {
  const next = typeof value === "string" ? value.trim() : "";
  return next.length > 0 ? next : fallback;
}

function truncate(value: string, maxLength: number): string {
  if (value.length <= maxLength) return value;
  return `${value.slice(0, Math.max(0, maxLength - 3)).trimEnd()}...`;
}

function formatKickoff(value: string | null | undefined): string {
  if (!value) return "Kickoff TBC";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "Kickoff TBC";
  return new Intl.DateTimeFormat("en", {
    weekday: "short",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    timeZone: "UTC",
    timeZoneName: "short",
  }).format(date);
}

function absoluteShareUrl(payload: PoolSocialCardPayload): string {
  const raw = payload.share_url?.trim() ||
    (payload.share_slug ? `/pools/${payload.share_slug}` : "/pools");
  if (/^https?:\/\//i.test(raw)) return raw;
  return `${PUBLIC_SITE_URL}${raw.startsWith("/") ? raw : `/${raw}`}`;
}

function safePathToken(value: string | null | undefined, fallback: string) {
  const token = (value ?? "").toLowerCase().replace(/[^a-z0-9_-]/g, "");
  return token.length >= 8 ? token.slice(0, 80) : fallback;
}

async function sha256Hex(value: string): Promise<string> {
  const buffer = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(buffer)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function socialCardFingerprint(
  payload: PoolSocialCardPayload,
): Promise<string> {
  const match = payload.match ?? {};
  const stats = payload.stats ?? {};
  const key = {
    version: 2,
    pool: {
      title: payload.title,
      scope: payload.scope,
      country_code: payload.country_code,
      venue_id: payload.venue_id,
      venue_name: payload.venue_name,
      share_slug: payload.share_slug,
    },
    match: {
      home_team: match.home_team,
      away_team: match.away_team,
      competition: match.competition,
      date: match.date,
      status: match.status,
      score: match.score,
    },
    stats: {
      total_members: stats.total_members ?? 0,
      total_staked_fet: stats.total_staked_fet ?? 0,
    },
  };
  return (await sha256Hex(JSON.stringify(key))).slice(0, 20);
}

export function buildPoolSocialCardSvg(
  payload: PoolSocialCardPayload,
): string {
  const match = payload.match ?? {};
  const stats = payload.stats ?? {};
  const title = truncate(cleanText(payload.title, "Match Pool"), 58);
  const home = truncate(cleanText(match.home_team, "Home"), 28);
  const away = truncate(cleanText(match.away_team, "Away"), 28);
  const competition = truncate(cleanText(match.competition, "FANZONE"), 42);
  const kickoff = formatKickoff(match.date);
  const members = Number(stats.total_members ?? 0).toLocaleString("en");
  const staked = Number(stats.total_staked_fet ?? 0).toLocaleString("en");
  const scopeLabel = truncate(cleanText(payload.scope_label, "Global"), 24);
  const venue = truncate(cleanText(payload.venue_name, ""), 34);
  const contextLabel = venue ||
    (payload.scope === "country"
      ? `${cleanText(payload.country_code, "Country")} Pool`
      : `${scopeLabel} Pool`);
  const score = cleanText(match.score, "VS");
  const shortUrl = truncate(
    absoluteShareUrl(payload).replace(/^https?:\/\//i, ""),
    44,
  );

  return `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630" role="img" aria-label="${
    escapeXml(title)
  }">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#07100E"/>
      <stop offset="0.5" stop-color="#10231F"/>
      <stop offset="1" stop-color="#232B2F"/>
    </linearGradient>
    <linearGradient id="accent" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#D6FF3F"/>
      <stop offset="1" stop-color="#39D98A"/>
    </linearGradient>
    <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="18" stdDeviation="18" flood-color="#000000" flood-opacity="0.32"/>
    </filter>
  </defs>
  <rect width="1200" height="630" fill="url(#bg)"/>
  <rect x="50" y="44" width="1100" height="542" rx="30" fill="#0B1117" opacity="0.94" stroke="#263540" stroke-width="2" filter="url(#shadow)"/>
  <rect x="84" y="80" width="178" height="44" rx="22" fill="url(#accent)"/>
  <text x="173" y="109" text-anchor="middle" font-family="Inter, Arial, sans-serif" font-size="18" font-weight="900" fill="#101820">${
    escapeXml(scopeLabel.toUpperCase())
  } POOL</text>
  <text x="1116" y="108" text-anchor="end" font-family="Inter, Arial, sans-serif" font-size="26" font-weight="950" fill="#D6FF3F">FANZONE</text>

  <text x="84" y="180" font-family="Inter, Arial, sans-serif" font-size="34" font-weight="850" fill="#F7FAFC">${
    escapeXml(competition)
  }</text>
  <text x="84" y="230" font-family="Inter, Arial, sans-serif" font-size="28" font-weight="750" fill="#AAB6C1">${
    escapeXml(kickoff)
  }</text>
  <text x="1116" y="230" text-anchor="end" font-family="Inter, Arial, sans-serif" font-size="24" font-weight="850" fill="#39D98A">${
    escapeXml(contextLabel)
  }</text>

  <text x="84" y="326" font-family="Inter, Arial, sans-serif" font-size="58" font-weight="950" fill="#FFFFFF">${
    escapeXml(home)
  }</text>
  <text x="600" y="326" text-anchor="middle" font-family="Inter, Arial, sans-serif" font-size="48" font-weight="950" fill="#D6FF3F">${
    escapeXml(score)
  }</text>
  <text x="1116" y="326" text-anchor="end" font-family="Inter, Arial, sans-serif" font-size="58" font-weight="950" fill="#FFFFFF">${
    escapeXml(away)
  }</text>

  <text x="84" y="400" font-family="Inter, Arial, sans-serif" font-size="30" font-weight="850" fill="#F7FAFC">${
    escapeXml(title)
  }</text>

  <rect x="84" y="452" width="288" height="86" rx="18" fill="#17212B" stroke="#2D3A45"/>
  <text x="114" y="488" font-family="Inter, Arial, sans-serif" font-size="18" font-weight="850" fill="#AAB6C1">MEMBERS</text>
  <text x="114" y="522" font-family="Inter, Arial, sans-serif" font-size="34" font-weight="950" fill="#FFFFFF">${
    escapeXml(members)
  }</text>

  <rect x="404" y="452" width="322" height="86" rx="18" fill="#17212B" stroke="#2D3A45"/>
  <text x="434" y="488" font-family="Inter, Arial, sans-serif" font-size="18" font-weight="850" fill="#AAB6C1">TOTAL STAKED</text>
  <text x="434" y="522" font-family="Inter, Arial, sans-serif" font-size="34" font-weight="950" fill="#FFFFFF">${
    escapeXml(staked)
  } FET</text>

  <rect x="758" y="452" width="358" height="86" rx="18" fill="#D6FF3F"/>
  <text x="937" y="492" text-anchor="middle" font-family="Inter, Arial, sans-serif" font-size="22" font-weight="950" fill="#101820">JOIN THE POOL</text>
  <text x="937" y="522" text-anchor="middle" font-family="Inter, Arial, sans-serif" font-size="15" font-weight="750" fill="#26313A">${
    escapeXml(shortUrl)
  }</text>
</svg>`;
}

async function readJson(req: Request): Promise<RequestBody> {
  try {
    return await req.json();
  } catch {
    return {};
  }
}

function bearerIsServiceRole(req: Request): boolean {
  const authHeader = req.headers.get("authorization")?.trim() || "";
  const bearer = authHeader.replace(/^Bearer\s+/i, "").trim();
  const apiKey = req.headers.get("apikey")?.trim() || "";
  return SUPABASE_SERVICE_ROLE_KEY.length > 0 &&
    (bearer === SUPABASE_SERVICE_ROLE_KEY ||
      apiKey === SUPABASE_SERVICE_ROLE_KEY);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: buildCorsHeaders("authorization, apikey, content-type", req),
    });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const authHeader = req.headers.get("authorization")?.trim();
  if (!authHeader) {
    return Response.json(
      { success: false, error: "Unauthorized" },
      { status: 401, headers: buildCorsHeaders("content-type", req) },
    );
  }

  try {
    const { pool_id: rawPoolId, slug, force = false } = await readJson(req);
    let poolId = rawPoolId?.trim() || "";
    if (poolId && !/^[0-9a-f-]{36}$/i.test(poolId)) {
      return Response.json(
        { success: false, error: "Valid pool_id is required" },
        { status: 400, headers: buildCorsHeaders("content-type", req) },
      );
    }

    if (!poolId && !(slug?.trim())) {
      return Response.json(
        { success: false, error: "pool_id or slug is required" },
        { status: 400, headers: buildCorsHeaders("content-type", req) },
      );
    }

    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const serviceRoleRequest = bearerIsServiceRole(req);
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false },
    });

    let actorUserId: string | null = null;
    if (!serviceRoleRequest) {
      const { data: userResult, error: userError } = await userClient.auth
        .getUser();
      if (userError || !userResult.user) {
        return Response.json(
          { success: false, error: "Unauthorized" },
          { status: 401, headers: buildCorsHeaders("content-type", req) },
        );
      }
      actorUserId = userResult.user.id;
    }

    if (!poolId) {
      const shareClient = serviceRoleRequest ? adminClient : userClient;
      const { data: sharePayload, error: shareError } = await shareClient.rpc(
        "get_public_pool_share",
        {
          p_slug_or_pool_id: slug,
          p_invite_code: null,
          p_source: "social_share",
        },
      );
      if (shareError) throw shareError;
      poolId = String(
        (sharePayload as { pool?: { id?: string } })?.pool?.id ?? "",
      );
    }

    if (!poolId || !/^[0-9a-f-]{36}$/i.test(poolId)) {
      return Response.json(
        { success: false, error: "Pool could not be resolved" },
        { status: 404, headers: buildCorsHeaders("content-type", req) },
      );
    }

    const readClient = serviceRoleRequest ? adminClient : userClient;
    const { data: payload, error: payloadError } = await readClient.rpc(
      "get_match_pool_social_card_payload",
      { p_pool_id: poolId },
    );
    if (payloadError) throw payloadError;

    const cardPayload = payload as PoolSocialCardPayload;
    const fingerprint = await socialCardFingerprint(cardPayload);
    const cachedFingerprint = cardPayload.social_card?.fingerprint ?? null;
    if (
      !force &&
      cardPayload.social_card_url &&
      cachedFingerprint === fingerprint
    ) {
      return Response.json(
        {
          success: true,
          status: "cached",
          pool_id: poolId,
          social_card_url: cardPayload.social_card_url,
          fingerprint,
        },
        { headers: buildCorsHeaders("content-type", req) },
      );
    }

    const svg = buildPoolSocialCardSvg(cardPayload);
    const fallbackToken = fingerprint;
    const pathToken = safePathToken(cardPayload.share_slug, fallbackToken);
    const objectPath = `cards/${pathToken}/pool-${fingerprint}.svg`;
    const { error: uploadError } = await adminClient.storage
      .from(SOCIAL_CARD_BUCKET)
      .upload(objectPath, new Blob([svg], { type: "image/svg+xml" }), {
        contentType: "image/svg+xml",
        cacheControl: "31536000",
        upsert: true,
      });
    if (uploadError) throw uploadError;

    const { data: publicUrlData } = adminClient.storage
      .from(SOCIAL_CARD_BUCKET)
      .getPublicUrl(objectPath);
    const socialCardUrl = publicUrlData.publicUrl;

    const { data: updateResult, error: updateError } = await adminClient.rpc(
      "set_match_pool_social_card_url",
      {
        p_pool_id: poolId,
        p_social_card_url: socialCardUrl,
        p_metadata: {
          generator: "generate-pool-social-card",
          version: 2,
          object_path: objectPath,
          fingerprint,
          share_slug: cardPayload.share_slug ?? null,
          actor_user_id: actorUserId,
          generated_by: serviceRoleRequest ? "service_role" : "authenticated",
          total_members: cardPayload.stats?.total_members ?? 0,
          total_staked_fet: cardPayload.stats?.total_staked_fet ?? 0,
        },
      },
    );

    if (updateError) {
      await adminClient.storage.from(SOCIAL_CARD_BUCKET).remove([objectPath]);
      throw updateError;
    }

    return Response.json(
      {
        success: true,
        status: "generated",
        pool_id: poolId,
        social_card_url: socialCardUrl,
        object_path: objectPath,
        fingerprint,
        update: updateResult,
      },
      { headers: buildCorsHeaders("content-type", req) },
    );
  } catch (error) {
    return Response.json(
      { success: false, error: getErrorMessage(error) },
      { status: 500, headers: buildCorsHeaders("content-type", req) },
    );
  }
});

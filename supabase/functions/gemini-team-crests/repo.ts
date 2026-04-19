import { createClient } from "jsr:@supabase/supabase-js@2";
import { DEFAULT_STORAGE_BUCKET } from "./constants.ts";
import { HttpError, requireEnv } from "./http.ts";
import type {
  ExistingCrestMetadata,
  ImageFetchResult,
  TeamSnapshot,
} from "./types.ts";

type SupabaseAdminClient = any;

function hexEncode(bytes: Uint8Array) {
  return Array.from(bytes).map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function extensionForContentType(
  contentType: string,
  fallbackUrl: string,
): string {
  const normalized = contentType.toLowerCase();

  if (normalized.includes("image/png")) return "png";
  if (normalized.includes("image/jpeg")) return "jpg";
  if (normalized.includes("image/webp")) return "webp";
  if (normalized.includes("image/svg+xml")) return "svg";

  try {
    const pathname = new URL(fallbackUrl).pathname.toLowerCase();
    if (pathname.endsWith(".png")) return "png";
    if (pathname.endsWith(".jpg") || pathname.endsWith(".jpeg")) return "jpg";
    if (pathname.endsWith(".webp")) return "webp";
    if (pathname.endsWith(".svg")) return "svg";
  } catch {
    // Ignore fallback parsing errors and fail closed below.
  }

  throw new HttpError(
    502,
    `Unsupported crest image content type: ${contentType}`,
  );
}

export function getSupabaseAdminClient() {
  return createClient(
    requireEnv("SUPABASE_URL"),
    requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    },
  );
}

export async function loadTeamSnapshot(
  supabase: SupabaseAdminClient,
  teamId: string,
): Promise<TeamSnapshot> {
  const { data, error } = await supabase
    .from("teams")
    .select("id, name, short_name, country, league_name, crest_url, logo_url")
    .eq("id", teamId)
    .maybeSingle();

  if (error) {
    throw new HttpError(500, "Failed to load team metadata.", error);
  }

  if (!data) {
    throw new HttpError(404, `Team ${teamId} was not found.`);
  }

  return data as TeamSnapshot;
}

export async function loadExistingMetadata(
  supabase: SupabaseAdminClient,
  teamId: string,
): Promise<ExistingCrestMetadata | null> {
  const { data, error } = await supabase
    .from("team_crest_metadata")
    .select(`
      team_id,
      image_url,
      remote_image_url,
      storage_path,
      image_sha256,
      source_url,
      source_domain,
      status,
      confidence_score,
      retry_count,
      fetch_count,
      last_attempt_at,
      stale_after,
      next_retry_at
    `)
    .eq("team_id", teamId)
    .maybeSingle();

  if (error) {
    throw new HttpError(500, "Failed to load team crest metadata.", error);
  }

  return (data as ExistingCrestMetadata | null) ?? null;
}

export async function createFetchRun(
  supabase: SupabaseAdminClient,
  teamId: string,
  requestPayload: Record<string, unknown>,
) {
  const { data, error } = await supabase
    .from("team_crest_fetch_runs")
    .insert({
      team_id: teamId,
      request_payload: requestPayload,
      status: "running",
    })
    .select("id")
    .maybeSingle();

  if (error || !data?.id) {
    throw new HttpError(500, "Failed to create team crest fetch run.", error);
  }

  return String(data.id);
}

export async function finalizeFetchRun(
  supabase: SupabaseAdminClient,
  runId: string,
  patch: Record<string, unknown>,
) {
  const { error } = await supabase
    .from("team_crest_fetch_runs")
    .update({
      ...patch,
      finished_at: new Date().toISOString(),
    })
    .eq("id", runId);

  if (error) {
    throw new HttpError(500, "Failed to finalize team crest fetch run.", error);
  }
}

export async function upsertCrestMetadata(
  supabase: SupabaseAdminClient,
  row: Record<string, unknown>,
) {
  const { error } = await supabase
    .from("team_crest_metadata")
    .upsert(row, { onConflict: "team_id" });

  if (error) {
    throw new HttpError(500, "Failed to upsert team crest metadata.", error);
  }
}

export async function downloadImage(
  remoteUrl: string,
): Promise<ImageFetchResult> {
  const response = await fetch(remoteUrl, {
    method: "GET",
    headers: {
      "Accept": "image/*,*/*;q=0.8",
      "User-Agent": "FANZONE crest verifier/1.0",
    },
    redirect: "follow",
    signal: AbortSignal.timeout(25_000),
  });

  if (!response.ok) {
    throw new HttpError(
      502,
      "Crest image download failed.",
      { status: response.status, url: remoteUrl },
    );
  }

  const contentType =
    response.headers.get("content-type")?.split(";")[0]?.trim() || "";
  if (!contentType.startsWith("image/")) {
    throw new HttpError(502, "Resolved crest URL did not return an image.", {
      url: remoteUrl,
      contentType,
    });
  }

  const bytes = new Uint8Array(await response.arrayBuffer());
  const digest = new Uint8Array(
    await crypto.subtle.digest("SHA-256", bytes),
  );

  return {
    final_url: response.url,
    content_type: contentType,
    extension: extensionForContentType(contentType, response.url),
    bytes,
    sha256: hexEncode(digest),
  };
}

export async function uploadImageToStorage(
  supabase: SupabaseAdminClient,
  teamId: string,
  image: ImageFetchResult,
) {
  const bucket = DEFAULT_STORAGE_BUCKET;
  const path = `teams/${teamId}/crest-${image.sha256}.${image.extension}`;

  const { error } = await supabase
    .storage
    .from(bucket)
    .upload(path, image.bytes, {
      cacheControl: "86400",
      contentType: image.content_type,
      upsert: false,
    });

  if (
    error &&
    !String(error.message || "").toLowerCase().includes("already exists")
  ) {
    throw new HttpError(500, "Failed to upload crest image to storage.", error);
  }

  const { data } = supabase.storage.from(bucket).getPublicUrl(path);
  return {
    bucket,
    path,
    publicUrl: data.publicUrl,
  };
}

export async function deleteStoredImage(
  supabase: SupabaseAdminClient,
  path: string | null,
) {
  if (!path) return;

  const { error } = await supabase
    .storage
    .from(DEFAULT_STORAGE_BUCKET)
    .remove([path]);

  if (error) {
    console.warn("[gemini-team-crests] Failed to remove old crest asset", {
      path,
      error,
    });
  }
}

export async function updateTeamCrestUrls(
  supabase: SupabaseAdminClient,
  teamId: string,
  patch: Record<string, unknown>,
) {
  if (Object.keys(patch).length === 0) {
    return;
  }

  const { error } = await supabase
    .from("teams")
    .update(patch)
    .eq("id", teamId);

  if (error) {
    throw new HttpError(500, "Failed to update team crest URLs.", error);
  }
}

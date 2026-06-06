import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

type AnySupabase = SupabaseClient<any, "public", any>;

export interface CronAuditResult {
  run_id: string | null;
  status: "tracked" | "untracked";
  warning?: string;
}

function sanitizeAuditError(error: unknown) {
  const raw = error instanceof Error
    ? error.message
    : typeof error === "string"
    ? error
    : "Unknown scheduler audit error";

  return raw
    .replaceAll(/service[_-]?role/gi, "[redacted-role]")
    .replaceAll(
      /eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}/g,
      "[redacted]",
    )
    .replaceAll(/sbp_[A-Za-z0-9_-]{20,}/g, "[redacted]")
    .replaceAll(/postgresql:\/\/[^:\s]+:[^@\s]+@[^\s]+/g, "[redacted]")
    .slice(0, 300);
}

export async function startCronJobRun(
  supabase: AnySupabase,
  jobName: string,
  metadata: Record<string, unknown> = {},
): Promise<CronAuditResult> {
  try {
    const { data, error } = await supabase.rpc("cron_job_start", {
      p_job_name: jobName,
      p_metadata: metadata,
    });

    if (error) throw error;
    return { run_id: String(data), status: "tracked" };
  } catch (error) {
    return {
      run_id: null,
      status: "untracked",
      warning: sanitizeAuditError(error),
    };
  }
}

export async function finishCronJobRun(
  supabase: AnySupabase,
  audit: CronAuditResult,
  status: "completed" | "failed",
  result: Record<string, unknown> = {},
  errorMessage?: string,
): Promise<CronAuditResult> {
  if (!audit.run_id) return audit;

  try {
    const { error } = await supabase.rpc("cron_job_finish", {
      p_run_id: audit.run_id,
      p_status: status,
      p_result: result,
      p_error_message: errorMessage ?? null,
    });

    if (error) throw error;
    return audit;
  } catch (error) {
    return {
      run_id: audit.run_id,
      status: "untracked",
      warning: sanitizeAuditError(error),
    };
  }
}

export function cronAuditResponse(audit: CronAuditResult) {
  return audit.warning
    ? { run_id: audit.run_id, status: audit.status, warning: audit.warning }
    : { run_id: audit.run_id, status: audit.status };
}

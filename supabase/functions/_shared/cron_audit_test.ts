import {
  cronAuditResponse,
  finishCronJobRun,
  startCronJobRun,
} from "./cron_audit.ts";

function fakeSupabase(
  handler: (
    name: string,
    params: Record<string, unknown>,
  ) => Promise<{ data?: unknown; error?: unknown }>,
) {
  return {
    rpc: handler,
  } as never;
}

Deno.test("startCronJobRun records scheduler run ids", async () => {
  const calls: Array<{ name: string; params: Record<string, unknown> }> = [];
  const supabase = fakeSupabase(async (name, params) => {
    calls.push({ name, params });
    return { data: "run-123" };
  });

  const audit = await startCronJobRun(supabase, "settle-match-pools", {
    limit: 50,
  });

  if (audit.run_id !== "run-123" || audit.status !== "tracked") {
    throw new Error(`Unexpected audit result ${JSON.stringify(audit)}`);
  }
  if (calls[0]?.name !== "cron_job_start") {
    throw new Error("Expected cron_job_start RPC to be called");
  }
  if (calls[0]?.params.p_job_name !== "settle-match-pools") {
    throw new Error("Expected job name to be forwarded");
  }
});

Deno.test("finishCronJobRun records terminal scheduler status", async () => {
  const calls: Array<{ name: string; params: Record<string, unknown> }> = [];
  const supabase = fakeSupabase(async (name, params) => {
    calls.push({ name, params });
    return { data: null };
  });

  const audit = await finishCronJobRun(
    supabase,
    { run_id: "run-456", status: "tracked" },
    "completed",
    { rows: 12 },
  );

  if (audit.run_id !== "run-456" || audit.status !== "tracked") {
    throw new Error(`Unexpected audit result ${JSON.stringify(audit)}`);
  }
  if (calls[0]?.name !== "cron_job_finish") {
    throw new Error("Expected cron_job_finish RPC to be called");
  }
  if (calls[0]?.params.p_status !== "completed") {
    throw new Error("Expected completed status to be forwarded");
  }
});

Deno.test("scheduler audit degrades without blocking cron work", async () => {
  const supabase = fakeSupabase(async () => ({
    error: new Error("database unavailable with service_role detail"),
  }));

  const audit = await startCronJobRun(supabase, "dispatch-match-alerts");
  const response = cronAuditResponse(audit);

  if (audit.run_id !== null || audit.status !== "untracked") {
    throw new Error(`Expected untracked audit result ${JSON.stringify(audit)}`);
  }
  if (!response.warning?.includes("database unavailable")) {
    throw new Error("Expected warning to preserve operational context");
  }
  if (response.warning.includes("service_role detail")) {
    throw new Error("Expected warning to be bounded before response output");
  }
});

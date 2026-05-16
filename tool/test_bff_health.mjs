import { createPrivilegedBffWorker } from "../packages/core/cloudflare/privileged-bff-worker.js";

const configuredEnv = {
  SUPABASE_URL: "https://example.supabase.co",
  SUPABASE_ANON_KEY: "anon-key-for-health-smoke",
};

for (const surface of ["admin", "venue"]) {
  const worker = createPrivilegedBffWorker({ surface });
  const response = await worker.fetch(
    new Request(`https://${surface}.example.com/api/health`),
    configuredEnv,
  );
  const payload = await response.json();

  if (
    response.status !== 200 ||
    payload.ok !== true ||
    payload.bff !== true ||
    payload.surface !== surface ||
    payload.privilegedSessionMode !== "bff"
  ) {
    console.error({ surface, status: response.status, payload });
    process.exit(1);
  }

  const serialized = JSON.stringify(payload);
  if (
    serialized.includes(configuredEnv.SUPABASE_ANON_KEY) ||
    serialized.includes(configuredEnv.SUPABASE_URL)
  ) {
    console.error(`${surface} health payload exposed configured values.`);
    process.exit(1);
  }
}

const unconfiguredWorker = createPrivilegedBffWorker({ surface: "admin" });
const unconfiguredResponse = await unconfiguredWorker.fetch(
  new Request("https://admin.example.com/api/health"),
  {},
);
const unconfiguredPayload = await unconfiguredResponse.json();

if (unconfiguredResponse.status !== 500 || unconfiguredPayload.ok !== false) {
  console.error({
    status: unconfiguredResponse.status,
    payload: unconfiguredPayload,
  });
  process.exit(1);
}

console.log("BFF health smoke passed.");

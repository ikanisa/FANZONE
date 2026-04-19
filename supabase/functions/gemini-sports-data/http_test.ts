import {
  assertAuthorized,
  corsHeaders,
  HttpError,
} from "./http.ts";

Deno.test("corsHeaders are built through the shared helper", () => {
  if (corsHeaders["Access-Control-Allow-Headers"] == null) {
    throw new Error("Expected CORS headers to include allowed headers");
  }

  if (corsHeaders["Access-Control-Allow-Methods"] !== "POST") {
    throw new Error("Expected POST to remain the allowed method");
  }
});

Deno.test("assertAuthorized accepts the configured match sync secret", () => {
  const request = new Request("https://example.com", {
    headers: { "x-match-sync-secret": "sync-secret" },
  });

  assertAuthorized(request, { matchSyncSecret: "sync-secret" });
});

Deno.test("assertAuthorized rejects incorrect secrets", () => {
  const request = new Request("https://example.com", {
    headers: { "x-match-sync-secret": "wrong-secret" },
  });

  try {
    assertAuthorized(request, { matchSyncSecret: "sync-secret" });
    throw new Error("Expected assertAuthorized to reject the request");
  } catch (error) {
    if (!(error instanceof HttpError) || error.status !== 401) {
      throw error;
    }
  }
});

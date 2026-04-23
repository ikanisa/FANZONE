import {
  buildCorsHeaders,
  getErrorMessage,
  isAuthorizedByServiceRole,
  isAuthorizedEdgeRequest,
  readBearerToken,
} from "./http.ts";

Deno.test("readBearerToken extracts bearer tokens", () => {
  const request = new Request("https://example.com", {
    headers: { Authorization: "Bearer service-role-key" },
  });

  if (readBearerToken(request) !== "service-role-key") {
    throw new Error("Expected bearer token to be extracted");
  }
});

Deno.test("buildCorsHeaders preserves explicit origin and header list", () => {
  const headers = buildCorsHeaders(
    "authorization, content-type",
    "https://admin.fanzone.test",
  );

  if (headers["Access-Control-Allow-Origin"] !== "https://admin.fanzone.test") {
    throw new Error("Expected explicit origin to be preserved");
  }

  if (
    headers["Access-Control-Allow-Headers"] !== "authorization, content-type"
  ) {
    throw new Error("Expected allowed headers to be preserved");
  }
});

Deno.test("isAuthorizedByServiceRole accepts service role bearer or shared secret", () => {
  const bearerRequest = new Request("https://example.com", {
    headers: { Authorization: "Bearer service-role-key" },
  });
  const secretRequest = new Request("https://example.com", {
    headers: { "x-cron-secret": "cron-secret" },
  });

  const serviceAuthorized = isAuthorizedByServiceRole({
    req: bearerRequest,
    serviceRoleKey: "service-role-key",
    sharedSecretHeader: "x-cron-secret",
    sharedSecret: "cron-secret",
  });
  const secretAuthorized = isAuthorizedByServiceRole({
    req: secretRequest,
    serviceRoleKey: "service-role-key",
    sharedSecretHeader: "x-cron-secret",
    sharedSecret: "cron-secret",
  });

  if (!serviceAuthorized || !secretAuthorized) {
    throw new Error("Expected either authorization path to succeed");
  }
});

Deno.test("isAuthorizedEdgeRequest only accepts configured shared secrets by default", () => {
  const bearerRequest = new Request("https://example.com", {
    headers: { Authorization: "Bearer service-role-key" },
  });
  const secretRequest = new Request("https://example.com", {
    headers: { "x-push-notify-secret": "push-secret" },
  });

  const bearerAuthorized = isAuthorizedEdgeRequest({
    req: bearerRequest,
    serviceRoleKey: "service-role-key",
    sharedSecrets: [{ header: "x-push-notify-secret", value: "push-secret" }],
  });
  const secretAuthorized = isAuthorizedEdgeRequest({
    req: secretRequest,
    serviceRoleKey: "service-role-key",
    sharedSecrets: [{ header: "x-push-notify-secret", value: "push-secret" }],
  });

  if (bearerAuthorized || !secretAuthorized) {
    throw new Error(
      "Expected shared-secret auth to be accepted and bearer auth to be rejected by default",
    );
  }
});

Deno.test("isAuthorizedEdgeRequest accepts trimmed service role bearer and apikey values when enabled", () => {
  const bearerRequest = new Request("https://example.com", {
    headers: { Authorization: "Bearer service-role-key" },
  });
  const apiKeyRequest = new Request("https://example.com", {
    headers: { apikey: "fallback-service-role-key" },
  });

  const bearerAuthorized = isAuthorizedEdgeRequest({
    req: bearerRequest,
    serviceRoleKey: "  service-role-key  ",
    allowServiceRoleBearer: true,
  });
  const apiKeyAuthorized = isAuthorizedEdgeRequest({
    req: apiKeyRequest,
    serviceRoleKeys: ["fallback-service-role-key"],
    allowServiceRoleBearer: true,
  });

  if (!bearerAuthorized || !apiKeyAuthorized) {
    throw new Error(
      "Expected trimmed service-role bearer and apikey auth to be accepted",
    );
  }
});

Deno.test("isAuthorizedByServiceRole rejects arbitrary bearer tokens", () => {
  const request = new Request("https://example.com", {
    headers: { Authorization: "Bearer definitely-not-service-role" },
  });

  const authorized = isAuthorizedByServiceRole({
    req: request,
    serviceRoleKey: "service-role-key",
    sharedSecretHeader: "x-cron-secret",
    sharedSecret: "cron-secret",
  });

  if (authorized) {
    throw new Error("Expected arbitrary bearer token to be rejected");
  }
});

Deno.test("isAuthorizedByServiceRole rejects missing auth when no shared secret is configured", () => {
  const request = new Request("https://example.com");

  const authorized = isAuthorizedByServiceRole({
    req: request,
    serviceRoleKey: "service-role-key",
    sharedSecretHeader: "x-cron-secret",
    sharedSecret: "",
  });

  if (authorized) {
    throw new Error("Expected request without auth to be rejected");
  }
});

Deno.test("getErrorMessage normalizes unknown errors", () => {
  if (getErrorMessage({ unexpected: true }) !== "Unknown error") {
    throw new Error("Expected unknown values to normalize");
  }
});

import {
  buildCorsHeaders,
  errorResponse,
  handleCors,
  jsonResponse,
} from "./cors.ts";

Deno.test("buildCorsHeaders does not use wildcard CORS by default", () => {
  const headers = buildCorsHeaders();

  if (headers["Access-Control-Allow-Origin"] === "*") {
    throw new Error("Expected default CORS origin to be allowlisted");
  }

  if (headers["Vary"] !== "Origin") {
    throw new Error("Expected CORS responses to vary by Origin");
  }
});

Deno.test("buildCorsHeaders reflects configured allowed request origins", () => {
  Deno.env.set(
    "FANZONE_EDGE_ALLOWED_ORIGINS",
    "https://admin.fanzone.test, https://venue.fanzone.test",
  );
  try {
    const request = new Request("https://edge.fanzone.test", {
      headers: { origin: "https://venue.fanzone.test" },
    });
    const headers = buildCorsHeaders(request);

    if (
      headers["Access-Control-Allow-Origin"] !== "https://venue.fanzone.test"
    ) {
      throw new Error("Expected configured request origin to be reflected");
    }
  } finally {
    Deno.env.delete("FANZONE_EDGE_ALLOWED_ORIGINS");
  }
});

Deno.test("handleCors rejects disallowed browser preflight origins", async () => {
  Deno.env.set("FANZONE_EDGE_ALLOWED_ORIGINS", "https://admin.fanzone.test");
  try {
    const request = new Request("https://edge.fanzone.test", {
      method: "OPTIONS",
      headers: { origin: "https://evil.example" },
    });
    const response = handleCors(request);

    if (!response) {
      throw new Error("Expected preflight response");
    }
    if (response.status !== 403) {
      throw new Error("Expected disallowed preflight to be rejected");
    }
    if (response.headers.has("Access-Control-Allow-Origin")) {
      throw new Error("Expected no CORS origin for rejected preflight");
    }
    await response.text();
  } finally {
    Deno.env.delete("FANZONE_EDGE_ALLOWED_ORIGINS");
  }
});

Deno.test("jsonResponse applies request-scoped CORS headers", () => {
  Deno.env.set("FANZONE_EDGE_ALLOWED_ORIGINS", "https://admin.fanzone.test");
  try {
    const request = new Request("https://edge.fanzone.test", {
      headers: { origin: "https://admin.fanzone.test" },
    });
    const response = jsonResponse({ ok: true }, 200, request);

    if (
      response.headers.get("Access-Control-Allow-Origin") !==
        "https://admin.fanzone.test"
    ) {
      throw new Error("Expected JSON response to include scoped CORS origin");
    }
  } finally {
    Deno.env.delete("FANZONE_EDGE_ALLOWED_ORIGINS");
  }
});

Deno.test("errorResponse includes validation details for client errors", async () => {
  const response = errorResponse("Invalid request data", 400, [{
    path: "venue_id",
  }]);
  const body = await response.json();

  if (!Array.isArray(body.details)) {
    throw new Error("Expected 4xx validation details to be returned");
  }
});

Deno.test("errorResponse suppresses internal details for server errors by default", async () => {
  const response = errorResponse(
    "Internal server error",
    500,
    "database stack trace",
  );
  const body = await response.json();

  if ("details" in body) {
    throw new Error("Expected 5xx details to be hidden by default");
  }
});

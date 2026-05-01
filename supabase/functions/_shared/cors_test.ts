import { errorResponse } from "./cors.ts";

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

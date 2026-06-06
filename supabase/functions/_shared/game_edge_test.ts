import { assertGameActionSupported, serveGameEdge } from "./game_edge.ts";

Deno.test("serveGameEdge rejects unsupported methods before auth", async () => {
  const response = await serveGameEdge(
    new Request("https://example.test/fan-trivia", { method: "GET" }),
    "fan_trivia",
  );

  if (response.status !== 405) {
    throw new Error(`Expected 405 for GET, got ${response.status}`);
  }
});

Deno.test("serveGameEdge handles allowed CORS preflight before auth", async () => {
  const response = await serveGameEdge(
    new Request("https://example.test/music-bingo", {
      method: "OPTIONS",
      headers: { origin: "https://fanzone.ikanisa.com" },
    }),
    "music_bingo",
  );

  if (response.status !== 200) {
    throw new Error(`Expected 200 for OPTIONS, got ${response.status}`);
  }
});

Deno.test("serveGameEdge rejects unknown CORS origins before auth", async () => {
  const response = await serveGameEdge(
    new Request("https://example.test/song-guess", {
      method: "OPTIONS",
      headers: { origin: "https://malicious.example.test" },
    }),
    "song_guess",
  );

  if (response.status !== 403) {
    throw new Error(
      `Expected 403 for blocked CORS origin, got ${response.status}`,
    );
  }
});

Deno.test("assertGameActionSupported allows shared team/session actions", () => {
  for (
    const action of [
      "list_sessions",
      "create_session",
      "create_team",
      "join_team",
      "start_session",
    ]
  ) {
    assertGameActionSupported(action, "fan_trivia");
    assertGameActionSupported(action, "song_guess");
    assertGameActionSupported(action, "music_bingo");
  }
});

Deno.test("assertGameActionSupported routes trivia actions away from music bingo", () => {
  assertGameActionSupported("current_question", "fan_trivia");
  assertGameActionSupported("submit_answer", "song_guess");

  try {
    assertGameActionSupported("submit_answer", "music_bingo");
  } catch (error) {
    if (
      !(error instanceof Error) ||
      !error.message.includes("does not accept trivia answers")
    ) {
      throw new Error(`Unexpected Music Bingo trivia guard: ${error}`);
    }
    return;
  }
  throw new Error("Expected Music Bingo submit_answer to be rejected");
});

Deno.test("assertGameActionSupported limits card and claim actions to music bingo", () => {
  assertGameActionSupported("get_or_create_card", "music_bingo");
  assertGameActionSupported("mark_tile", "music_bingo");
  assertGameActionSupported("submit_claim", "music_bingo");

  try {
    assertGameActionSupported("mark_tile", "fan_trivia");
  } catch (error) {
    if (
      !(error instanceof Error) ||
      !error.message.includes("Cards are only available for Music Bingo")
    ) {
      throw new Error(`Unexpected Fan Trivia card guard: ${error}`);
    }
    return;
  }
  throw new Error("Expected Fan Trivia mark_tile to be rejected");
});

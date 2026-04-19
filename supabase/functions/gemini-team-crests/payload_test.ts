import { HttpError } from "./http.ts";
import { parseRequestPayload } from "./payload.ts";

Deno.test("parseRequestPayload accepts a single top-level team", () => {
  const payload = parseRequestPayload({
    team_id: "arsenal",
    team_name: "Arsenal FC",
    competition: "Premier League",
    country: "England",
    aliases: ["Arsenal", "The Gunners"],
  });

  if (payload.teams.length !== 1) {
    throw new Error("Expected a single team payload");
  }

  if (payload.teams[0].team_id !== "arsenal") {
    throw new Error("Expected team id to be preserved");
  }
});

Deno.test("parseRequestPayload dedupes repeated teams by team_id", () => {
  const payload = parseRequestPayload({
    teams: [
      { team_id: "arsenal", team_name: "Arsenal FC" },
      { team_id: "arsenal", team_name: "Arsenal Football Club" },
    ],
  });

  if (payload.teams.length !== 1) {
    throw new Error("Expected duplicate teams to be deduped");
  }
});

Deno.test("parseRequestPayload rejects empty requests", () => {
  try {
    parseRequestPayload({});
    throw new Error("Expected empty payload to throw");
  } catch (error) {
    if (!(error instanceof HttpError) || error.status !== 400) {
      throw error;
    }
  }
});

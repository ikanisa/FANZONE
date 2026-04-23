import {
  buildResultDispatchKey,
  type MatchRow,
  singleMatch,
  uniqueUserIds,
} from "./dispatch.ts";

Deno.test("singleMatch unwraps arrays and preserves direct rows", () => {
  const match: MatchRow = {
    id: "match-1",
    date: "2026-04-20T12:00:00.000Z",
    status: "upcoming",
    home_team: "Liverpool",
    away_team: "Arsenal",
  };

  if (singleMatch(match)?.id != "match-1") {
    throw new Error("Expected direct match row to be returned");
  }

  if (singleMatch([match])?.id != "match-1") {
    throw new Error("Expected wrapped match row to be unwrapped");
  }

  if (singleMatch([]) !== null || singleMatch(null) !== null) {
    throw new Error("Expected null for empty/null match relations");
  }
});

Deno.test("uniqueUserIds preserves order while deduplicating", () => {
  const result = uniqueUserIds(["user-1", "user-2", "user-1", "user-3"]);

  if (result.join(",") !== "user-1,user-2,user-3") {
    throw new Error(`Unexpected dedupe result: ${result.join(",")}`);
  }
});

Deno.test("buildResultDispatchKey stays stable for final score dedupe", () => {
  const key = buildResultDispatchKey({ ft_home: 2, ft_away: 1 });

  if (key !== "result:2-1") {
    throw new Error(`Unexpected result dispatch key: ${key}`);
  }
});

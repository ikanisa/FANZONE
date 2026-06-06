import { errorResponse, handleCors, jsonResponse, requireAuth } from "./mod.ts";

type GameKind = "fan_trivia" | "song_guess" | "music_bingo";

interface GameRequest {
  action?: string;
  venue_id?: string;
  session_id?: string;
  team_id?: string;
  card_id?: string;
  question_id?: string;
  name?: string;
  answer?: string;
  tile_key?: string;
  marked?: boolean;
  scheduled_start_at?: string;
  reward_fet?: number;
  ordinal?: number;
  metadata?: Record<string, unknown>;
}

const gameTemplateId: Record<GameKind, string> = {
  fan_trivia: "fan_trivia",
  song_guess: "song_guess",
  music_bingo: "music_bingo",
};

const readableGame: Record<GameKind, string> = {
  fan_trivia: "Fan Trivia",
  song_guess: "Song Guess",
  music_bingo: "Music Bingo",
};

const commonActions = new Set([
  "list_sessions",
  "create_session",
  "create_team",
  "join_team",
  "start_session",
]);

const questionActions = new Set(["current_question", "submit_answer"]);
const musicBingoActions = new Set([
  "get_or_create_card",
  "mark_tile",
  "submit_claim",
]);

export function assertGameActionSupported(action: string, game: GameKind) {
  if (commonActions.has(action)) return;
  if (questionActions.has(action) && game !== "music_bingo") return;
  if (musicBingoActions.has(action) && game === "music_bingo") return;

  if (questionActions.has(action)) {
    throw new Error(
      action === "current_question"
        ? `${readableGame[game]} has no trivia question`
        : `${readableGame[game]} does not accept trivia answers`,
    );
  }
  if (musicBingoActions.has(action)) {
    throw new Error(`Cards are only available for Music Bingo`);
  }
  throw new Error(`Unsupported action: ${action}`);
}

function requireString(value: unknown, field: string) {
  if (typeof value !== "string" || value.trim() === "") {
    throw new Error(`${field} is required`);
  }
  return value.trim();
}

function asReward(value: unknown) {
  return typeof value === "number" && Number.isFinite(value)
    ? Math.max(0, Math.trunc(value))
    : 0;
}

async function sessionTemplate(
  supabaseUser: any,
  sessionId: string,
) {
  const { data, error } = await supabaseUser
    .from("game_sessions")
    .select("id, template_id, status, current_question_ordinal")
    .eq("id", sessionId)
    .single();
  if (error || !data) throw new Error("Game session not found");
  return data as {
    id: string;
    template_id: string;
    status: string;
    current_question_ordinal?: number | null;
  };
}

async function assertSessionGame(
  supabaseUser: any,
  sessionId: string,
  game: GameKind,
) {
  const session = await sessionTemplate(supabaseUser, sessionId);
  if (session.template_id !== gameTemplateId[game]) {
    throw new Error(`${readableGame[game]} cannot operate on this session`);
  }
  return session;
}

async function assertTeamGame(
  supabaseUser: any,
  teamId: string,
  game: GameKind,
) {
  const { data, error } = await supabaseUser
    .from("game_teams")
    .select("id, session_id, game_sessions!inner(template_id)")
    .eq("id", teamId)
    .single();
  if (error || !data) throw new Error("Game team not found");
  const templateId = (data as any).game_sessions?.template_id;
  if (templateId !== gameTemplateId[game]) {
    throw new Error(`${readableGame[game]} cannot operate on this team`);
  }
  return data as { id: string; session_id: string };
}

async function assertCardGame(
  supabaseUser: any,
  cardId: string,
  game: GameKind,
) {
  const { data, error } = await supabaseUser
    .from("music_bingo_cards")
    .select("id, session_id")
    .eq("id", cardId)
    .single();
  if (error || !data) throw new Error("Music Bingo card not found");
  await assertSessionGame(supabaseUser, (data as any).session_id, game);
  return data as { id: string; session_id: string };
}

async function rpc(
  supabaseUser: any,
  fn: string,
  params: Record<string, unknown>,
) {
  const { data, error } = await supabaseUser.rpc(fn, params);
  if (error) throw new Error(error.message);
  return data;
}

export async function serveGameEdge(req: Request, game: GameKind) {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405, undefined, req);
  }

  const authResult = await requireAuth(req);
  if (authResult instanceof Response) return authResult;
  const { supabaseUser } = authResult;

  try {
    const body = await req.json() as GameRequest;
    const action = requireString(body.action, "action");
    assertGameActionSupported(action, game);

    if (action === "list_sessions") {
      const { data, error } = await supabaseUser
        .from("game_sessions")
        .select("*, game_templates!inner(id, name, category), venues(id, name)")
        .eq("template_id", gameTemplateId[game])
        .in("status", ["scheduled", "lobby", "live"])
        .order("scheduled_start_at", { ascending: true })
        .limit(50);
      if (error) throw new Error(error.message);
      return jsonResponse({ success: true, game, action, data }, 200, req);
    }

    if (action === "create_session") {
      const data = await rpc(supabaseUser, "create_game_session", {
        p_venue_id: requireString(body.venue_id, "venue_id"),
        p_template_id: gameTemplateId[game],
        p_scheduled_start_at: requireString(
          body.scheduled_start_at,
          "scheduled_start_at",
        ),
        p_reward_fet: asReward(body.reward_fet),
      });
      return jsonResponse({ success: true, game, action, data }, 200, req);
    }

    if (action === "create_team") {
      const sessionId = requireString(body.session_id, "session_id");
      await assertSessionGame(supabaseUser, sessionId, game);
      const data = await rpc(supabaseUser, "create_game_team", {
        p_session_id: sessionId,
        p_name: requireString(body.name, "name"),
      });
      return jsonResponse({ success: true, game, action, data }, 200, req);
    }

    if (action === "join_team") {
      const teamId = requireString(body.team_id, "team_id");
      await assertTeamGame(supabaseUser, teamId, game);
      const data = await rpc(supabaseUser, "join_game_team", {
        p_team_id: teamId,
      });
      return jsonResponse({ success: true, game, action, data }, 200, req);
    }

    if (action === "start_session") {
      const sessionId = requireString(body.session_id, "session_id");
      await assertSessionGame(supabaseUser, sessionId, game);
      const data = await rpc(supabaseUser, "start_game_session", {
        p_session_id: sessionId,
      });
      return jsonResponse({ success: true, game, action, data }, 200, req);
    }

    if (action === "current_question") {
      if (game === "music_bingo") {
        throw new Error("Music Bingo has no trivia question");
      }
      const sessionId = requireString(body.session_id, "session_id");
      const session = await assertSessionGame(supabaseUser, sessionId, game);
      const data = await rpc(supabaseUser, "get_game_session_question", {
        p_session_id: sessionId,
        p_ordinal: body.ordinal ?? session.current_question_ordinal ?? 1,
      });
      return jsonResponse({ success: true, game, action, data }, 200, req);
    }

    if (action === "submit_answer") {
      const sessionId = requireString(body.session_id, "session_id");
      await assertSessionGame(supabaseUser, sessionId, game);
      const data = await rpc(supabaseUser, "submit_game_answer", {
        p_session_id: sessionId,
        p_question_id: requireString(body.question_id, "question_id"),
        p_team_id: requireString(body.team_id, "team_id"),
        p_answer: requireString(body.answer, "answer"),
      });
      return jsonResponse({ success: true, game, action, data }, 200, req);
    }

    if (action === "get_or_create_card") {
      const sessionId = requireString(body.session_id, "session_id");
      await assertSessionGame(supabaseUser, sessionId, game);
      const data = await rpc(supabaseUser, "get_or_create_music_bingo_card", {
        p_session_id: sessionId,
        p_team_id: requireString(body.team_id, "team_id"),
      });
      return jsonResponse({ success: true, game, action, data }, 200, req);
    }

    if (action === "mark_tile") {
      const cardId = requireString(body.card_id, "card_id");
      await assertCardGame(supabaseUser, cardId, game);
      const data = await rpc(supabaseUser, "mark_music_bingo_tile", {
        p_card_id: cardId,
        p_tile_key: requireString(body.tile_key, "tile_key"),
        p_marked: body.marked ?? true,
      });
      return jsonResponse({ success: true, game, action, data }, 200, req);
    }

    if (action === "submit_claim") {
      const cardId = requireString(body.card_id, "card_id");
      await assertCardGame(supabaseUser, cardId, game);
      const data = await rpc(supabaseUser, "submit_music_bingo_claim", {
        p_card_id: cardId,
        p_metadata: body.metadata ?? {},
      });
      return jsonResponse({ success: true, game, action, data }, 200, req);
    }

    return errorResponse(`Unsupported action: ${action}`, 400, undefined, req);
  } catch (error) {
    const message = error instanceof Error
      ? error.message
      : "Game request failed";
    return errorResponse(message, 400, undefined, req);
  }
}

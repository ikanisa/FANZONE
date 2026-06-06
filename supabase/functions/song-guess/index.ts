import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { serveGameEdge } from "../_shared/game_edge.ts";

Deno.serve((req) => serveGameEdge(req, "song_guess"));

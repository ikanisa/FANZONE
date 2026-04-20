/**
 * gemini-team-discovery — Gemini + Google Search Grounding
 * for discovering all first-division football teams across
 * 100+ countries (Europe, Africa, Americas).
 *
 * POST / → Run discovery for a region or specific countries.
 * GET  / → Export all active teams as JSON (for bundled fallback).
 */
import { handleTeamDiscoveryRequest, handleExportRequest } from "./handler.ts";

Deno.serve(async (req) => {
  if (req.method === "GET") {
    return handleExportRequest(req);
  }
  return handleTeamDiscoveryRequest(req);
});

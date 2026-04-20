import {
  handleExportRequest,
  handleTeamDiscoveryRequest,
} from "../gemini-team-discovery/handler.ts";

Deno.serve((req) => {
  if (req.method === "GET") {
    return handleExportRequest(req);
  }
  return handleTeamDiscoveryRequest(req);
});

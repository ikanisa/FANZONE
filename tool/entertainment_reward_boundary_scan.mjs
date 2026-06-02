#!/usr/bin/env node
import { readFileSync } from "node:fs";

const checks = [
  {
    file: "supabase/tests/release_readiness_hardening.sql",
    required: [
      "game_answers_first_correct_once_idx",
      "game_answers_team_question_idx",
      "game_session_questions_session_ordinal_idx",
      "already_settled",
      "idempotency_key",
      "user_has_qualifying_order",
      "won_ineligible_no_qualifying_order",
      "game_winner_settlement",
      "game_reward_unpaid_return",
      "ineligible_winners",
      "unique_violation",
      "User is not a member of this team",
      "sports_bar_write_audit",
      "provider_api_used",
      "Authenticated users must not execute raw settle_match_pool",
      "Anonymous users must not settle game sessions",
    ],
  },
  {
    file: "supabase/functions/settle-match-pools/index.ts",
    required: [
      'req.method !== "POST"',
      "isAuthorizedEdgeRequest",
      "allowServiceRoleBearer: true",
      'header: "x-cron-secret"',
      "settle_finished_match_pools",
      "Math.max(1, Math.min(250",
    ],
    forbidden: [
      {
        pattern: /\.from\(["']match_pool_settlements["']\)\s*\.\s*(insert|update|delete|upsert)/s,
        message:
          "settle-match-pools Edge Function must delegate settlement to RPCs",
      },
      {
        pattern: /\.from\(["']fet_wallet_transactions["']\)\s*\.\s*(insert|update|delete|upsert)/s,
        message:
          "settle-match-pools Edge Function must not mutate FET ledger rows directly",
      },
    ],
  },
  {
    file: "apps/venue-portal/src/services/venueOperations.ts",
    required: [
      'supabase.rpc("create_game_session"',
      'supabase.rpc("update_game_session_lifecycle"',
      'supabase.rpc("verify_music_bingo_claim"',
      'supabase.rpc("venue_settle_game_session"',
      'supabase.rpc("venue_close_match_pool"',
      'supabase.rpc("venue_settle_match_pool"',
      'supabase.rpc("set_venue_screen_state"',
    ],
    forbidden: [
      {
        pattern: /\.from\(["']match_pool_settlements["']\)\s*\.\s*(insert|update|delete|upsert)/s,
        message:
          "venue portal must not directly mutate match_pool_settlements",
      },
      {
        pattern: /\.from\(["']game_sessions["']\)\s*\.\s*(insert|update|delete|upsert)/s,
        message: "venue portal must mutate game sessions through RPCs",
      },
      {
        pattern: /\.from\(["']game_answers["']\)\s*\.\s*(insert|update|delete|upsert)/s,
        message: "venue portal must not directly mutate game answers",
      },
      {
        pattern: /\.from\(["']venue_fet_wallet_transactions["']\)\s*\.\s*(insert|update|delete|upsert)/s,
        message: "venue portal must not directly mutate venue FET ledger rows",
      },
    ],
  },
  {
    file: "apps/admin/src/features/pool-operations/usePoolOperations.ts",
    required: [
      'fnName: "admin_run_pool_settlement"',
      'fnName: "admin_cancel_refund_pool"',
      'fnName: "admin_retry_pool_settlement"',
      '"generate-pool-social-card"',
    ],
    forbidden: [
      {
        pattern: /\.from\(["']match_pool_settlements["']\)\s*\.\s*(insert|update|delete|upsert)/s,
        message: "admin pool operations must use settlement RPCs",
      },
      {
        pattern: /\.from\(["']fet_wallet_transactions["']\)\s*\.\s*(insert|update|delete|upsert)/s,
        message: "admin pool operations must not directly mutate FET ledger rows",
      },
    ],
  },
  {
    file: "apps/admin/src/features/match-curation/MatchCurationPage.tsx",
    required: [
      "Post this final score? This can trigger automatic pool settlement.",
    ],
  },
];

const failures = [];

for (const check of checks) {
  const source = readFileSync(check.file, "utf8");
  for (const required of check.required ?? []) {
    if (!source.includes(required)) {
      failures.push(`${check.file}: missing ${required}`);
    }
  }
  for (const forbidden of check.forbidden ?? []) {
    if (forbidden.pattern.test(source)) {
      failures.push(`${check.file}: ${forbidden.message}`);
    }
  }
}

console.log("FANZONE entertainment/reward boundary scan");

if (failures.length > 0) {
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log("Entertainment/reward boundary scan passed.");

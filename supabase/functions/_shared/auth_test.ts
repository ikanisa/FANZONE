import { checkRateLimit } from "./auth.ts";

Deno.test("checkRateLimit calls the current SQL contract", async () => {
  let rpcName = "";
  let rpcArgs: Record<string, unknown> = {};

  const supabaseAdmin = {
    rpc(name: string, args: Record<string, unknown>) {
      rpcName = name;
      rpcArgs = args;
      return Promise.resolve({ data: true, error: null });
    },
  };

  const result = await checkRateLimit(
    supabaseAdmin as any,
    "00000000-0000-0000-0000-000000000001",
    {
      endpoint: "join_pool",
      maxRequests: 5,
      window: "1 hour",
    },
  );

  if (result !== true) {
    throw new Error("Expected allowed rate-limit result");
  }

  if (rpcName !== "check_rate_limit") {
    throw new Error(`Expected check_rate_limit RPC, got ${rpcName}`);
  }

  const expected = {
    p_user_id: "00000000-0000-0000-0000-000000000001",
    p_action: "join_pool",
    p_max_count: 5,
    p_window: "1 hour",
  };

  if (JSON.stringify(rpcArgs) !== JSON.stringify(expected)) {
    throw new Error(
      `Unexpected rate-limit RPC arguments: ${JSON.stringify(rpcArgs)}`,
    );
  }
});

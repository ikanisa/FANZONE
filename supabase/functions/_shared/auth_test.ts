import { checkRateLimit, requireAdminRole } from "./auth.ts";

const testUserId = "00000000-0000-0000-0000-000000000001";

function createAdminRoleClient(record: { id: string; role: string } | null) {
  return {
    from(table: string) {
      if (table !== "admin_users") {
        throw new Error(`Unexpected table: ${table}`);
      }

      const query = {
        select(_columns: string) {
          return query;
        },
        eq(_column: string, _value: unknown) {
          return query;
        },
        single() {
          return Promise.resolve({ data: record, error: null });
        },
      };

      return query;
    },
  };
}

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
    testUserId,
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
    p_user_id: testUserId,
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

Deno.test("requireAdminRole allows an admin with the required role", async () => {
  const result = await requireAdminRole(
    createAdminRoleClient({ id: "admin-record-id", role: "admin" }) as any,
    testUserId,
    "admin",
  );

  if (result instanceof Response) {
    throw new Error(`Expected admin access, got status ${result.status}`);
  }

  if (result.role !== "admin") {
    throw new Error(`Expected admin role, got ${result.role}`);
  }
});

Deno.test("requireAdminRole allows a higher role", async () => {
  const result = await requireAdminRole(
    createAdminRoleClient({
      id: "admin-record-id",
      role: "super_admin",
    }) as any,
    testUserId,
    "admin",
  );

  if (result instanceof Response) {
    throw new Error(`Expected super admin access, got status ${result.status}`);
  }

  if (result.role !== "super_admin") {
    throw new Error(`Expected super_admin role, got ${result.role}`);
  }
});

Deno.test("requireAdminRole rejects a lower role", async () => {
  const result = await requireAdminRole(
    createAdminRoleClient({ id: "admin-record-id", role: "moderator" }) as any,
    testUserId,
    "admin",
  );

  if (!(result instanceof Response)) {
    throw new Error("Expected lower admin role to be rejected");
  }

  if (result.status !== 403) {
    throw new Error(`Expected 403, got ${result.status}`);
  }
});

Deno.test("requireAdminRole rejects unsupported admin roles", async () => {
  const result = await requireAdminRole(
    createAdminRoleClient({ id: "admin-record-id", role: "owner" }) as any,
    testUserId,
    "admin",
  );

  if (!(result instanceof Response)) {
    throw new Error("Expected unsupported role to be rejected");
  }

  if (result.status !== 403) {
    throw new Error(`Expected 403, got ${result.status}`);
  }
});

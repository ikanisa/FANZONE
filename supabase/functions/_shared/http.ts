import { resolveEdgeCorsOrigin } from "./cors_allowlist.ts";

interface SharedSecretOption {
  header: string;
  value?: string;
}

interface EdgeAuthorizationOptions {
  req: Request;
  serviceRoleKey?: string;
  serviceRoleKeys?: string[];
  allowServiceRoleBearer?: boolean;
  sharedSecrets?: SharedSecretOption[];
}

interface AuthorizationOptions {
  req: Request;
  serviceRoleKey: string;
  sharedSecretHeader: string;
  sharedSecret?: string;
  allowServiceRoleBearer?: boolean;
}

export function buildCorsHeaders(
  allowedHeaders: string,
  requestOrOrigin?: Request | string | null,
) {
  const allowedOrigin = requestOrOrigin instanceof Request
    ? resolveEdgeCorsOrigin(requestOrOrigin.headers.get("origin"))
    : typeof requestOrOrigin === "string"
    ? requestOrOrigin
    : resolveEdgeCorsOrigin();
  const headers: Record<string, string> = {
    "Access-Control-Allow-Methods": "POST",
    "Access-Control-Allow-Headers": allowedHeaders,
    "Vary": "Origin",
  };

  if (allowedOrigin) {
    headers["Access-Control-Allow-Origin"] = allowedOrigin;
  }

  return headers;
}

export function readBearerToken(req: Request): string | null {
  const authHeader = req.headers.get("authorization")?.trim();
  if (!authHeader) return null;

  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}

function readApiKey(req: Request): string | null {
  return req.headers.get("apikey")?.trim() || null;
}

export function isAuthorizedEdgeRequest({
  req,
  serviceRoleKey,
  serviceRoleKeys = [],
  allowServiceRoleBearer = false,
  sharedSecrets = [],
}: EdgeAuthorizationOptions): boolean {
  const bearerToken = readBearerToken(req);
  const apiKey = readApiKey(req);
  const allowedServiceRoleKeys = [serviceRoleKey, ...serviceRoleKeys]
    .map((value) => value?.trim() || "")
    .filter((value) => value.length > 0);

  if (
    allowServiceRoleBearer &&
    allowedServiceRoleKeys.some((value) =>
      value === bearerToken || value === apiKey
    )
  ) {
    return true;
  }

  for (const sharedSecret of sharedSecrets) {
    const secretValue = sharedSecret.value?.trim();
    if (!secretValue) continue;

    const headerSecret = req.headers.get(sharedSecret.header)?.trim() || "";
    if (headerSecret === secretValue) {
      return true;
    }
  }

  return false;
}

export function isAuthorizedByServiceRole({
  req,
  serviceRoleKey,
  sharedSecretHeader,
  sharedSecret,
  allowServiceRoleBearer = true,
}: AuthorizationOptions): boolean {
  return isAuthorizedEdgeRequest({
    req,
    serviceRoleKey,
    allowServiceRoleBearer,
    sharedSecrets: [{ header: sharedSecretHeader, value: sharedSecret }],
  });
}

export function getErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  return typeof error === "string" ? error : "Unknown error";
}

/**
 * Standardized Response Helpers
 */

export const responses = {
  ok: (data: any = { success: true }) =>
    Response.json(data, {
      headers: buildCorsHeaders("content-type"),
      status: 200,
    }),

  badRequest: (message: string) =>
    Response.json({ error: message }, {
      headers: buildCorsHeaders("content-type"),
      status: 400,
    }),

  unauthorized: () =>
    Response.json({ error: "Unauthorized" }, {
      headers: buildCorsHeaders("content-type"),
      status: 401,
    }),

  error: (err: unknown) =>
    Response.json({ error: getErrorMessage(err) }, {
      headers: buildCorsHeaders("content-type"),
      status: 500,
    }),
};

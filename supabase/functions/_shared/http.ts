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
  allowedOrigin = readOptionalEnv("ALLOWED_ORIGIN") || "*",
) {
  return {
    "Access-Control-Allow-Origin": allowedOrigin,
    "Access-Control-Allow-Methods": "POST",
    "Access-Control-Allow-Headers": allowedHeaders,
  };
}

function readOptionalEnv(name: string): string | undefined {
  try {
    return Deno.env.get(name)?.trim() || undefined;
  } catch {
    return undefined;
  }
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

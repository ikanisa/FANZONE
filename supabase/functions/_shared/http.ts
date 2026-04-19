interface AuthorizationOptions {
  req: Request;
  serviceRoleKey: string;
  sharedSecretHeader: string;
  sharedSecret?: string;
}

export function buildCorsHeaders(
  allowedHeaders: string,
  allowedOrigin = Deno.env.get('ALLOWED_ORIGIN')?.trim() || '*',
) {
  return {
    'Access-Control-Allow-Origin': allowedOrigin,
    'Access-Control-Allow-Methods': 'POST',
    'Access-Control-Allow-Headers': allowedHeaders,
  };
}

export function readBearerToken(req: Request): string | null {
  const authHeader = req.headers.get('authorization')?.trim();
  if (!authHeader) return null;

  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}

export function isAuthorizedByServiceRole({
  req,
  serviceRoleKey,
  sharedSecretHeader,
  sharedSecret,
}: AuthorizationOptions): boolean {
  const bearerToken = readBearerToken(req);
  if (bearerToken === serviceRoleKey) return true;

  if (!sharedSecret?.trim()) return false;

  const headerSecret = req.headers.get(sharedSecretHeader)?.trim() || '';
  return headerSecret === sharedSecret.trim();
}

export function getErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  return typeof error === 'string' ? error : 'Unknown error';
}

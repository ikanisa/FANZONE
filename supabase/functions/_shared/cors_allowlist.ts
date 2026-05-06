const DEFAULT_EDGE_ALLOWED_ORIGINS = [
  "https://fanzone.ikanisa.com",
  "https://fanzone-website.pages.dev",
  "https://fanzone-admin.pages.dev",
  "https://fanzone-venue-portal.pages.dev",
  "https://fanzone-tv-display.pages.dev",
  "http://localhost:4173",
  "http://localhost:4174",
  "http://localhost:4175",
  "http://localhost:4176",
  "http://localhost:5173",
  "http://localhost:5174",
  "http://localhost:5175",
  "http://localhost:5176",
];

const EDGE_ALLOWED_ORIGINS_ENV = "FANZONE_EDGE_ALLOWED_ORIGINS";
const LEGACY_ALLOWED_ORIGIN_ENV = "ALLOWED_ORIGIN";
const ALLOW_WILDCARD_ENV = "FANZONE_EDGE_ALLOW_WILDCARD_CORS";

declare const Deno: {
  env: {
    get(key: string): string | undefined;
  };
};

function readOptionalEnv(name: string): string | undefined {
  try {
    return Deno.env.get(name)?.trim() || undefined;
  } catch {
    return undefined;
  }
}

export function normalizeCorsOrigin(value: string | null | undefined): string {
  const trimmed = value?.trim() || "";
  if (!trimmed || trimmed === "null") return "";
  if (trimmed === "*") return trimmed;

  try {
    return new URL(trimmed).origin;
  } catch {
    return trimmed.replace(/\/+$/, "");
  }
}

export function readEdgeAllowedOrigins(): string[] {
  const configured = readOptionalEnv(EDGE_ALLOWED_ORIGINS_ENV) ??
    readOptionalEnv(LEGACY_ALLOWED_ORIGIN_ENV);

  const origins =
    (configured ? configured.split(",") : DEFAULT_EDGE_ALLOWED_ORIGINS)
      .map(normalizeCorsOrigin)
      .filter((origin) => origin.length > 0);

  if (origins.includes("*")) {
    return readOptionalEnv(ALLOW_WILDCARD_ENV) === "true"
      ? ["*"]
      : origins.filter((origin) => origin !== "*");
  }

  return origins;
}

export function resolveEdgeCorsOrigin(
  requestOrigin?: string | null,
): string | null {
  const allowedOrigins = readEdgeAllowedOrigins();
  if (allowedOrigins.includes("*")) return "*";

  const normalizedRequestOrigin = normalizeCorsOrigin(requestOrigin);
  if (normalizedRequestOrigin) {
    return allowedOrigins.includes(normalizedRequestOrigin)
      ? normalizedRequestOrigin
      : null;
  }

  return allowedOrigins[0] ?? null;
}

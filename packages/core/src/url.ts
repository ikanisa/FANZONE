const defaultAllowedProtocols = ["https:", "http:"] as const;
const controlCharacterPattern = /[\u0000-\u001F\u007F]/;

export interface SafeUrlOptions {
  allowedProtocols?: readonly string[];
  allowRelative?: boolean;
}

function normalizedProtocolSet(protocols: readonly string[]) {
  return new Set(
    protocols.map((protocol) =>
      protocol.endsWith(":")
        ? protocol.toLowerCase()
        : `${protocol.toLowerCase()}:`,
    ),
  );
}

export function safeUrl(value: unknown, options: SafeUrlOptions = {}) {
  if (typeof value !== "string") return null;

  const trimmed = value.trim();
  if (!trimmed || controlCharacterPattern.test(trimmed)) return null;

  if (
    options.allowRelative === true &&
    trimmed.startsWith("/") &&
    !trimmed.startsWith("//")
  ) {
    return trimmed;
  }

  const allowedProtocols = normalizedProtocolSet(
    options.allowedProtocols ?? defaultAllowedProtocols,
  );

  try {
    const parsed = new URL(trimmed);
    return allowedProtocols.has(parsed.protocol.toLowerCase())
      ? parsed.href
      : null;
  } catch {
    return null;
  }
}

export function safeHref(value: unknown, options?: SafeUrlOptions) {
  return safeUrl(value, options);
}

export function safeImageUrl(value: unknown, options?: SafeUrlOptions) {
  return safeUrl(value, options);
}

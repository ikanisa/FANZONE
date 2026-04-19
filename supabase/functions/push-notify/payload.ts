export interface PushPayload {
  userIds: string[];
  type: string;
  title: string;
  body: string;
  data: Record<string, string>;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function requireString(value: unknown, fieldName: string): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new Error(`Missing or invalid ${fieldName}`);
  }

  return value.trim();
}

function normalizeUserIds(input: Record<string, unknown>): string[] {
  const userIds = new Set<string>();

  if (typeof input.user_id === 'string' && input.user_id.trim()) {
    userIds.add(input.user_id.trim());
  }

  if (Array.isArray(input.user_ids)) {
    for (const candidate of input.user_ids) {
      if (typeof candidate === 'string' && candidate.trim()) {
        userIds.add(candidate.trim());
      }
    }
  }

  const normalized = [...userIds];
  if (normalized.length === 0) {
    throw new Error('Missing user_id(s)');
  }

  return normalized;
}

function normalizeData(value: unknown): Record<string, string> {
  if (value === undefined || value === null) {
    return {};
  }

  if (!isRecord(value)) {
    throw new Error('Invalid data payload');
  }

  return Object.fromEntries(
    Object.entries(value)
      .filter(([, entryValue]) => entryValue !== undefined && entryValue !== null)
      .map(([key, entryValue]) => [key, String(entryValue)]),
  );
}

export function parsePushPayload(input: unknown): PushPayload {
  if (!isRecord(input)) {
    throw new Error('Invalid push payload');
  }

  return {
    userIds: normalizeUserIds(input),
    type: requireString(input.type, 'type'),
    title: requireString(input.title, 'title'),
    body: requireString(input.body, 'body'),
    data: normalizeData(input.data),
  };
}

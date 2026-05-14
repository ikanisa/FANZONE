import type { Json, Venue } from "@fanzone/core";
import type { VenueScreenMode, VenueScreenState } from "../services/tvData";

const publicAppBaseUrl = (
  import.meta.env.VITE_PUBLIC_APP_URL || "https://fanzone.guest.ikanisa.com"
).replace(/\/$/, "");

export function buildJoinUrl(
  venue: Venue | null,
  state: VenueScreenState | null,
) {
  if (state?.activePoolId) {
    return `${publicAppBaseUrl}/pool/${state.activePoolId}/join`;
  }

  if (state?.activeGameSessionId && venue) {
    return `${publicAppBaseUrl}/v/${venue.slug}?game=${state.activeGameSessionId}`;
  }

  if (venue) return `${publicAppBaseUrl}/v/${venue.slug}`;
  return publicAppBaseUrl;
}

export function parseOptions(options: Json | null): string[] {
  if (Array.isArray(options)) {
    return options.map((option) => String(option)).filter(Boolean);
  }

  if (options && typeof options === "object") {
    const record = options as Record<string, Json | undefined>;
    const values = record.options;
    if (Array.isArray(values)) {
      return values.map((option) => String(option)).filter(Boolean);
    }
    return Object.values(record)
      .filter((value): value is string => typeof value === "string")
      .slice(0, 6);
  }

  return [];
}

export function formatCurrency(amount: number, currency: string) {
  return new Intl.NumberFormat(undefined, {
    style: "currency",
    currency,
    maximumFractionDigits: currency === "RWF" ? 0 : 2,
  }).format(amount);
}

export function formatTime(value: Date) {
  return new Intl.DateTimeFormat(undefined, {
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  }).format(value);
}

export function readable(value: string) {
  return value.replace(/_/g, " ");
}

export function readableMode(mode: VenueScreenMode) {
  return readable(mode).replace(/^game /, "game: ");
}

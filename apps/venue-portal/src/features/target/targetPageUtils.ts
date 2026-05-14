import { type DependencyList, useEffect, useState } from "react";
import type { VenueScreenMode } from "../../services/venueOperations";

export const eligibilityRule =
  "To receive FET winnings, the user must place at least one order from this bar within 2 hours before the linked game/pool start time.";

export type Action = {
  label: string;
  to?: string;
  disabled?: boolean;
};

export type Metric = {
  label: string;
  value: string;
  detail?: string;
};

export type AsyncState<T> = {
  data: T;
  loading: boolean;
  error: string | null;
  refresh: () => void;
};

export const screenModes: Array<{ label: string; mode: VenueScreenMode }> = [
  { label: "Venue welcome", mode: "welcome" },
  { label: "QR join screen", mode: "qr" },
  { label: "Active prediction pool", mode: "pool" },
  { label: "Active game lobby", mode: "game_lobby" },
  { label: "Game question", mode: "game_question" },
  { label: "Game leaderboard", mode: "leaderboard" },
  { label: "Winner celebration", mode: "winners" },
  { label: "Menu / promotions", mode: "menu" },
  { label: "Order promo / FET reminder", mode: "promo" },
];

const tvDisplayBaseUrl = (
  import.meta.env.VITE_TV_DISPLAY_URL || "https://fanzonetv.ikanisa.com"
).replace(/\/$/, "");

export function tvDisplayUrl(venueId: string) {
  return `${tvDisplayBaseUrl}/venue/${venueId}`;
}

export function useAsyncData<T>(
  loader: () => Promise<T>,
  deps: DependencyList,
  fallback: T,
): AsyncState<T> {
  const [data, setData] = useState<T>(fallback);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [refreshToken, setRefreshToken] = useState(0);

  useEffect(() => {
    let mounted = true;
    queueMicrotask(() => {
      if (!mounted) return;
      setLoading(true);
      setError(null);

      loader()
        .then((value) => {
          if (mounted) setData(value);
        })
        .catch((err) => {
          if (mounted) {
            setError(
              err instanceof Error ? err.message : "Failed to load data.",
            );
          }
        })
        .finally(() => {
          if (mounted) setLoading(false);
        });
    });

    return () => {
      mounted = false;
    };
    // The callers pass explicit stable dependency keys. Including loader would
    // refire every render because it is created inline at the call site.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, refreshToken]);

  return {
    data,
    loading,
    error,
    refresh: () => setRefreshToken((value) => value + 1),
  };
}

export function formatDate(value: string | null | undefined) {
  if (!value) return "Not scheduled";
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}

export function shortId(value: string | null | undefined) {
  return value ? value.replace(/-/g, "").slice(0, 8).toUpperCase() : "NONE";
}

export function userCode(value: string | null | undefined) {
  return value ? value.replace(/-/g, "").slice(-6).toUpperCase() : "000000";
}

export function nowLocalInputValue() {
  const date = new Date(Date.now() + 15 * 60 * 1000);
  date.setSeconds(0, 0);
  return new Date(date.getTime() - date.getTimezoneOffset() * 60000)
    .toISOString()
    .slice(0, 16);
}

import {
  CONFIRMED_CONFIDENCE_THRESHOLD,
  LOW_CONFIDENCE_THRESHOLD,
} from "./constants.ts";
import { normalizeText, toDatabaseMatchStatus } from "./match.ts";
import type {
  GroundingSummary,
  MatchEventsPayload,
  TrustedMatchSource,
  ValidationResult,
} from "./types.ts";

function clamp(value: number, min = 0, max = 0.99) {
  return Math.max(min, Math.min(max, value));
}

function hostFromUrl(value: string | null | undefined): string | null {
  if (!value) return null;
  try {
    return new URL(value).host.toLowerCase();
  } catch {
    return null;
  }
}

function matchesDomainPattern(host: string, pattern: string) {
  const normalizedPattern = pattern.toLowerCase().replace(/^\*\./, "");
  return host === normalizedPattern || host.endsWith(`.${normalizedPattern}`);
}

export function enrichGroundingSummary(
  grounding: GroundingSummary,
  trustedSources: TrustedMatchSource[],
): GroundingSummary {
  const enriched = grounding.sources.map((source) => {
    const host = source.domain ?? hostFromUrl(source.uri);
    const matched = host
      ? trustedSources.find((candidate) =>
        candidate.active && matchesDomainPattern(host, candidate.domain_pattern)
      )
      : undefined;

    return {
      ...source,
      domain: host,
      source_type: matched?.source_type ?? source.source_type,
      trust_score: matched?.trust_score ?? source.trust_score,
      trusted: matched != null || source.trusted,
    };
  });

  return {
    ...grounding,
    sources: enriched,
  };
}

export function evaluateMatchUpdateConfidence(
  payload: MatchEventsPayload,
  grounding: GroundingSummary,
): ValidationResult {
  const flags: string[] = [];
  let score = 0.35;

  const officialSources =
    grounding.sources.filter((source) =>
      source.source_type === "official_match_centre" ||
      source.source_type === "official_federation" ||
      source.source_type === "official_competition"
    ).length;
  const trustedSources = grounding.sources.filter((source) => source.trusted)
    .length;

  if (grounding.sources.length === 0) {
    flags.push("no_grounding_sources");
    score -= 0.25;
  } else if (grounding.sources.length === 1) {
    score += 0.08;
  } else if (grounding.sources.length === 2) {
    score += 0.18;
  } else {
    score += 0.24;
  }

  if (officialSources >= 1) {
    score += 0.24;
  } else if (trustedSources >= 2) {
    score += 0.18;
    flags.push("trusted_reference_fallback");
  } else if (trustedSources === 1) {
    score += 0.08;
    flags.push("single_trusted_source");
  } else {
    score -= 0.18;
    flags.push("no_trusted_sources");
  }

  if (payload.match_status !== "UNKNOWN") {
    score += 0.05;
  } else {
    flags.push("unknown_match_status");
  }

  if (payload.match_status === "LIVE" && payload.minute == null) {
    score -= 0.08;
    flags.push("missing_live_minute");
  }

  if (payload.events.length > 0) {
    score += 0.05;
  }

  if (payload.uncertainty_notes.length > 0) {
    score -= Math.min(payload.uncertainty_notes.length * 0.04, 0.16);
    flags.push("model_reported_uncertainty");
  }

  const normalizedStatus = toDatabaseMatchStatus(payload.match_status);
  if (
    normalizedStatus === "live" &&
    payload.home_score === 0 &&
    payload.away_score === 0 &&
    payload.events.length === 0 &&
    payload.minute != null &&
    payload.minute >= 30
  ) {
    flags.push("no_live_events_confirmed");
  }

  if (normalizeText(payload.summary).length > 0) {
    score += 0.02;
  }

  const confidenceScore = clamp(Number(score.toFixed(4)));

  if (confidenceScore >= CONFIRMED_CONFIDENCE_THRESHOLD) {
    return {
      confidence_score: confidenceScore,
      status: "confirmed",
      flags: Array.from(new Set(flags)),
      review_reason: null,
      official_sources: officialSources,
      trusted_sources: trustedSources,
    };
  }

  if (confidenceScore >= LOW_CONFIDENCE_THRESHOLD) {
    return {
      confidence_score: confidenceScore,
      status: "low_confidence",
      flags: Array.from(new Set(flags)),
      review_reason: payload.uncertainty_notes[0] ??
        "Grounded sources were present but not strong enough for automatic publication.",
      official_sources: officialSources,
      trusted_sources: trustedSources,
    };
  }

  return {
    confidence_score: confidenceScore,
    status: "manual_review",
    flags: Array.from(new Set(flags)),
    review_reason: payload.uncertainty_notes[0] ??
      "Grounded evidence was too weak or too inconsistent for automatic publication.",
    official_sources: officialSources,
    trusted_sources: trustedSources,
  };
}

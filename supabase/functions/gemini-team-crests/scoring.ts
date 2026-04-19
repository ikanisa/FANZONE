import {
  FEDERATION_REFRESH_HOURS,
  INITIAL_FAILURE_RETRY_HOURS,
  LOW_CONFIDENCE_RETRY_HOURS,
  MAX_FAILURE_RETRY_HOURS,
  OFFICIAL_REFRESH_HOURS,
  REFERENCE_REFRESH_HOURS,
} from "./constants.ts";
import type {
  GeminiCrestCandidate,
  GroundingSummary,
  ImageFetchResult,
  TeamCrestInput,
  ValidationResult,
} from "./types.ts";

const TRUSTED_REFERENCE_DOMAINS = [
  "transfermarkt.com",
  "transfermarkt.co.uk",
  "soccerway.com",
  "worldfootball.net",
  "besoccer.com",
  "espn.com",
  "flashscore.com",
  "fotmob.com",
  "goal.com",
  "wikipedia.org",
];

const SUSPICIOUS_TERMS = [
  "fan",
  "forum",
  "shop",
  "store",
  "ticket",
  "kit",
  "merch",
  "sponsor",
  "fantasy",
];

function clamp(value: number, min = 0, max = 0.99) {
  return Math.max(min, Math.min(max, value));
}

export function normalizeText(value: string | null | undefined): string {
  return (value ?? "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\b(fc|cf|sc|afc|club|football|deportivo|atletico)\b/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function tokenize(value: string | null | undefined): string[] {
  return normalizeText(value)
    .split(" ")
    .filter((token) => token.length >= 3);
}

function tokenOverlapScore(
  left: string | null | undefined,
  right: string | null | undefined,
) {
  const leftTokens = new Set(tokenize(left));
  const rightTokens = new Set(tokenize(right));
  if (leftTokens.size === 0 || rightTokens.size === 0) return 0;

  let overlap = 0;
  for (const token of leftTokens) {
    if (rightTokens.has(token)) {
      overlap += 1;
    }
  }

  return overlap / Math.max(leftTokens.size, rightTokens.size);
}

function hostFromUrl(value: string | null | undefined): string | null {
  if (!value) return null;
  try {
    return new URL(value).host.toLowerCase();
  } catch {
    return null;
  }
}

function hasTrustedReferenceDomain(host: string | null): boolean {
  if (!host) return false;
  return TRUSTED_REFERENCE_DOMAINS.some((domain) =>
    host === domain || host.endsWith(`.${domain}`)
  );
}

function containsSuspiciousTerm(value: string | null | undefined): boolean {
  const normalized = normalizeText(value);
  return SUSPICIOUS_TERMS.some((term) => normalized.includes(term));
}

function groundedUrlCount(
  summary: GroundingSummary,
  candidate: GeminiCrestCandidate,
) {
  const grounded = new Set(
    summary.grounded_urls.map((url) => url.toLowerCase()),
  );
  let matches = 0;

  for (const value of [candidate.source_url, candidate.image_url]) {
    const normalized = value.toLowerCase();
    if (grounded.has(normalized)) {
      matches += 1;
      continue;
    }

    const host = hostFromUrl(normalized);
    if (
      host &&
      Array.from(grounded).some((url) => hostFromUrl(url) === host)
    ) {
      matches += 1;
    }
  }

  return matches;
}

function baseScoreForSourceType(
  sourceType: GeminiCrestCandidate["source_type"],
) {
  switch (sourceType) {
    case "official_club":
      return 0.9;
    case "official_federation":
      return 0.86;
    case "official_competition":
      return 0.83;
    case "trusted_reference":
      return 0.72;
    default:
      return 0.45;
  }
}

export function evaluateCandidate(
  input: TeamCrestInput,
  candidate: GeminiCrestCandidate,
  grounding: GroundingSummary,
  image: ImageFetchResult,
): ValidationResult {
  const flags: string[] = [];
  let score = baseScoreForSourceType(candidate.source_type);

  const nameScore = Math.max(
    tokenOverlapScore(input.team_name, candidate.matched_name),
    ...input.aliases.map((alias) =>
      tokenOverlapScore(alias, candidate.matched_name)
    ),
    candidate.matched_alias
      ? tokenOverlapScore(candidate.matched_alias, input.team_name)
      : 0,
  );

  if (nameScore >= 0.8) {
    score += 0.06;
  } else if (nameScore >= 0.5) {
    score += 0.03;
    flags.push("partial_name_match");
  } else {
    score -= 0.18;
    flags.push("weak_name_match");
  }

  if (candidate.competition_match) {
    score += 0.03;
  } else if (input.competition) {
    flags.push("competition_not_confirmed");
    score -= 0.03;
  }

  if (candidate.country_match) {
    score += 0.02;
  } else if (input.country) {
    flags.push("country_not_confirmed");
    score -= 0.02;
  }

  if (candidate.official_signal) {
    score += 0.03;
  } else if (candidate.source_type.startsWith("official")) {
    flags.push("official_signal_missing");
  }

  const groundedMatches = groundedUrlCount(grounding, candidate);
  if (groundedMatches >= 2) {
    score += 0.05;
  } else if (groundedMatches === 1) {
    score += 0.02;
    flags.push("partial_grounding_match");
  } else {
    score -= 0.25;
    flags.push("source_not_grounded");
  }

  const sourceHost = hostFromUrl(candidate.source_url) ??
    candidate.source_domain;
  if (candidate.source_type === "trusted_reference") {
    if (hasTrustedReferenceDomain(sourceHost)) {
      score += 0.03;
      flags.push("trusted_reference_fallback");
    } else {
      score -= 0.12;
      flags.push("untrusted_reference_domain");
    }
  }

  if (
    containsSuspiciousTerm(candidate.source_url) ||
    containsSuspiciousTerm(sourceHost)
  ) {
    score -= 0.12;
    flags.push("suspicious_source_terms");
  }

  if (image.bytes.byteLength < 1024) {
    score -= 0.2;
    flags.push("image_too_small");
  } else if (image.bytes.byteLength < 4096) {
    score -= 0.08;
    flags.push("small_image_asset");
  } else {
    score += 0.02;
  }

  if (image.content_type === "image/svg+xml") {
    score += 0.02;
  }

  const confidenceScore = clamp(Number(score.toFixed(4)));
  const hardFailure = flags.some((flag) =>
    [
      "source_not_grounded",
      "untrusted_reference_domain",
      "image_too_small",
    ].includes(flag)
  );

  let status: ValidationResult["status"];
  if (hardFailure && confidenceScore < 0.65) {
    status = "failed";
  } else if (confidenceScore >= 0.85) {
    status = "fetched";
  } else if (confidenceScore >= 0.65) {
    status = "low_confidence";
  } else {
    status = "manual_review";
  }

  return {
    confidence_score: confidenceScore,
    status,
    flags: Array.from(new Set(flags)),
    notes: candidate.validation_notes,
  };
}

export function getRefreshHours(
  sourceType: GeminiCrestCandidate["source_type"],
) {
  switch (sourceType) {
    case "official_club":
      return OFFICIAL_REFRESH_HOURS;
    case "official_federation":
    case "official_competition":
      return FEDERATION_REFRESH_HOURS;
    case "trusted_reference":
      return REFERENCE_REFRESH_HOURS;
    default:
      return LOW_CONFIDENCE_RETRY_HOURS;
  }
}

export function getNextRetryHours(
  status: ValidationResult["status"],
  retryCount: number,
) {
  if (status === "failed") {
    return Math.min(
      INITIAL_FAILURE_RETRY_HOURS * Math.pow(2, Math.max(retryCount, 0)),
      MAX_FAILURE_RETRY_HOURS,
    );
  }

  if (status === "low_confidence" || status === "manual_review") {
    return LOW_CONFIDENCE_RETRY_HOURS;
  }

  return null;
}

export function shouldApplyToTeam(
  currentTeamImageUrl: string | null,
  previousAutomatedImageUrl: string | null,
  status: ValidationResult["status"],
  forceApply: boolean,
) {
  if (status !== "fetched") {
    return false;
  }

  if (forceApply) {
    return true;
  }

  if (!currentTeamImageUrl) {
    return true;
  }

  return previousAutomatedImageUrl != null &&
    currentTeamImageUrl === previousAutomatedImageUrl;
}

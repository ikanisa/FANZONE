import {
  evaluateCandidate,
  getNextRetryHours,
  normalizeText,
  shouldApplyToTeam,
} from "./scoring.ts";
import type {
  GroundingSummary,
  ImageFetchResult,
  TeamCrestInput,
} from "./types.ts";

const input: TeamCrestInput = {
  team_id: "arsenal",
  team_name: "Arsenal FC",
  competition: "Premier League",
  country: "England",
  aliases: ["Arsenal", "The Gunners"],
};

const grounding: GroundingSummary = {
  sources: [
    { uri: "https://www.arsenal.com/", title: "Arsenal official site" },
  ],
  grounded_urls: [
    "https://www.arsenal.com/",
    "https://www.arsenal.com/themes/custom/arsenal/logo.svg",
  ],
};

const image: ImageFetchResult = {
  final_url: "https://www.arsenal.com/themes/custom/arsenal/logo.svg",
  content_type: "image/svg+xml",
  extension: "svg",
  bytes: new Uint8Array(8_192),
  sha256: "abc123",
};

Deno.test("normalizeText removes club boilerplate and punctuation", () => {
  const normalized = normalizeText("Arsenal Football Club!");
  if (normalized !== "arsenal") {
    throw new Error(`Unexpected normalized text: ${normalized}`);
  }
});

Deno.test("evaluateCandidate scores official grounded crests highly", () => {
  const result = evaluateCandidate(
    input,
    {
      source_url: "https://www.arsenal.com/",
      image_url: "https://www.arsenal.com/themes/custom/arsenal/logo.svg",
      source_name: "Arsenal",
      source_domain: "www.arsenal.com",
      source_type: "official_club",
      matched_name: "Arsenal FC",
      matched_alias: "Arsenal",
      official_signal: "Official Arsenal club domain",
      match_reason:
        "The page is the club home page and exposes the crest asset.",
      competition_match: true,
      country_match: true,
      validation_notes: null,
    },
    grounding,
    image,
  );

  if (result.status !== "fetched") {
    throw new Error(`Expected fetched status, got ${result.status}`);
  }

  if (result.confidence_score < 0.85) {
    throw new Error("Expected an official grounded crest to score highly");
  }
});

Deno.test("evaluateCandidate penalizes weak trusted-reference matches", () => {
  const result = evaluateCandidate(
    input,
    {
      source_url: "https://example.com/random-logo",
      image_url: "https://example.com/random-logo.png",
      source_name: "Unknown",
      source_domain: "example.com",
      source_type: "trusted_reference",
      matched_name: "Arsenal Women",
      matched_alias: null,
      official_signal: null,
      match_reason: "Unclear result",
      competition_match: false,
      country_match: true,
      validation_notes: "Fallback source used",
    },
    { sources: [], grounded_urls: [] },
    {
      ...image,
      final_url: "https://example.com/random-logo.png",
      content_type: "image/png",
      extension: "png",
      bytes: new Uint8Array(900),
    },
  );

  if (result.status === "fetched") {
    throw new Error(
      "Expected suspicious fallback candidate to avoid fetched status",
    );
  }
});

Deno.test("getNextRetryHours backs off failed attempts", () => {
  const first = getNextRetryHours("failed", 0);
  const second = getNextRetryHours("failed", 1);

  if (first == null || second == null || second <= first) {
    throw new Error("Expected retry hours to increase after repeated failures");
  }
});

Deno.test("shouldApplyToTeam only overwrites automated values unless forced", () => {
  if (!shouldApplyToTeam(null, null, "fetched", false)) {
    throw new Error("Expected empty team crest to be fillable");
  }

  if (
    shouldApplyToTeam("https://manual.example/logo.png", null, "fetched", false)
  ) {
    throw new Error("Expected manual crest URL to be preserved");
  }

  if (
    !shouldApplyToTeam(
      "https://auto.example/logo.png",
      "https://auto.example/logo.png",
      "fetched",
      false,
    )
  ) {
    throw new Error("Expected previous automated crest URL to be replaceable");
  }
});

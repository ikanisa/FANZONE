/**
 * Gemini Vision response schema for extracting betting odds from screenshots.
 * Uses structured output to ensure consistent, parseable JSON.
 */

const Type = {
  OBJECT: "OBJECT",
  INTEGER: "INTEGER",
  STRING: "STRING",
  ARRAY: "ARRAY",
  NUMBER: "NUMBER",
} as const;

const fixtureOddsItemSchema = {
  type: Type.OBJECT,
  description: "A single fixture with 1X2 decimal odds extracted from the screenshot.",
  properties: {
    home_team: {
      type: Type.STRING,
      description:
        "Home team name exactly as it appears on the screenshot. Do not translate or normalize.",
    },
    away_team: {
      type: Type.STRING,
      description:
        "Away team name exactly as it appears on the screenshot. Do not translate or normalize.",
    },
    competition: {
      type: Type.STRING,
      description:
        "Competition or league name if visible in a section header above the fixture. Null if not visible.",
    },
    kickoff_text: {
      type: Type.STRING,
      description:
        "Kickoff time or date as shown on the screenshot, raw text. Null if not visible.",
    },
    home_odds: {
      type: Type.NUMBER,
      description: "Decimal odds for home win (1). Must be > 1.0.",
    },
    draw_odds: {
      type: Type.NUMBER,
      description: "Decimal odds for draw (X). Must be > 1.0.",
    },
    away_odds: {
      type: Type.NUMBER,
      description: "Decimal odds for away win (2). Must be > 1.0.",
    },
    confidence: {
      type: Type.NUMBER,
      description:
        "Your confidence that these odds are correctly read (0.0 to 1.0). Lower if text is blurry, partially obscured, or ambiguous.",
    },
  },
  required: [
    "home_team",
    "away_team",
    "home_odds",
    "draw_odds",
    "away_odds",
    "confidence",
  ],
};

export const screenshotOddsSchema = {
  type: Type.OBJECT,
  description:
    "All 1X2 decimal betting odds visible in the screenshot, organized by fixture.",
  properties: {
    detected_site: {
      type: Type.STRING,
      description:
        "The betting site detected from the screenshot (e.g. 'bet365', 'betway', '1xbet', 'unknown').",
    },
    total_fixtures_found: {
      type: Type.INTEGER,
      description: "Total number of football fixtures with visible 1X2 odds in the screenshot.",
    },
    fixtures: {
      type: Type.ARRAY,
      description: "List of all fixtures with their extracted 1X2 decimal odds.",
      items: fixtureOddsItemSchema,
    },
    extraction_notes: {
      type: Type.ARRAY,
      description:
        "Notes about extraction quality: partially visible odds, blurry text, cut-off fixtures, non-football content, etc.",
      items: { type: Type.STRING },
    },
  },
  required: [
    "detected_site",
    "total_fixtures_found",
    "fixtures",
    "extraction_notes",
  ],
};

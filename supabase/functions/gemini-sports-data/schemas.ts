import { type Schema, Type } from "npm:@google/genai";

import { EVENT_TYPES, MATCH_PHASES, MATCH_STATES } from "./constants.ts";

const eventItemSchema: Schema = {
  type: Type.OBJECT,
  properties: {
    minute: {
      type: Type.INTEGER,
      description:
        "Minute the event happened. Convert stoppage time to a single integer.",
    },
    event_type: {
      type: Type.STRING,
      enum: [...EVENT_TYPES],
      description: "Supported event type.",
    },
    team: {
      type: Type.STRING,
      description: "Team associated with the event.",
    },
    player: {
      type: Type.STRING,
      description: "Primary player associated with the event.",
    },
    assist_player: {
      type: Type.STRING,
      description: "Assist player when reliably available.",
    },
    details: {
      type: Type.STRING,
      description:
        "Extra context such as scoreline, booking reason, VAR outcome, or substitution in/out.",
    },
  },
  required: ["minute", "event_type", "team", "player", "details"],
};

export const eventsSchema: Schema = {
  type: Type.OBJECT,
  description:
    "Current match state plus the chronological list of confirmed live football match events.",
  properties: {
    match_status: {
      type: Type.STRING,
      enum: [...MATCH_STATES],
      description: "Current match status.",
    },
    phase: {
      type: Type.STRING,
      enum: [...MATCH_PHASES],
      description: "Most specific confirmed phase of play.",
    },
    minute: {
      type: Type.INTEGER,
      description:
        "Current confirmed match minute. Omit if there is no reliable minute yet.",
    },
    home_score: {
      type: Type.INTEGER,
      description: "Current or final score for the home team.",
    },
    away_score: {
      type: Type.INTEGER,
      description: "Current or final score for the away team.",
    },
    events: {
      type: Type.ARRAY,
      description: "Chronological list of confirmed key live match events.",
      items: eventItemSchema,
    },
    summary: {
      type: Type.STRING,
      description: "Short factual summary of the current match state.",
    },
    uncertainty_notes: {
      type: Type.ARRAY,
      description:
        "List the specific facts that could not be reliably confirmed. Use an empty array when confidence is strong.",
      items: {
        type: Type.STRING,
      },
    },
  },
  required: [
    "match_status",
    "phase",
    "home_score",
    "away_score",
    "events",
    "uncertainty_notes",
  ],
};

export const oddsSchema: Schema = {
  type: Type.OBJECT,
  description: "Standard 1X2 decimal betting multipliers for the fixture.",
  properties: {
    home_multiplier: {
      type: Type.NUMBER,
      description: "Decimal odds for the home team win.",
    },
    draw_multiplier: {
      type: Type.NUMBER,
      description: "Decimal odds for the draw.",
    },
    away_multiplier: {
      type: Type.NUMBER,
      description: "Decimal odds for the away team win.",
    },
  },
  required: ["home_multiplier", "draw_multiplier", "away_multiplier"],
};

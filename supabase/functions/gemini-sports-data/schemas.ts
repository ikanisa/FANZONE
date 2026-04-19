import { type Schema, SchemaType } from "npm:@google/generative-ai";

import { EVENT_TYPES, MATCH_STATES } from "./constants.ts";

const eventItemSchema: Schema = {
  type: SchemaType.OBJECT,
  properties: {
    minute: {
      type: SchemaType.INTEGER,
      description:
        "Minute the event happened. Convert stoppage time to a single integer.",
    },
    event_type: {
      type: SchemaType.STRING,
      format: "enum",
      enum: [...EVENT_TYPES],
      description: "Supported event type.",
    },
    team: {
      type: SchemaType.STRING,
      description: "Team associated with the event.",
    },
    player: {
      type: SchemaType.STRING,
      description: "Primary player associated with the event.",
    },
    details: {
      type: SchemaType.STRING,
      description:
        "Extra context such as scoreline, assist, booking reason, or substitution in/out.",
    },
  },
  required: ["minute", "event_type", "team", "player", "details"],
};

export const eventsSchema: Schema = {
  type: SchemaType.OBJECT,
  description:
    "Current match state plus the chronological list of confirmed live football match events.",
  properties: {
    match_status: {
      type: SchemaType.STRING,
      format: "enum",
      enum: [...MATCH_STATES],
      description: "Current match status.",
    },
    home_score: {
      type: SchemaType.INTEGER,
      description: "Current or final score for the home team.",
    },
    away_score: {
      type: SchemaType.INTEGER,
      description: "Current or final score for the away team.",
    },
    events: {
      type: SchemaType.ARRAY,
      description: "Chronological list of key live match events.",
      items: eventItemSchema,
    },
  },
  required: ["match_status", "home_score", "away_score", "events"],
};

export const oddsSchema: Schema = {
  type: SchemaType.OBJECT,
  description: "Standard 1X2 decimal betting multipliers for the fixture.",
  properties: {
    home_multiplier: {
      type: SchemaType.NUMBER,
      description: "Decimal odds for the home team win.",
    },
    draw_multiplier: {
      type: SchemaType.NUMBER,
      description: "Decimal odds for the draw.",
    },
    away_multiplier: {
      type: SchemaType.NUMBER,
      description: "Decimal odds for the away team win.",
    },
  },
  required: ["home_multiplier", "draw_multiplier", "away_multiplier"],
};

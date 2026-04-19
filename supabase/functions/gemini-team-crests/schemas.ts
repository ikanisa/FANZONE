export const crestLookupResponseSchema = {
  type: "object",
  properties: {
    selected_candidate: {
      type: ["object", "null"],
      properties: {
        source_url: {
          type: "string",
          description: "Public page URL where the crest can be verified.",
        },
        image_url: {
          type: "string",
          description: "Direct public image URL for the club crest or logo.",
        },
        source_name: {
          type: ["string", "null"],
          description: "Readable name of the source publication or website.",
        },
        source_domain: {
          type: ["string", "null"],
          description: "Hostname for the source URL.",
        },
        source_type: {
          type: "string",
          enum: [
            "official_club",
            "official_federation",
            "official_competition",
            "trusted_reference",
            "unknown",
          ],
        },
        matched_name: {
          type: ["string", "null"],
          description:
            "Team name string observed on the source page that supports the match.",
        },
        matched_alias: {
          type: ["string", "null"],
          description: "Alias used to disambiguate the team, if any.",
        },
        official_signal: {
          type: ["string", "null"],
          description:
            "Why the source appears official, such as club domain, federation page, or verified profile.",
        },
        match_reason: {
          type: ["string", "null"],
          description:
            "Brief explanation of why this crest was chosen for the exact team.",
        },
        competition_match: {
          type: "boolean",
          description:
            "Whether the source context aligns with the provided competition.",
        },
        country_match: {
          type: "boolean",
          description:
            "Whether the source context aligns with the provided country.",
        },
        validation_notes: {
          type: ["string", "null"],
          description:
            "Short note about any caveat, such as fallback to a trusted reference source.",
        },
      },
      required: [
        "source_url",
        "image_url",
        "source_name",
        "source_domain",
        "source_type",
        "matched_name",
        "matched_alias",
        "official_signal",
        "match_reason",
        "competition_match",
        "country_match",
        "validation_notes",
      ],
      additionalProperties: false,
    },
    alternative_candidates: {
      type: "array",
      items: {
        type: "object",
        properties: {
          source_url: { type: ["string", "null"] },
          image_url: { type: ["string", "null"] },
          source_domain: { type: ["string", "null"] },
          source_type: {
            type: "string",
            enum: [
              "official_club",
              "official_federation",
              "official_competition",
              "trusted_reference",
              "unknown",
            ],
          },
          reason: { type: ["string", "null"] },
        },
        required: [
          "source_url",
          "image_url",
          "source_domain",
          "source_type",
          "reason",
        ],
        additionalProperties: false,
      },
      maxItems: 3,
    },
    search_summary: {
      type: ["string", "null"],
      description:
        "Short summary of the search strategy and why the selected source is the best match.",
    },
  },
  required: [
    "selected_candidate",
    "alternative_candidates",
    "search_summary",
  ],
  additionalProperties: false,
} as const;

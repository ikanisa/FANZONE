import { SchemaType, type Schema } from "npm:@google/generative-ai";

export const discoveredLeagueSchema: Schema = {
  type: SchemaType.OBJECT,
  properties: {
    league_name: { type: SchemaType.STRING },
    total_count: { type: SchemaType.INTEGER },
    teams: {
      type: SchemaType.ARRAY,
      items: {
        type: SchemaType.OBJECT,
        properties: {
          name: { type: SchemaType.STRING },
          short_name: { type: SchemaType.STRING },
          country: { type: SchemaType.STRING },
          country_code: { type: SchemaType.STRING },
          league_name: { type: SchemaType.STRING },
          search_terms: {
            type: SchemaType.ARRAY,
            items: { type: SchemaType.STRING },
          },
          crest_url: { type: SchemaType.STRING },
        },
        required: [
          "name",
          "short_name",
          "country",
          "country_code",
          "league_name",
          "search_terms",
        ],
      },
    },
  },
  required: ["league_name", "total_count", "teams"],
};

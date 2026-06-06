#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const files = {
  onboardingScreen: "lib/features/onboarding/screens/onboarding_screen.dart",
  fanProfileSelector: "lib/features/onboarding/widgets/fan_profile_selector.dart",
  fanProfileModel: "lib/features/onboarding/data/fan_profile.dart",
  onboardingGateway: "lib/features/onboarding/data/onboarding_gateway.dart",
  teamCatalog: "lib/features/onboarding/data/team_search_catalog.dart",
  fanProfileTest: "test/features/onboarding/fan_profile_test.dart",
  fanProfileSelectorTest: "test/features/onboarding/fan_profile_selector_test.dart",
  teamCatalogTest: "test/features/onboarding/team_search_catalog_test.dart",
  categoryMigration: "supabase/migrations/20260503135000_fan_profile_categories.sql",
  topClubMigration: "supabase/migrations/20260504170000_replace_uat_sports_catalog.sql",
  localCatalogMigration:
    "supabase/migrations/20260508170000_import_world_cup_african_catalog.sql",
};

const failures = [];

function read(filePath) {
  const absolute = path.resolve(root, filePath);
  if (!fs.existsSync(absolute)) {
    failures.push(`Missing onboarding team catalog evidence file: ${filePath}`);
    return "";
  }
  return fs.readFileSync(absolute, "utf8");
}

function requireText(label, source, required) {
  for (const text of required) {
    if (!source.includes(text)) {
      failures.push(`${label} is missing required evidence text: ${text}`);
    }
  }
}

function rejectPattern(label, source, pattern, message) {
  if (pattern.test(source)) failures.push(`${label}: ${message}`);
}

const sources = Object.fromEntries(
  Object.entries(files).map(([key, filePath]) => [key, read(filePath)]),
);

requireText("Onboarding screen", sources.onboardingScreen, [
  "requireLocalTeam: true",
  "requireTopEuropeanTeam: true",
  "requireRemoteSync: true",
  "Pick your local team, top European clubs, and World Cup teams",
]);

requireText("Fan profile selector", sources.fanProfileSelector, [
  "FanProfileTeamCategory.local",
  "FanProfileTeamCategory.topEuropean",
  "FanProfileTeamCategory.national",
  "countryCode: widget.localCountryCode",
  "localOnly: true",
  "region: 'europe'",
  "popularOnly: true",
  "nationalOnly: true",
]);

requireText("Fan profile model", sources.fanProfileModel, [
  "FanProfileTeamCategory { local, topEuropean, national }",
  "Select one local team to continue.",
  "Select at least one top European team to continue.",
  "A team can only be selected once in a fan profile.",
]);

requireText("Onboarding gateway", sources.onboardingGateway, [
  ".from('teams')",
  ".from('user_favorite_teams')",
  "countryCode: countryCode",
  "localOnly: localOnly",
  "popularOnly: popularOnly",
  "nationalOnly: nationalOnly",
  "return _resolvedCatalog.browse(",
  "onboardingCompleted: true",
]);

requireText("Team catalog", sources.teamCatalog, [
  "String? teamType",
  "List<OnboardingTeam> browse({",
  "team.teamType",
  "_normalize(team.league ?? '').contains('world cup')",
]);

requireText("Fan profile tests", sources.fanProfileTest, [
  "can require local and top European teams for onboarding",
  "throwsArgumentError",
]);

requireText("Fan profile selector tests", sources.fanProfileSelectorTest, [
  "local onboarding step browses Supabase teams by country code",
  "expect(gateway.lastCountryCode, 'MT')",
  "expect(gateway.lastRegion, 'europe')",
  "expect(gateway.lastNationalOnly, isTrue)",
]);

requireText("Team catalog tests", sources.teamCatalogTest, [
  "browse filters local, top European, and national catalog groups",
  "teamType: 'club'",
  "teamType: 'national'",
]);

requireText("Favorite-team migration", sources.categoryMigration, [
  "ALTER TABLE public.user_favorite_teams",
  "top_european",
  "national",
  "enforce_user_favorite_team_limits",
]);

requireText("Top-club team migration", sources.topClubMigration, [
  "INSERT INTO public.teams",
  "'arsenal'",
  "'real_madrid'",
  "'barcelona'",
  "'manchester_city'",
  "'FIFA World Cup'",
  "'national'",
]);

requireText("Local team catalog migration", sources.localCatalogMigration, [
  "INSERT INTO public.teams",
  "'africa'",
  "'club'",
  "local_",
]);

rejectPattern(
  "Onboarding team catalog evidence",
  [
    sources.onboardingScreen,
    sources.fanProfileSelector,
    sources.fanProfileModel,
    sources.onboardingGateway,
    sources.teamCatalog,
  ].join("\n"),
  /\b(fet wallet|wallet balance|wallet transfer|stake[ -]?fet|cash[- ]?out|wager|odds)\b/i,
  "Onboarding/fan profile code must stay clear of wallet, staking, cash-out, wagering, and odds positioning.",
);

if (failures.length > 0) {
  console.error("Onboarding team catalog evidence validation failed:");
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log("Onboarding team catalog evidence validation passed.");

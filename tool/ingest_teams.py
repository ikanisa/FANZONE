import json
import os
import sys
import time
from pathlib import Path

import requests

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
    print("Error: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set.")
    sys.exit(1)

FUNCTION_NAME = os.environ.get("TEAM_DISCOVERY_FUNCTION", "gemini-team-discovery")
FUNCTION_URL = f"{SUPABASE_URL}/functions/v1/{FUNCTION_NAME}"
HEADERS = {
    "Authorization": f"Bearer {SUPABASE_SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
}
REQUEST_TIMEOUT = int(os.environ.get("TEAM_DISCOVERY_TIMEOUT", "120"))
SLEEP_SECONDS = float(os.environ.get("TEAM_DISCOVERY_SLEEP", "1.0"))
EXPORT_PATH = os.environ.get("TEAM_DISCOVERY_EXPORT_PATH", "").strip()
INCLUDE_GROUNDING = os.environ.get("TEAM_DISCOVERY_INCLUDE_GROUNDING", "").strip().lower() in {
    "1",
    "true",
    "yes",
}


def fetch_catalog():
    response = requests.get(
        FUNCTION_URL,
        headers=HEADERS,
        params={"catalog": "1"},
        timeout=REQUEST_TIMEOUT,
    )
    response.raise_for_status()
    payload = response.json()
    return payload.get("catalog", [])


def ingest_country(country):
    code = country["countryCode"]
    name = country["country"]
    region = country["region"]
    expected = country.get("expectedTeams", 0)
    print(f"Ingesting teams for {name} ({code}) [{region}] expected≈{expected}...")

    payload = {
        "country_code": code,
        "include_grounding": INCLUDE_GROUNDING,
    }

    try:
        response = requests.post(
            FUNCTION_URL,
            headers=HEADERS,
            json=payload,
            timeout=REQUEST_TIMEOUT,
        )
        response.raise_for_status()
        data = response.json()
        result = (data.get("results") or [{}])[0]
        teams_discovered = result.get("teamsDiscovered", 0)
        teams_upserted = result.get("teamsUpserted", 0)
        league = result.get("league") or country.get("league")
        print(
            f"  Success: league={league} discovered={teams_discovered} "
            f"upserted={teams_upserted}"
        )
        return data
    except Exception as error:
        print(f"  Error: {error}")
        return None


def export_teams(destination):
    response = requests.get(FUNCTION_URL, headers=HEADERS, timeout=REQUEST_TIMEOUT)
    response.raise_for_status()
    payload = response.json()
    path = Path(destination)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"Exported {payload.get('count', 0)} teams to {path}")


def main():
    countries = fetch_catalog()
    if not countries:
        print("No catalog entries returned from team discovery function.")
        sys.exit(1)

    limit = os.environ.get("TEAM_DISCOVERY_LIMIT")
    if limit:
        countries = countries[: int(limit)]

    print(f"Starting ingestion for {len(countries)} countries via {FUNCTION_NAME}...")
    for country in countries:
        ingest_country(country)
        time.sleep(SLEEP_SECONDS)

    if EXPORT_PATH:
        export_teams(EXPORT_PATH)

    print("Ingestion complete.")


if __name__ == "__main__":
    main()

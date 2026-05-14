#!/usr/bin/env python3
"""Fetch LiveScore football data and prepare FANZONE catalog ingest rows.

The script intentionally writes provider data to FANZONE's staging/raw ingest
contract. It does not curate matches or make any fixture pool-eligible.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo


PUBLIC_API_BASE = "https://prod-cdn-public-api.livescore.com/v1/api/app"
LIVESCORE_WEB_BASE = "https://www.livescore.com"
TEAM_IMAGE_BASE = "https://storage.livescore.com/images/team/high/"
COMPETITION_IMAGE_BASE = "https://storage.livescore.com/images/competition/high/"
DEFAULT_USER_AGENT = "FANZONE-UAT-LiveScore-Ingest/1.0"


@dataclass(frozen=True)
class LiveScoreResource:
    resource_id: str
    provider_competition_id: str
    competition_slug: str
    category_slug: str
    competition_id: str
    season_id: str
    timezone_name: str
    locale: str
    limit: int


def slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.strip().lower())
    return slug.strip("-")


def http_json(url: str, *, user_agent: str, timeout: int) -> Any:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": user_agent,
            "Accept": "application/json,text/plain,*/*",
            "Origin": LIVESCORE_WEB_BASE,
            "Referer": f"{LIVESCORE_WEB_BASE}/",
        },
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        body = response.read().decode("utf-8")
    return json.loads(body)


def post_json(
    url: str,
    payload: dict[str, Any],
    *,
    headers: dict[str, str],
    timeout: int,
) -> Any:
    data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
            **headers,
        },
    )
    try:
        response = urllib.request.urlopen(request, timeout=timeout)
    except urllib.error.HTTPError as exc:
        error_body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"POST {url} failed with HTTP {exc.code}: {error_body}") from exc
    with response:
        body = response.read().decode("utf-8")
    return json.loads(body) if body else {}


def parse_livescore_datetime(value: Any, timezone_name: str) -> datetime:
    raw = str(value or "").strip()
    if not re.fullmatch(r"\d{14}", raw):
        raise ValueError(f"Invalid LiveScore Esd datetime: {value!r}")
    local = datetime.strptime(raw, "%Y%m%d%H%M%S")
    return local.replace(tzinfo=ZoneInfo(timezone_name))


def team_image_url(path: Any) -> str | None:
    raw = str(path or "").strip()
    if not raw:
        return None
    if raw.startswith("http://") or raw.startswith("https://"):
        return raw
    return urllib.parse.urljoin(TEAM_IMAGE_BASE, raw)


def competition_image_url(path: Any) -> str | None:
    raw = str(path or "").strip()
    if not raw:
        return None
    if raw.startswith("http://") or raw.startswith("https://"):
        return raw
    return urllib.parse.urljoin(COMPETITION_IMAGE_BASE, raw)


def build_fixtures_api_url(resource: LiveScoreResource) -> str:
    timezone_path = urllib.parse.quote(resource.timezone_name, safe="")
    query = urllib.parse.urlencode({"locale": resource.locale, "limit": resource.limit})
    return (
        f"{PUBLIC_API_BASE}/competition/{resource.provider_competition_id}"
        f"/fixtures-w/{timezone_path}?{query}"
    )


def build_info_api_url(event_id: str, locale: str) -> str:
    query = urllib.parse.urlencode({"locale": locale})
    return f"{PUBLIC_API_BASE}/info/soccer/{event_id}?{query}"


def build_scoreboard_api_url(event_id: str, locale: str) -> str:
    query = urllib.parse.urlencode({"locale": locale})
    return f"{PUBLIC_API_BASE}/scoreboard/soccer/{event_id}?{query}"


def build_match_url(
    competition_slug: str,
    category_slug: str,
    home_name: str,
    away_name: str,
    event_id: str,
) -> str:
    match_slug = f"{slugify(home_name)}-vs-{slugify(away_name)}"
    return (
        f"{LIVESCORE_WEB_BASE}/en/football/{category_slug}/"
        f"{competition_slug}/{match_slug}/{event_id}/"
    )


def first_team(event: dict[str, Any], key: str) -> dict[str, Any]:
    teams = event.get(key)
    if isinstance(teams, list) and teams:
        first = teams[0]
        return first if isinstance(first, dict) else {}
    return {}


def scoreboard_team(scoreboard: dict[str, Any] | None, key: str) -> dict[str, Any]:
    if not scoreboard:
        return {}
    return first_team(scoreboard, key)


def fetch_fixture_rows(
    resource: LiveScoreResource,
    *,
    include_details: bool,
    include_scoreboard: bool,
    delay_ms: int,
    timeout: int,
    user_agent: str,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    api_url = build_fixtures_api_url(resource)
    payload = http_json(api_url, user_agent=user_agent, timeout=timeout)
    stages = payload.get("Stages") or []
    rows: list[dict[str, Any]] = []
    seen_event_ids: set[str] = set()

    for stage in stages:
        if not isinstance(stage, dict):
            continue
        events = stage.get("Events") or []
        for event in events:
            if not isinstance(event, dict):
                continue
            event_id = str(event.get("Eid") or "").strip()
            if not event_id or event_id in seen_event_ids:
                continue
            seen_event_ids.add(event_id)

            home = first_team(event, "T1")
            away = first_team(event, "T2")
            home_name = str(home.get("Nm") or "").strip()
            away_name = str(away.get("Nm") or "").strip()
            starts_at = parse_livescore_datetime(event.get("Esd"), resource.timezone_name)
            source_url = build_match_url(
                resource.competition_slug,
                resource.category_slug,
                home_name,
                away_name,
                event_id,
            )

            details: dict[str, Any] = {}
            scoreboard: dict[str, Any] | None = None
            if include_details:
                time.sleep(delay_ms / 1000)
                details = http_json(
                    build_info_api_url(event_id, resource.locale),
                    user_agent=user_agent,
                    timeout=timeout,
                )
            if include_scoreboard:
                time.sleep(delay_ms / 1000)
                scoreboard = http_json(
                    build_scoreboard_api_url(event_id, resource.locale),
                    user_agent=user_agent,
                    timeout=timeout,
                )

            scoreboard_home = scoreboard_team(scoreboard, "T1")
            scoreboard_away = scoreboard_team(scoreboard, "T2")
            venue = details.get("Vnm") or (scoreboard or {}).get("Venue", {}).get("Vnm")
            venue_city = details.get("Vcy") or details.get("VCnm")
            if not venue_city:
                venue_city = (scoreboard or {}).get("Venue", {}).get("Vcy")

            row = {
                "source_match_id": event_id,
                "provider_match_id": event_id,
                "competition_id": resource.competition_id,
                "season_id": resource.season_id,
                "competition_name": payload.get("CompN") or stage.get("CompN"),
                "competition_provider_id": payload.get("CompId") or stage.get("CompId"),
                "competition_logo_url": competition_image_url(payload.get("badgeUrl") or stage.get("badgeUrl")),
                "stage": stage.get("Snm") or event.get("stageName"),
                "matchday_or_round": event.get("ErnInf"),
                "home_team_source_id": str(home.get("ID") or scoreboard_home.get("ID") or "").strip(),
                "away_team_source_id": str(away.get("ID") or scoreboard_away.get("ID") or "").strip(),
                "home_team_name": home_name,
                "away_team_name": away_name,
                "home_team_abbr": home.get("Abr") or scoreboard_home.get("Abr"),
                "away_team_abbr": away.get("Abr") or scoreboard_away.get("Abr"),
                "home_team_country_code": scoreboard_home.get("CoId"),
                "away_team_country_code": scoreboard_away.get("CoId"),
                "home_team_image_path": home.get("Img") or scoreboard_home.get("Img"),
                "away_team_image_path": away.get("Img") or scoreboard_away.get("Img"),
                "home_team_logo_url": team_image_url(home.get("Img") or scoreboard_home.get("Img")),
                "away_team_logo_url": team_image_url(away.get("Img") or scoreboard_away.get("Img")),
                "home_team_type": "national",
                "away_team_type": "national",
                "local_date": starts_at.date().isoformat(),
                "local_time": starts_at.time().replace(microsecond=0).isoformat(),
                "timezone_name": resource.timezone_name,
                "starts_at": starts_at.isoformat().replace("+00:00", "Z"),
                "venue": venue,
                "venue_city": venue_city,
                "source_url": source_url,
                "match_status": normalize_event_status(event.get("Eps")),
                "event_status": event.get("Eps"),
                "is_neutral": bool(details.get("Vneut") or (scoreboard or {}).get("Venue", {}).get("Vneut")),
                "confidence": "official",
                "source_payload": {
                    "stage": stage,
                    "event": event,
                    "details": details,
                    "scoreboard": scoreboard,
                },
            }
            rows.append(row)

    metadata = {
        "api_url": api_url,
        "provider_competition_id": resource.provider_competition_id,
        "competition_name": payload.get("CompN"),
        "stages_seen": len(stages),
        "rows_seen": len(rows),
        "timezone_name": resource.timezone_name,
        "include_details": include_details,
        "include_scoreboard": include_scoreboard,
    }
    return rows, metadata


def normalize_event_status(status: Any) -> str:
    raw = str(status or "").strip().lower()
    if raw in {"ns", "unknown", "upcoming", "scheduled"}:
        return "scheduled"
    if raw in {"live", "inplay", "1h", "2h", "ht"}:
        return "live"
    if raw in {"ft", "aet", "ap", "finished"}:
        return "finished"
    if raw in {"postponed", "ppd"}:
        return "postponed"
    if raw in {"cancelled", "canceled", "can"}:
        return "cancelled"
    return "scheduled"


def build_output_payload(
    resource: LiveScoreResource,
    rows: list[dict[str, Any]],
    metadata: dict[str, Any],
) -> dict[str, Any]:
    return {
        "datasetType": "official_fixture_rows",
        "mode": "scheduled",
        "sourceId": resource.resource_id,
        "resourceId": resource.resource_id,
        "timezone": resource.timezone_name,
        "metadata": metadata,
        "rows": rows,
    }


def rest_rpc(
    supabase_url: str,
    service_role_key: str,
    function_name: str,
    payload: dict[str, Any],
    *,
    timeout: int,
) -> Any:
    url = f"{supabase_url.rstrip('/')}/rest/v1/rpc/{function_name}"
    return post_json(
        url,
        payload,
        headers={
            "apikey": service_role_key,
            "Authorization": f"Bearer {service_role_key}",
        },
        timeout=timeout,
    )


def push_to_supabase_rest(
    resource: LiveScoreResource,
    rows: list[dict[str, Any]],
    metadata: dict[str, Any],
    *,
    supabase_url: str,
    service_role_key: str,
    apply_to_matches: bool,
    timeout: int,
) -> dict[str, Any]:
    api_url = build_fixtures_api_url(resource)
    resource_url = (
        f"{LIVESCORE_WEB_BASE}/en/football/{resource.category_slug}/"
        f"{resource.competition_slug}/fixtures/"
    )
    rest_rpc(
        supabase_url,
        service_role_key,
        "admin_register_football_official_resource",
        {
            "p_resource_id": resource.resource_id,
            "p_name": f"LiveScore {metadata.get('competition_name') or resource.competition_slug} fixtures",
            "p_provider": "livescore",
            "p_resource_url": resource_url,
            "p_resource_type": "fixtures",
            "p_competition_id": resource.competition_id,
            "p_season_id": resource.season_id,
            "p_api_url": api_url,
            "p_provider_competition_id": resource.provider_competition_id,
            "p_timezone": resource.timezone_name,
            "p_fetch_mode": "livescore_public_api",
            "p_is_authoritative": True,
            "p_config_json": metadata,
        },
        timeout=timeout,
    )
    sync_run_id = rest_rpc(
        supabase_url,
        service_role_key,
        "admin_start_football_resource_sync",
        {"p_resource_id": resource.resource_id, "p_metadata": metadata},
        timeout=timeout,
    )
    staged = rest_rpc(
        supabase_url,
        service_role_key,
        "admin_stage_official_fixture_rows",
        {
            "p_resource_id": resource.resource_id,
            "p_rows": rows,
            "p_sync_run_id": sync_run_id,
            "p_timezone": resource.timezone_name,
        },
        timeout=timeout,
    )
    applied: Any = None
    if apply_to_matches:
        applied = rest_rpc(
            supabase_url,
            service_role_key,
            "admin_apply_official_fixture_staging_batch",
            {"p_resource_id": resource.resource_id, "p_limit": len(rows)},
            timeout=timeout,
        )
    rest_rpc(
        supabase_url,
        service_role_key,
        "admin_finish_football_resource_sync",
        {
            "p_sync_run_id": sync_run_id,
            "p_status": "succeeded",
            "p_rows_found": len(rows),
            "p_rows_staged": staged.get("staged_rows", len(rows)) if isinstance(staged, dict) else len(rows),
            "p_rows_applied": applied.get("applied_rows", 0) if isinstance(applied, dict) else 0,
            "p_metadata": metadata,
        },
        timeout=timeout,
    )
    return {"sync_run_id": sync_run_id, "staged": staged, "applied": applied}


def push_to_edge_function(
    edge_url: str,
    cron_secret: str,
    payload: dict[str, Any],
    *,
    timeout: int,
) -> Any:
    return post_json(
        edge_url,
        payload,
        headers={"x-cron-secret": cron_secret},
        timeout=timeout,
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fetch LiveScore fixtures, teams, and crest URLs for FANZONE staging.",
    )
    parser.add_argument("--resource-id", default="livescore_world_cup_2026")
    parser.add_argument("--provider-competition-id", default="734")
    parser.add_argument("--competition-slug", default="world-cup-2026")
    parser.add_argument("--category-slug", default="international")
    parser.add_argument("--competition-id", default="fifa_world_cup")
    parser.add_argument("--season-id", default="fifa_world_cup_2026")
    parser.add_argument("--timezone", default="UTC")
    parser.add_argument("--locale", default="en")
    parser.add_argument("--limit", type=int, default=200)
    parser.add_argument("--include-details", action="store_true", help="Fetch venue details per event.")
    parser.add_argument(
        "--include-scoreboard",
        action="store_true",
        help="Fetch scoreboard per event for country codes and richer team payloads.",
    )
    parser.add_argument("--delay-ms", type=int, default=750)
    parser.add_argument("--timeout", type=int, default=30)
    parser.add_argument("--user-agent", default=DEFAULT_USER_AGENT)
    parser.add_argument("--output", type=Path, help="Write JSON payload to this path.")
    parser.add_argument(
        "--post-edge-url",
        help="POST the staging payload to a Supabase Edge Function URL.",
    )
    parser.add_argument(
        "--cron-secret",
        default=os.environ.get("CRON_SECRET"),
        help="Cron secret for --post-edge-url. Defaults to CRON_SECRET.",
    )
    parser.add_argument(
        "--supabase-url",
        default=os.environ.get("SUPABASE_URL"),
        help="Supabase project URL for direct REST RPC push.",
    )
    parser.add_argument(
        "--service-role-key",
        default=os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("EDGE_SERVICE_ROLE_KEY"),
        help="Service role key for direct REST RPC push.",
    )
    parser.add_argument(
        "--push-rest",
        action="store_true",
        help="Register resource and stage rows through Supabase REST RPC.",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="After staging through REST RPC, upsert staged rows into the raw matches catalog.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        ZoneInfo(args.timezone)
        resource = LiveScoreResource(
            resource_id=args.resource_id,
            provider_competition_id=args.provider_competition_id,
            competition_slug=args.competition_slug,
            category_slug=args.category_slug,
            competition_id=args.competition_id,
            season_id=args.season_id,
            timezone_name=args.timezone,
            locale=args.locale,
            limit=max(1, args.limit),
        )
        rows, metadata = fetch_fixture_rows(
            resource,
            include_details=args.include_details,
            include_scoreboard=args.include_scoreboard,
            delay_ms=max(0, args.delay_ms),
            timeout=args.timeout,
            user_agent=args.user_agent,
        )
        payload = build_output_payload(resource, rows, metadata)

        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")

        edge_result = None
        if args.post_edge_url:
            if not args.cron_secret:
                raise RuntimeError("--post-edge-url requires --cron-secret or CRON_SECRET")
            edge_result = push_to_edge_function(
                args.post_edge_url,
                args.cron_secret,
                payload,
                timeout=args.timeout,
            )

        rest_result = None
        if args.push_rest:
            if not args.supabase_url or not args.service_role_key:
                raise RuntimeError("--push-rest requires --supabase-url and --service-role-key")
            rest_result = push_to_supabase_rest(
                resource,
                rows,
                metadata,
                supabase_url=args.supabase_url,
                service_role_key=args.service_role_key,
                apply_to_matches=args.apply,
                timeout=args.timeout,
            )

        summary = {
            "resource_id": resource.resource_id,
            "provider_competition_id": resource.provider_competition_id,
            "rows": len(rows),
            "stages_seen": metadata.get("stages_seen"),
            "output": str(args.output) if args.output else None,
            "posted_edge": bool(args.post_edge_url),
            "posted_rest": bool(args.push_rest),
            "applied": bool(args.apply and args.push_rest),
            "edge_result": edge_result,
            "rest_result": rest_result,
        }
        print(json.dumps(summary, indent=2, sort_keys=True))
        return 0
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, ValueError, RuntimeError) as exc:
        print(f"LiveScore ingest failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

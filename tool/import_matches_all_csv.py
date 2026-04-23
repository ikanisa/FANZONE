#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import sys
import unicodedata
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any, Iterable

import psycopg
from psycopg.rows import dict_row


@dataclass(frozen=True)
class CompetitionSpec:
    id: str
    name: str
    short_name: str
    country: str
    region: str
    competition_type: str
    is_international: bool
    team_scope: str
    data_source: str = "matches_all_csv"


@dataclass
class ProvisionalTeam:
    namespace: str
    raw_key: str
    display_names: Counter[str] = field(default_factory=Counter)
    raw_ids: Counter[str] = field(default_factory=Counter)
    competition_ids: set[str] = field(default_factory=set)
    regions: Counter[str] = field(default_factory=Counter)
    team_type: str = "club"
    country: str | None = None
    canonical_id: str | None = None
    seeded_row: dict[str, Any] | None = None
    existing_row: dict[str, Any] | None = None

    def preferred_display_name(self) -> str:
        ranked = sorted(
            self.display_names.items(),
            key=lambda item: (-item[1], -len(item[0]), item[0].lower()),
        )
        return ranked[0][0]


@dataclass
class FinalTeam:
    id: str
    team_type: str
    country: str | None
    region: str | None
    seeded_row: dict[str, Any] | None = None
    existing_row: dict[str, Any] | None = None
    display_names: Counter[str] = field(default_factory=Counter)
    raw_ids: Counter[str] = field(default_factory=Counter)
    competition_ids: set[str] = field(default_factory=set)

    def preferred_display_name(self) -> str:
        if self.seeded_row and self.seeded_row.get("name"):
            return str(self.seeded_row["name"])
        if self.existing_row and self.existing_row.get("name"):
            return str(self.existing_row["name"])

        ranked = sorted(
            self.display_names.items(),
            key=lambda item: (-item[1], -len(item[0]), item[0].lower()),
        )
        return ranked[0][0]


def slugify(value: str) -> str:
    ascii_value = (
        unicodedata.normalize("NFKD", value)
        .encode("ascii", "ignore")
        .decode("ascii")
        .lower()
    )
    slug = re.sub(r"[^a-z0-9]+", "-", ascii_value).strip("-")
    return slug or "unknown"


def normalized_text(value: str) -> str:
    folded = (
        unicodedata.normalize("NFKD", value)
        .encode("ascii", "ignore")
        .decode("ascii")
        .lower()
    )
    folded = folded.replace("&", " and ")
    folded = re.sub(r"[^a-z0-9]+", " ", folded)
    return re.sub(r"\s+", " ", folded).strip()


def core_team_name(value: str) -> str:
    text = normalized_text(value)
    replacements = {
        "man utd": "manchester united",
        "man united": "manchester united",
        "man city": "manchester city",
        "man city fc": "manchester city",
        "ath madrid": "atletico madrid",
        "borussia gladbach": "gladbach",
        "eintracht frankfurt": "frankfurt",
        "psg": "paris saint germain",
        "inter": "inter milan",
        "fc koln": "koln",
        "fc koln ": "koln",
        "fc koln 1": "koln",
        "fc koln ii": "koln ii",
    }
    text = replacements.get(text, text)
    text = re.sub(r"\b(fc|cf|sc|fk|afc|ac|as|us|rc|nk|sk|club)\b", " ", text)
    text = re.sub(r"\b(st|saint)\b", "saint", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text or normalized_text(value)


def iso_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def parse_match_date(raw: str) -> datetime:
    return datetime.strptime(raw.strip(), "%Y-%m-%d").replace(tzinfo=timezone.utc)


def normalize_status(raw: str) -> str:
    text = normalized_text(raw)
    if text in {"completed", "finished"}:
        return "completed"
    if text in {"scheduled", "not started", "not_started", "fixture"}:
        return "scheduled"
    if text in {"live", "in play"}:
        return "live"
    if text in {"cancelled", "canceled"}:
        return "cancelled"
    return raw.strip().lower() or "scheduled"


def normalize_stage(raw: str) -> str:
    if not raw.strip():
        return "Regular"

    text = raw.strip()
    key = normalized_text(text)
    replacements = {
        "copa 3rd": "Copa 3rd Place",
        "copa 3rd place": "Copa 3rd Place",
        "semi finals": "Semi-finals",
        "semi final": "Semi-finals",
        "quarter finals": "Quarter-finals",
        "quarter final": "Quarter-finals",
        "round of 16": "Round of 16",
        "round of 32": "Round of 32",
        "play off": "Play-off",
    }
    return replacements.get(key, text)


def normalize_round(raw: str, stage: str) -> str:
    value = raw.strip()
    if value:
        return value
    return stage


def to_bool(raw: str) -> bool:
    return normalized_text(raw) in {"true", "yes", "y", "1"}


def nullable_int(raw: str) -> int | None:
    text = raw.strip()
    if not text:
        return None
    return int(text)


def compute_result_code(home_goals: int | None, away_goals: int | None) -> str | None:
    if home_goals is None or away_goals is None:
        return None
    if home_goals > away_goals:
        return "H"
    if away_goals > home_goals:
        return "A"
    return "D"


def stable_hash(*parts: str, prefix: str) -> str:
    digest = hashlib.sha1("||".join(parts).encode("utf-8")).hexdigest()[:16]
    return f"{prefix}_{digest}"


COMPETITIONS: dict[str, CompetitionSpec] = {
    "comp_epl": CompetitionSpec("comp_epl", "Premier League", "Premier League", "England", "europe", "league", False, "club"),
    "comp_ll": CompetitionSpec("comp_ll", "La Liga", "La Liga", "Spain", "europe", "league", False, "club"),
    "comp_l1": CompetitionSpec("comp_l1", "Ligue 1", "Ligue 1", "France", "europe", "league", False, "club"),
    "comp_bl": CompetitionSpec("comp_bl", "Bundesliga", "Bundesliga", "Germany", "europe", "league", False, "club"),
    "comp_sa": CompetitionSpec("comp_sa", "Serie A", "Serie A", "Italy", "europe", "league", False, "club"),
    "comp_rpl": CompetitionSpec("comp_rpl", "Rwanda Premier League", "RPL", "Rwanda", "africa", "league", False, "club"),
    "comp_zsl": CompetitionSpec("comp_zsl", "Zambia Super League", "ZSL", "Zambia", "africa", "league", False, "club"),
    "comp_drc": CompetitionSpec("comp_drc", "Linafoot", "Linafoot", "DR Congo", "africa", "league", False, "club"),
    "comp_wc": CompetitionSpec("comp_wc", "FIFA World Cup", "World Cup", "International", "global", "tournament", True, "national_team"),
    "comp_wcq": CompetitionSpec("comp_wcq", "World Cup Qualifiers", "WCQ", "International", "global", "qualifier", True, "national_team"),
    "comp_wcp": CompetitionSpec("comp_wcp", "World Cup Play-offs", "WC Play-off", "International", "global", "qualifier", True, "national_team"),
    "comp_con": CompetitionSpec("comp_con", "CONMEBOL Qualifiers", "CONMEBOL Qual", "South America", "americas", "qualifier", True, "national_team"),
    "comp_e24": CompetitionSpec("comp_e24", "UEFA Euro", "EURO", "Europe", "europe", "tournament", True, "national_team"),
    "comp_e24q": CompetitionSpec("comp_e24q", "UEFA Euro Qualifiers", "EURO Qual", "Europe", "europe", "qualifier", True, "national_team"),
    "comp_e24p": CompetitionSpec("comp_e24p", "UEFA Euro Play-offs", "EURO Play-off", "Europe", "europe", "qualifier", True, "national_team"),
    "comp_unl": CompetitionSpec("comp_unl", "UEFA Nations League", "UNL", "Europe", "europe", "tournament", True, "national_team"),
    "comp_unl23": CompetitionSpec("comp_unl23", "UEFA Nations League 2022/23", "UNL 2022/23", "Europe", "europe", "tournament", True, "national_team"),
    "comp_ca24": CompetitionSpec("comp_ca24", "Copa America", "Copa America", "South America", "americas", "tournament", True, "national_team"),
    "comp_ca24p": CompetitionSpec("comp_ca24p", "Copa America Play-offs", "Copa Play-off", "CONCACAF", "americas", "qualifier", True, "national_team"),
    "comp_af23": CompetitionSpec("comp_af23", "Africa Cup of Nations 2023", "AFCON 2023", "Africa", "africa", "tournament", True, "national_team"),
    "comp_af25": CompetitionSpec("comp_af25", "Africa Cup of Nations 2025", "AFCON 2025", "Africa", "africa", "tournament", True, "national_team"),
    "comp_afq": CompetitionSpec("comp_afq", "AFCON Qualifiers", "AFCON Qual", "Africa", "africa", "qualifier", True, "national_team"),
    "comp_gc23": CompetitionSpec("comp_gc23", "CONCACAF Gold Cup", "Gold Cup", "CONCACAF", "americas", "tournament", True, "national_team"),
    "comp_cnl": CompetitionSpec("comp_cnl", "CONCACAF Nations League", "CNL", "CONCACAF", "americas", "tournament", True, "national_team"),
    "comp_cnl23": CompetitionSpec("comp_cnl23", "CONCACAF Nations League 2023/24", "CNL 2023/24", "CONCACAF", "americas", "tournament", True, "national_team"),
    "comp_ac23": CompetitionSpec("comp_ac23", "AFC Asian Cup", "Asian Cup", "Asia", "asia", "tournament", True, "national_team"),
    "comp_caf23": CompetitionSpec("comp_caf23", "CAFA Nations Cup", "CAFA Cup", "Asia", "asia", "tournament", True, "national_team"),
    "comp_agc": CompetitionSpec("comp_agc", "Arabian Gulf Cup", "Gulf Cup", "Middle East", "asia", "tournament", True, "national_team"),
    "comp_ofc": CompetitionSpec("comp_ofc", "OFC Nations Cup", "OFC Cup", "Oceania", "global", "tournament", True, "national_team"),
    "comp_fri": CompetitionSpec("comp_fri", "International Friendlies", "Friendlies", "International", "global", "friendly", True, "national_team"),
    "comp_mpl": CompetitionSpec("comp_mpl", "Maltese Premier League", "MPL", "Malta", "europe", "league", False, "club"),
}

SEEDED_SEASONS: dict[tuple[str, str], dict[str, str]] = {
    ("comp_epl", "seas_epl_2526"): {"id": "seas_epl_2526", "name": "2025-2026", "start_date": "2025-08-16", "end_date": "2026-05-24"},
    ("comp_ll", "seas_ll_2526"): {"id": "seas_ll_2526", "name": "2025-2026", "start_date": "2025-08-15", "end_date": "2026-05-24"},
    ("comp_l1", "seas_l1_2526"): {"id": "seas_l1_2526", "name": "2025-2026", "start_date": "2025-08-16", "end_date": "2026-05-17"},
    ("comp_bl", "seas_bl_2526"): {"id": "seas_bl_2526", "name": "2025-2026", "start_date": "2025-08-22", "end_date": "2026-05-16"},
    ("comp_sa", "seas_sa_2526"): {"id": "seas_sa_2526", "name": "2025-2026", "start_date": "2025-08-23", "end_date": "2026-05-24"},
    ("comp_rpl", "seas_rpl_2526"): {"id": "seas_rpl_2526", "name": "2025-2026", "start_date": "2025-08-15", "end_date": "2026-05-29"},
    ("comp_zsl", "seas_zsl_2526"): {"id": "seas_zsl_2526", "name": "2025-2026", "start_date": "2025-08-15", "end_date": "2026-05-16"},
    ("comp_drc", "seas_drc_2526"): {"id": "seas_drc_2526", "name": "2025-2026", "start_date": "2025-08-20", "end_date": "2026-05-31"},
    ("comp_wc", "seas_wc18"): {"id": "seas_wc18", "name": "2018", "start_date": "2018-06-14", "end_date": "2018-07-15"},
    ("comp_wc", "seas_wc22"): {"id": "seas_wc22", "name": "2022", "start_date": "2022-11-20", "end_date": "2022-12-18"},
    ("comp_wc", "seas_wc26"): {"id": "seas_wc26", "name": "2026", "start_date": "2026-06-11", "end_date": "2026-07-19"},
    ("comp_wcq", "seas_wcq_26"): {"id": "seas_wcq_26", "name": "2026 Qualifiers", "start_date": "2023-09-07", "end_date": "2026-03-31"},
    ("comp_wcp", "seas_wcp_26"): {"id": "seas_wcp_26", "name": "2026 Play-offs", "start_date": "2026-03-26", "end_date": "2026-03-31"},
    ("comp_con", "seas_con_26"): {"id": "seas_con_26", "name": "CONMEBOL 2026 Qualifiers", "start_date": "2023-09-07", "end_date": "2025-10-15"},
    ("comp_e24", "seas_e24"): {"id": "seas_e24", "name": "Euro 2024", "start_date": "2024-06-14", "end_date": "2024-07-14"},
    ("comp_e24q", "seas_e24q"): {"id": "seas_e24q", "name": "Euro 2024 Qualifiers", "start_date": "2023-03-23", "end_date": "2023-11-21"},
    ("comp_unl", "seas_unl_25"): {"id": "seas_unl_25", "name": "Nations League 2024-2025", "start_date": "2024-09-05", "end_date": "2025-06-08"},
    ("comp_ca24", "seas_ca24"): {"id": "seas_ca24", "name": "Copa America 2024", "start_date": "2024-06-20", "end_date": "2024-07-14"},
    ("comp_af23", "seas_af23"): {"id": "seas_af23", "name": "AFCON 2023", "start_date": "2024-01-13", "end_date": "2024-02-11"},
    ("comp_af25", "seas_af25"): {"id": "seas_af25", "name": "AFCON 2025", "start_date": "2025-12-21", "end_date": "2026-02-08"},
    ("comp_afq", "seas_afq_23"): {"id": "seas_afq_23", "name": "AFCON 2023 Qualifiers", "start_date": "2022-06-01", "end_date": "2023-09-12"},
    ("comp_cnl", "seas_cnl_24"): {"id": "seas_cnl_24", "name": "CNL 2024-2025", "start_date": "2024-09-05", "end_date": "2025-03-24"},
    ("comp_cnl", "seas_cnl_25"): {"id": "seas_cnl_25", "name": "CNL 2025-2026", "start_date": "2025-09-04", "end_date": "2026-03-24"},
    ("comp_ac23", "seas_ac23"): {"id": "seas_ac23", "name": "Asian Cup 2023", "start_date": "2024-01-12", "end_date": "2024-02-10"},
    ("comp_ofc", "seas_ofc_24"): {"id": "seas_ofc_24", "name": "OFC Nations Cup 2024", "start_date": "2024-06-15", "end_date": "2024-06-30"},
    ("comp_fri", "seas_fri_22"): {"id": "seas_fri_22", "name": "Friendlies 2022", "start_date": "2022-01-01", "end_date": "2022-12-31"},
    ("comp_fri", "seas_fri_23"): {"id": "seas_fri_23", "name": "Friendlies 2023", "start_date": "2023-01-01", "end_date": "2023-12-31"},
    ("comp_fri", "seas_fri_24"): {"id": "seas_fri_24", "name": "Friendlies 2024", "start_date": "2024-01-01", "end_date": "2024-12-31"},
    ("comp_fri", "seas_fri_25"): {"id": "seas_fri_25", "name": "Friendlies 2025", "start_date": "2025-01-01", "end_date": "2025-12-31"},
    ("comp_fri", "seas_fri_26"): {"id": "seas_fri_26", "name": "Friendlies 2026", "start_date": "2026-01-01", "end_date": "2026-12-31"},
    ("comp_e24p", "seas_e24q"): {"id": "seas_e24p_24", "name": "Euro 2024 Play-offs", "start_date": "2024-03-21", "end_date": "2024-03-26"},
    ("comp_ca24p", "seas_ca24q"): {"id": "seas_ca24p_24", "name": "Copa America 2024 Play-offs", "start_date": "2024-03-21", "end_date": "2024-03-26"},
    ("comp_unl23", "seas_unl23"): {"id": "seas_unl23", "name": "Nations League 2022-2023", "start_date": "2022-06-01", "end_date": "2023-06-18"},
    ("comp_cnl23", "seas_cnl23"): {"id": "seas_cnl23", "name": "CNL 2023-2024", "start_date": "2023-03-25", "end_date": "2023-03-28"},
    ("comp_agc", "seas_agc_23"): {"id": "seas_agc_23", "name": "Arabian Gulf Cup 2023", "start_date": "2023-01-06", "end_date": "2023-01-19"},
    ("comp_agc", "seas_agc23"): {"id": "seas_agc_23", "name": "Arabian Gulf Cup 2023", "start_date": "2023-01-06", "end_date": "2023-01-19"},
    ("comp_wcp", "seas_wc22"): {"id": "seas_wcp_22", "name": "2022 Play-offs", "start_date": "2022-06-14", "end_date": "2022-06-14"},
}

SEEDED_TEAMS: dict[str, dict[str, str]] = {
    "t_arg": {"name": "Argentina", "country": "Argentina", "team_type": "national_team"},
    "t_bra": {"name": "Brazil", "country": "Brazil", "team_type": "national_team"},
    "t_fra": {"name": "France", "country": "France", "team_type": "national_team"},
    "t_eng": {"name": "England", "country": "England", "team_type": "national_team"},
    "t_por": {"name": "Portugal", "country": "Portugal", "team_type": "national_team"},
    "t_esp": {"name": "Spain", "country": "Spain", "team_type": "national_team"},
    "t_bel": {"name": "Belgium", "country": "Belgium", "team_type": "national_team"},
    "t_ned": {"name": "Netherlands", "country": "Netherlands", "team_type": "national_team"},
    "t_ger": {"name": "Germany", "country": "Germany", "team_type": "national_team"},
    "t_ita": {"name": "Italy", "country": "Italy", "team_type": "national_team"},
    "t_cro": {"name": "Croatia", "country": "Croatia", "team_type": "national_team"},
    "t_sui": {"name": "Switzerland", "country": "Switzerland", "team_type": "national_team"},
    "t_den": {"name": "Denmark", "country": "Denmark", "team_type": "national_team"},
    "t_aut": {"name": "Austria", "country": "Austria", "team_type": "national_team"},
    "t_pol": {"name": "Poland", "country": "Poland", "team_type": "national_team"},
    "t_swe": {"name": "Sweden", "country": "Sweden", "team_type": "national_team"},
    "t_srb": {"name": "Serbia", "country": "Serbia", "team_type": "national_team"},
    "t_nor": {"name": "Norway", "country": "Norway", "team_type": "national_team"},
    "t_uru": {"name": "Uruguay", "country": "Uruguay", "team_type": "national_team"},
    "t_col": {"name": "Colombia", "country": "Colombia", "team_type": "national_team"},
    "t_ecu": {"name": "Ecuador", "country": "Ecuador", "team_type": "national_team"},
    "t_chi": {"name": "Chile", "country": "Chile", "team_type": "national_team"},
    "t_par": {"name": "Paraguay", "country": "Paraguay", "team_type": "national_team"},
    "t_mar": {"name": "Morocco", "country": "Morocco", "team_type": "national_team"},
    "t_sen": {"name": "Senegal", "country": "Senegal", "team_type": "national_team"},
    "t_nga": {"name": "Nigeria", "country": "Nigeria", "team_type": "national_team"},
    "t_egy": {"name": "Egypt", "country": "Egypt", "team_type": "national_team"},
    "t_ivc": {"name": "Ivory Coast", "country": "Ivory Coast", "team_type": "national_team"},
    "t_cmr": {"name": "Cameroon", "country": "Cameroon", "team_type": "national_team"},
    "t_alg": {"name": "Algeria", "country": "Algeria", "team_type": "national_team"},
    "t_tun": {"name": "Tunisia", "country": "Tunisia", "team_type": "national_team"},
    "t_mli": {"name": "Mali", "country": "Mali", "team_type": "national_team"},
    "t_rsa": {"name": "South Africa", "country": "South Africa", "team_type": "national_team"},
    "t_usa": {"name": "USA", "country": "USA", "team_type": "national_team"},
    "t_mex": {"name": "Mexico", "country": "Mexico", "team_type": "national_team"},
    "t_can": {"name": "Canada", "country": "Canada", "team_type": "national_team"},
    "t_pan": {"name": "Panama", "country": "Panama", "team_type": "national_team"},
    "t_crc": {"name": "Costa Rica", "country": "Costa Rica", "team_type": "national_team"},
    "t_jam": {"name": "Jamaica", "country": "Jamaica", "team_type": "national_team"},
    "t_jpn": {"name": "Japan", "country": "Japan", "team_type": "national_team"},
    "t_kor": {"name": "South Korea", "country": "South Korea", "team_type": "national_team"},
    "t_irn": {"name": "Iran", "country": "Iran", "team_type": "national_team"},
    "t_aus": {"name": "Australia", "country": "Australia", "team_type": "national_team"},
    "t_sau": {"name": "Saudi Arabia", "country": "Saudi Arabia", "team_type": "national_team"},
    "t_qat": {"name": "Qatar", "country": "Qatar", "team_type": "national_team"},
    "t_uzb": {"name": "Uzbekistan", "country": "Uzbekistan", "team_type": "national_team"},
    "t_irq": {"name": "Iraq", "country": "Iraq", "team_type": "national_team"},
    "t_nzl": {"name": "New Zealand", "country": "New Zealand", "team_type": "national_team"},
    "t_mci": {"name": "Manchester City", "country": "England", "team_type": "club"},
    "t_ars": {"name": "Arsenal", "country": "England", "team_type": "club"},
    "t_liv": {"name": "Liverpool", "country": "England", "team_type": "club"},
    "t_che": {"name": "Chelsea", "country": "England", "team_type": "club"},
    "t_tot": {"name": "Tottenham Hotspur", "country": "England", "team_type": "club"},
    "t_mun": {"name": "Manchester United", "country": "England", "team_type": "club"},
    "t_new": {"name": "Newcastle United", "country": "England", "team_type": "club"},
    "t_whu": {"name": "West Ham United", "country": "England", "team_type": "club"},
    "t_rma": {"name": "Real Madrid", "country": "Spain", "team_type": "club"},
    "t_bar": {"name": "Barcelona", "country": "Spain", "team_type": "club"},
    "t_atm": {"name": "Atletico Madrid", "country": "Spain", "team_type": "club"},
    "t_psg": {"name": "Paris Saint-Germain", "country": "France", "team_type": "club"},
    "t_om": {"name": "Marseille", "country": "France", "team_type": "club"},
    "t_bay": {"name": "Bayern Munich", "country": "Germany", "team_type": "club"},
    "t_dor": {"name": "Borussia Dortmund", "country": "Germany", "team_type": "club"},
    "t_lev": {"name": "Bayer Leverkusen", "country": "Germany", "team_type": "club"},
    "t_int": {"name": "Inter Milan", "country": "Italy", "team_type": "club"},
    "t_juv": {"name": "Juventus", "country": "Italy", "team_type": "club"},
    "t_mil": {"name": "AC Milan", "country": "Italy", "team_type": "club"},
    "t_nap": {"name": "Napoli", "country": "Italy", "team_type": "club"},
    "t_apr": {"name": "APR FC", "country": "Rwanda", "team_type": "club"},
    "t_ray": {"name": "Rayon Sports", "country": "Rwanda", "team_type": "club"},
    "t_ask": {"name": "AS Kigali", "country": "Rwanda", "team_type": "club"},
    "t_zes": {"name": "ZESCO United", "country": "Zambia", "team_type": "club"},
    "t_pow": {"name": "Power Dynamos", "country": "Zambia", "team_type": "club"},
    "t_maz": {"name": "TP Mazembe", "country": "DR Congo", "team_type": "club"},
    "t_vit": {"name": "AS Vita Club", "country": "DR Congo", "team_type": "club"},
    "t_lup": {"name": "St Eloi Lupopo", "country": "DR Congo", "team_type": "club"},
}

SEEDED_TEAM_ALIASES: dict[str, list[str]] = {
    "t_arg": ["La Albiceleste"],
    "t_bra": ["Selecao"],
    "t_fra": ["Les Bleus"],
    "t_eng": ["Three Lions"],
    "t_usa": ["United States", "USMNT"],
    "t_mex": ["El Tri"],
    "t_kor": ["Korea Republic"],
    "t_irn": ["IR Iran"],
    "t_rsa": ["Bafana Bafana"],
    "t_cmr": ["Indomitable Lions"],
    "t_ivc": ["Cote d'Ivoire", "Cote d Ivoire", "Côte d'Ivoire"],
    "t_mci": ["Man City", "Manchester City FC"],
    "t_ars": ["The Gunners"],
    "t_liv": ["The Reds"],
    "t_mun": ["Man Utd", "Manchester Utd"],
    "t_tot": ["Spurs", "Tottenham"],
    "t_new": ["Newcastle United"],
    "t_whu": ["West Ham United"],
    "t_rma": ["Real Madrid CF", "Los Blancos"],
    "t_bar": ["FC Barcelona", "Barca", "Barcelona FC"],
    "t_atm": ["Atletico", "Atletico Madrid", "Atlético Madrid"],
    "t_psg": ["PSG", "Paris SG"],
    "t_om": ["Olympique de Marseille"],
    "t_bay": ["FC Bayern", "Bayern Munchen"],
    "t_dor": ["BVB"],
    "t_lev": ["Leverkusen"],
    "t_int": ["Internazionale", "Inter"],
    "t_juv": ["Juve"],
    "t_mil": ["Milan"],
    "t_apr": ["Armee Patriotique Rwandaise FC"],
    "t_ray": ["Gikundiro"],
    "t_maz": ["Tout Puissant Mazembe"],
}

SEEDED_NAME_TO_TEAM_IDS: dict[str, set[str]] = defaultdict(set)
for team_id, meta in SEEDED_TEAMS.items():
    SEEDED_NAME_TO_TEAM_IDS[normalized_text(meta["name"])].add(team_id)
for team_id, aliases in SEEDED_TEAM_ALIASES.items():
    for alias in aliases:
        SEEDED_NAME_TO_TEAM_IDS[normalized_text(alias)].add(team_id)


def canonical_competition_id(row: dict[str, str]) -> str:
    competition_id = row["competition_id"].strip()
    season_id = row["season_id"].strip()

    if competition_id == "comp_laliga":
        return "comp_ll"
    if competition_id == "comp_agc23":
        return "comp_agc"
    if competition_id == "comp_wc22":
        return "comp_wc"
    if competition_id == "comp_wc22p":
        return "comp_wcp"
    if competition_id == "comp_wcq22":
        return "comp_wcq"
    if competition_id == "comp_uef":
        return "comp_e24q" if season_id.endswith("24") else "comp_wcq"
    return competition_id


def season_label_from_raw(raw_season_id: str) -> str:
    text = raw_season_id.strip().lower()
    four = re.search(r"(\d{4})$", text)
    if four and not four.group(1).startswith("20"):
        start = 2000 + int(four.group(1)[:2])
        end = 2000 + int(four.group(1)[2:])
        return f"{start}/{str(end)[2:]}"

    if four and four.group(1).startswith("20"):
        return four.group(1)

    two = re.search(r"(\d{2})$", text)
    if two:
        return str(2000 + int(two.group(1)))

    return text.upper()


def canonical_season_id(competition_id: str, raw_season_id: str) -> tuple[str, str]:
    override = SEEDED_SEASONS.get((competition_id, raw_season_id))
    if override:
        return override["id"], override["name"]
    label = season_label_from_raw(raw_season_id)
    return f"season:{competition_id}:{slugify(label)}", label


def preferred_source_name(values: Iterable[str]) -> str:
    cleaned = [value.strip() for value in values if value.strip()]
    if not cleaned:
        return "Matches - ALL.csv"
    ranked = Counter(cleaned).most_common()
    return ranked[0][0]


def team_namespace(spec: CompetitionSpec) -> str:
    if spec.team_scope == "national_team":
        return "national"
    return f"club:{slugify(spec.country)}"


def provisional_team_key(spec: CompetitionSpec, display_name: str) -> tuple[str, str]:
    namespace = team_namespace(spec)
    return namespace, slugify(display_name)


def final_team_key_for_generated(namespace: str, display_name: str) -> str:
    if namespace == "national":
        return f"team:national:{slugify(display_name)}"
    return f"team:{namespace}:{slugify(display_name)}"


def iter_batches(rows: list[dict[str, Any]], size: int = 500) -> Iterable[list[dict[str, Any]]]:
    for index in range(0, len(rows), size):
        yield rows[index:index + size]


def fetch_existing_rows(conn: psycopg.Connection[Any], table: str, columns: str) -> list[dict[str, Any]]:
    with conn.cursor(row_factory=dict_row) as cur:
        cur.execute(f"select {columns} from public.{table}")
        return list(cur.fetchall())


def choose_existing_team_match(
    candidate: ProvisionalTeam,
    existing_by_name: dict[str, list[dict[str, Any]]],
    existing_by_alias: dict[str, list[dict[str, Any]]],
    used_ids: set[str],
) -> dict[str, Any] | None:
    names_to_try = {normalized_text(candidate.preferred_display_name())}
    names_to_try.update(normalized_text(name) for name in candidate.display_names)

    candidates: list[dict[str, Any]] = []
    seen_ids: set[str] = set()
    for name in names_to_try:
        for row in existing_by_name.get(name, []):
            if row["id"] not in seen_ids:
                candidates.append(row)
                seen_ids.add(row["id"])
        for row in existing_by_alias.get(name, []):
            if row["id"] not in seen_ids:
                candidates.append(row)
                seen_ids.add(row["id"])

    if not candidates:
        return None

    filtered = [row for row in candidates if row["id"] not in used_ids]
    if not filtered:
        filtered = candidates

    if candidate.team_type == "national_team":
        national = [
            row for row in filtered
            if normalized_text(str(row.get("team_type") or "")) in {"national team", "national_team"}
        ]
        if len(national) == 1:
            return national[0]

    if candidate.country:
        country_matches = [
            row for row in filtered
            if normalized_text(str(row.get("country") or "")) == normalized_text(candidate.country or "")
        ]
        if len(country_matches) == 1:
            return country_matches[0]
        if country_matches:
            filtered = country_matches

    if len(filtered) == 1:
        return filtered[0]

    exact_name = normalized_text(candidate.preferred_display_name())
    exact = [row for row in filtered if normalized_text(str(row.get("name") or "")) == exact_name]
    if len(exact) == 1:
        return exact[0]

    return None


def choose_seeded_team_match(candidate: ProvisionalTeam) -> tuple[str, dict[str, str]] | None:
    names_to_try = {normalized_text(candidate.preferred_display_name())}
    names_to_try.update(normalized_text(name) for name in candidate.display_names)

    matches: set[str] = set()
    for name in names_to_try:
        matches.update(SEEDED_NAME_TO_TEAM_IDS.get(name, set()))

    if candidate.team_type == "national_team":
        matches = {
            team_id for team_id in matches
            if SEEDED_TEAMS[team_id]["team_type"] == "national_team"
        }
    else:
        matches = {
            team_id for team_id in matches
            if SEEDED_TEAMS[team_id]["team_type"] == "club"
            and normalized_text(SEEDED_TEAMS[team_id]["country"]) == normalized_text(candidate.country or "")
        }

    if len(matches) != 1:
        return None

    team_id = next(iter(matches))
    return team_id, SEEDED_TEAMS[team_id]


def build_dataset(
    csv_path: Path,
    existing_teams: list[dict[str, Any]],
    existing_competitions: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    rows = list(csv.DictReader(csv_path.open("r", encoding="utf-8-sig", newline="")))
    if not rows:
        raise ValueError("CSV is empty")

    provisional_teams: dict[tuple[str, str], ProvisionalTeam] = {}
    raw_rows: list[dict[str, Any]] = []
    audit = {
        "source_rows": len(rows),
        "skipped_blank_team_rows": 0,
        "skipped_stale_scheduled_rows": 0,
        "competition_alias_repairs": 0,
        "deduped_match_groups": 0,
    }
    today = datetime.now(timezone.utc).date()

    for row in rows:
        canonical_comp_id = canonical_competition_id(row)
        if canonical_comp_id != row["competition_id"].strip():
            audit["competition_alias_repairs"] += 1

        spec = COMPETITIONS.get(canonical_comp_id)
        if spec is None:
            raise KeyError(f"Unsupported competition id after canonicalization: {canonical_comp_id}")

        raw_season_id = row["season_id"].strip()
        season_override = SEEDED_SEASONS.get((canonical_comp_id, raw_season_id))
        season_id, season_label = canonical_season_id(canonical_comp_id, raw_season_id)
        match_date = parse_match_date(row["match_date"])
        stage = normalize_stage(row["stage"])
        round_label = normalize_round(row["matchday_or_round"], stage)
        status = normalize_status(row["match_status"])
        if status in {"scheduled", "live"} and match_date.date() < today:
            audit["skipped_stale_scheduled_rows"] += 1
            continue
        home_goals = nullable_int(row["home_goals"])
        away_goals = nullable_int(row["away_goals"])
        result_code = row["result_code"].strip() or compute_result_code(home_goals, away_goals) or ""

        home_name = row["home_team"].strip()
        away_name = row["away_team"].strip()
        if not home_name or not away_name:
            audit["skipped_blank_team_rows"] += 1
            continue

        home_ns_key = provisional_team_key(spec, home_name)
        away_ns_key = provisional_team_key(spec, away_name)

        home_team = provisional_teams.setdefault(
            home_ns_key,
            ProvisionalTeam(
                namespace=home_ns_key[0],
                raw_key=home_ns_key[1],
                team_type=spec.team_scope,
                country=home_name if spec.team_scope == "national_team" else spec.country,
            ),
        )
        away_team = provisional_teams.setdefault(
            away_ns_key,
            ProvisionalTeam(
                namespace=away_ns_key[0],
                raw_key=away_ns_key[1],
                team_type=spec.team_scope,
                country=away_name if spec.team_scope == "national_team" else spec.country,
            ),
        )

        home_team.display_names[home_name] += 1
        away_team.display_names[away_name] += 1
        if row["home_team_id"].strip():
            home_team.raw_ids[row["home_team_id"].strip()] += 1
        if row["away_team_id"].strip():
            away_team.raw_ids[row["away_team_id"].strip()] += 1
        home_team.competition_ids.add(canonical_comp_id)
        away_team.competition_ids.add(canonical_comp_id)
        home_team.regions[spec.region] += 1
        away_team.regions[spec.region] += 1

        raw_rows.append({
            "canonical_competition_id": canonical_comp_id,
            "season_id": season_id,
            "season_label": season_label,
            "raw_season_id": raw_season_id,
            "season_override": season_override,
            "match_date": match_date,
            "stage": stage,
            "round": round_label,
            "home_team_key": home_ns_key,
            "away_team_key": away_ns_key,
            "home_name": home_name,
            "away_name": away_name,
            "home_goals": home_goals,
            "away_goals": away_goals,
            "result_code": result_code or None,
            "status": status,
            "is_neutral": to_bool(row["is_neutral"]),
            "source_name": row["source_name"].strip(),
            "raw_match_id": row["match_id"].strip(),
        })

    existing_by_name: dict[str, list[dict[str, Any]]] = defaultdict(list)
    existing_by_alias: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in existing_teams:
        existing_by_name[normalized_text(str(row.get("name") or ""))].append(row)
        for alias in row.get("aliases") or []:
            existing_by_alias[normalized_text(str(alias))].append(row)

    used_existing_ids: set[str] = set()
    for provisional in provisional_teams.values():
        seeded = choose_seeded_team_match(provisional)
        if seeded:
            provisional.canonical_id = seeded[0]
            provisional.seeded_row = seeded[1]

        match = choose_existing_team_match(
            candidate=provisional,
            existing_by_name=existing_by_name,
            existing_by_alias=existing_by_alias,
            used_ids=used_existing_ids,
        )
        if match:
            provisional.existing_row = match
            used_existing_ids.add(str(match["id"]))
            if provisional.canonical_id is None:
                provisional.canonical_id = str(match["id"])

    final_teams: dict[str, FinalTeam] = {}
    final_team_lookup: dict[tuple[str, str], str] = {}
    unmatched_merge_keys: dict[tuple[str, str], str] = {}

    for provisional_key, provisional in provisional_teams.items():
        if provisional.canonical_id:
            final_id = provisional.canonical_id
        else:
            merge_key = (provisional.namespace, core_team_name(provisional.preferred_display_name()))
            if merge_key in unmatched_merge_keys:
                final_id = unmatched_merge_keys[merge_key]
            else:
                generated = final_team_key_for_generated(
                    provisional.namespace,
                    provisional.preferred_display_name(),
                )
                final_id = generated
                unmatched_merge_keys[merge_key] = generated

        final_team_lookup[provisional_key] = final_id
        final_team = final_teams.setdefault(
            final_id,
            FinalTeam(
                id=final_id,
                team_type=provisional.team_type,
                country=provisional.country,
                region=provisional.regions.most_common(1)[0][0] if provisional.regions else None,
                seeded_row=provisional.seeded_row,
                existing_row=provisional.existing_row,
            ),
        )
        if provisional.seeded_row and not final_team.seeded_row:
            final_team.seeded_row = provisional.seeded_row
        if provisional.existing_row and not final_team.existing_row:
            final_team.existing_row = provisional.existing_row
        final_team.display_names.update(provisional.display_names)
        final_team.raw_ids.update(provisional.raw_ids)
        final_team.competition_ids.update(provisional.competition_ids)

    competition_stats: dict[str, dict[str, Any]] = {}
    seasons: dict[str, dict[str, Any]] = {}
    match_groups: dict[tuple[str, str, str, str, str, str], list[dict[str, Any]]] = defaultdict(list)

    for raw in raw_rows:
        season = seasons.setdefault(
            raw["season_id"],
            {
                "id": raw["season_id"],
                "competition_id": raw["canonical_competition_id"],
                "season_label": raw["season_label"],
                "start_year": (
                    datetime.strptime(raw["season_override"]["start_date"], "%Y-%m-%d").year
                    if raw["season_override"] and raw["season_override"].get("start_date")
                    else raw["match_date"].year
                ),
                "end_year": (
                    datetime.strptime(raw["season_override"]["end_date"], "%Y-%m-%d").year
                    if raw["season_override"] and raw["season_override"].get("end_date")
                    else raw["match_date"].year
                ),
                "has_future": False,
                "max_date": raw["match_date"],
            },
        )
        season["start_year"] = min(season["start_year"], raw["match_date"].year)
        season["end_year"] = max(season["end_year"], raw["match_date"].year)
        season["max_date"] = max(season["max_date"], raw["match_date"])
        if raw["status"] in {"scheduled", "live"}:
            season["has_future"] = True

        competition = competition_stats.setdefault(
            raw["canonical_competition_id"],
            {
                "season_ids": set(),
                "team_ids": set(),
                "future_matches": 0,
            },
        )
        competition["season_ids"].add(raw["season_id"])
        competition["team_ids"].add(final_team_lookup[raw["home_team_key"]])
        competition["team_ids"].add(final_team_lookup[raw["away_team_key"]])
        if raw["status"] in {"scheduled", "live"}:
            competition["future_matches"] += 1

        group_key = (
            raw["canonical_competition_id"],
            raw["season_id"],
            raw["match_date"].date().isoformat(),
            final_team_lookup[raw["home_team_key"]],
            final_team_lookup[raw["away_team_key"]],
            normalized_text(raw["stage"]),
        )
        match_groups[group_key].append(raw)

    matches: list[dict[str, Any]] = []
    standings_rows: list[dict[str, Any]] = []
    for group_rows in match_groups.values():
        if len(group_rows) > 1:
            audit["deduped_match_groups"] += 1

        ordered = sorted(
            group_rows,
            key=lambda row: (
                row["status"] != "completed",
                row["raw_match_id"],
            ),
        )
        source_names = [row["source_name"] for row in ordered]
        home_goals = next((row["home_goals"] for row in ordered if row["home_goals"] is not None), None)
        away_goals = next((row["away_goals"] for row in ordered if row["away_goals"] is not None), None)
        status_rank = {"completed": 0, "live": 1, "scheduled": 2, "cancelled": 3}
        best_status = sorted(
            {row["status"] for row in ordered},
            key=lambda value: status_rank.get(value, 99),
        )[0]
        first = ordered[0]
        match_id = stable_hash(
            first["canonical_competition_id"],
            first["season_id"],
            first["match_date"].date().isoformat(),
            final_team_lookup[first["home_team_key"]],
            final_team_lookup[first["away_team_key"]],
            normalized_text(first["stage"]),
            prefix="match",
        )
        result_code = compute_result_code(home_goals, away_goals) if best_status == "completed" else None
        if not result_code:
            result_code = next((row["result_code"] for row in ordered if row["result_code"]), None)

        matches.append({
            "id": match_id,
            "competition_id": first["canonical_competition_id"],
            "season_id": first["season_id"],
            "stage": first["stage"],
            "matchday_or_round": first["round"],
            "match_date": first["match_date"],
            "home_team_id": final_team_lookup[first["home_team_key"]],
            "away_team_id": final_team_lookup[first["away_team_key"]],
            "home_goals": home_goals,
            "away_goals": away_goals,
            "result_code": result_code,
            "match_status": best_status,
            "is_neutral": any(row["is_neutral"] for row in ordered),
            "source_name": preferred_source_name(source_names),
            "source_url": None,
            "notes": None,
        })

    league_competitions = {
        comp_id for comp_id, spec in COMPETITIONS.items()
        if spec.competition_type == "league"
    }
    standings_input: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for match in matches:
        if (
            match["competition_id"] in league_competitions and
            match["match_status"] == "completed" and
            match["home_goals"] is not None and
            match["away_goals"] is not None
        ):
            standings_input[(match["competition_id"], match["season_id"])].append(match)

    team_names_by_id = {
        team.id: team.preferred_display_name()
        for team in final_teams.values()
    }

    for (competition_id, season_id), comp_matches in standings_input.items():
        table: dict[str, dict[str, Any]] = defaultdict(lambda: {
            "played": 0,
            "wins": 0,
            "draws": 0,
            "losses": 0,
            "goals_for": 0,
            "goals_against": 0,
            "points": 0,
        })
        for match in comp_matches:
            home_id = match["home_team_id"]
            away_id = match["away_team_id"]
            home_goals = int(match["home_goals"])
            away_goals = int(match["away_goals"])

            home_row = table[home_id]
            away_row = table[away_id]

            home_row["played"] += 1
            away_row["played"] += 1
            home_row["goals_for"] += home_goals
            home_row["goals_against"] += away_goals
            away_row["goals_for"] += away_goals
            away_row["goals_against"] += home_goals

            if home_goals > away_goals:
                home_row["wins"] += 1
                away_row["losses"] += 1
                home_row["points"] += 3
            elif away_goals > home_goals:
                away_row["wins"] += 1
                home_row["losses"] += 1
                away_row["points"] += 3
            else:
                home_row["draws"] += 1
                away_row["draws"] += 1
                home_row["points"] += 1
                away_row["points"] += 1

        snapshot_type = "current" if seasons[season_id]["has_future"] else "final"
        snapshot_date = seasons[season_id]["max_date"].date()
        ranked = sorted(
            table.items(),
            key=lambda item: (
                -item[1]["points"],
                -(item[1]["goals_for"] - item[1]["goals_against"]),
                -item[1]["goals_for"],
                team_names_by_id.get(item[0], item[0]).lower(),
            ),
        )
        for position, (team_id, stats) in enumerate(ranked, start=1):
            standings_rows.append({
                "competition_id": competition_id,
                "season_id": season_id,
                "snapshot_type": snapshot_type,
                "snapshot_date": snapshot_date,
                "team_id": team_id,
                "position": position,
                "played": stats["played"],
                "wins": stats["wins"],
                "draws": stats["draws"],
                "losses": stats["losses"],
                "goals_for": stats["goals_for"],
                "goals_against": stats["goals_against"],
                "goal_difference": stats["goals_for"] - stats["goals_against"],
                "points": stats["points"],
                "source_name": "derived_matches_all_csv",
                "source_url": None,
            })

    imported_competition_ids = sorted(competition_stats.keys())
    imported_team_ids = sorted(final_teams.keys())

    competitions_rows: list[dict[str, Any]] = []
    seasons_rows: list[dict[str, Any]] = []
    teams_rows: list[dict[str, Any]] = []
    team_alias_rows: list[dict[str, Any]] = []

    for competition_id in imported_competition_ids:
        spec = COMPETITIONS[competition_id]
        existing = existing_competitions.get(competition_id)
        current_seasons = [
            seasons[season_id]["season_label"]
            for season_id in sorted(competition_stats[competition_id]["season_ids"])
        ]
        competitions_rows.append({
            "id": competition_id,
            "name": spec.name,
            "short_name": spec.short_name,
            "country": spec.country,
            "tier": 1,
            "data_source": spec.data_source,
            "source_file": csv_path.name,
            "seasons": current_seasons,
            "team_count": len(competition_stats[competition_id]["team_ids"]),
            "season": current_seasons[-1] if current_seasons else None,
            "status": "active",
            "is_featured": bool(existing["is_featured"]) if existing else False,
            "region": spec.region,
            "competition_type": spec.competition_type,
            "event_tag": existing["event_tag"] if existing else None,
            "start_date": None,
            "end_date": None,
            "country_or_region": spec.country,
            "is_international": spec.is_international,
            "is_active": True,
            "updated_at": iso_now(),
        })

    for season in seasons.values():
        seasons_rows.append({
            "id": season["id"],
            "competition_id": season["competition_id"],
            "season_label": season["season_label"],
            "start_year": season["start_year"],
            "end_year": season["end_year"],
            "is_current": bool(season["has_future"] or season["max_date"].date() >= today),
            "updated_at": iso_now(),
        })

    alias_owners: dict[str, set[str]] = defaultdict(set)
    team_alias_candidates: dict[str, set[str]] = defaultdict(set)
    raw_id_owners: dict[str, set[str]] = defaultdict(set)
    seen_team_alias_pairs: set[tuple[str, str]] = set()

    for team in final_teams.values():
        display_name = team.preferred_display_name()
        seeded_meta = team.seeded_row or SEEDED_TEAMS.get(team.id)
        explicit_aliases = set(SEEDED_TEAM_ALIASES.get(team.id, []))
        team_row = {
            "id": team.id,
            "name": display_name,
            "short_name": (
                str(team.existing_row.get("short_name"))
                if team.existing_row and team.existing_row.get("short_name")
                else None
            ),
            "country": (
                seeded_meta["country"]
                if seeded_meta and seeded_meta.get("country")
                else str(team.existing_row.get("country"))
                if team.existing_row and team.existing_row.get("country")
                else team.country
            ),
            "competition_ids": sorted(team.competition_ids),
            "aliases": sorted({
                *(name for name in team.display_names if name != display_name),
                *explicit_aliases,
            }),
            "country_code": team.existing_row.get("country_code") if team.existing_row else None,
            "league_name": team.existing_row.get("league_name") if team.existing_row else None,
            "logo_url": team.existing_row.get("logo_url") if team.existing_row else None,
            "crest_url": team.existing_row.get("crest_url") if team.existing_row else None,
            "search_terms": sorted({
                display_name,
                normalized_text(display_name),
                *team.display_names.keys(),
                *explicit_aliases,
            }),
            "is_active": True,
            "is_featured": bool(team.existing_row["is_featured"]) if team.existing_row and "is_featured" in team.existing_row else False,
            "is_popular_pick": bool(team.existing_row["is_popular_pick"]) if team.existing_row and "is_popular_pick" in team.existing_row else False,
            "popular_pick_rank": team.existing_row.get("popular_pick_rank") if team.existing_row else None,
            "updated_at": iso_now(),
            "region": team.region,
            "description": team.existing_row.get("description") if team.existing_row else None,
            "cover_image_url": team.existing_row.get("cover_image_url") if team.existing_row else None,
            "fan_count": team.existing_row.get("fan_count") if team.existing_row else 0,
            "team_type": seeded_meta["team_type"] if seeded_meta else team.team_type,
        }
        teams_rows.append(team_row)

        aliases = {
            display_name,
            *(name for name in team.display_names if name),
            *explicit_aliases,
        }
        for alias in list(aliases):
            folded = (
                unicodedata.normalize("NFKD", alias)
                .encode("ascii", "ignore")
                .decode("ascii")
                .strip()
            )
            if folded and folded != alias:
                aliases.add(folded)
        for alias in aliases:
            if alias.strip():
                alias_owners[alias.strip().lower()].add(team.id)
                team_alias_candidates[team.id].add(alias.strip())

        for raw_id in team.raw_ids:
            raw_id_owners[raw_id.lower()].add(team.id)

    for team in final_teams.values():
        for alias in sorted(team_alias_candidates[team.id]):
            alias_key = (team.id, alias.lower())
            if len(alias_owners[alias.lower()]) == 1 and alias_key not in seen_team_alias_pairs:
                seen_team_alias_pairs.add(alias_key)
                team_alias_rows.append({
                    "team_id": team.id,
                    "alias_name": alias,
                    "source_name": "matches_all_csv",
                })

        for raw_id in sorted(team.raw_ids):
            alias_key = (team.id, raw_id.lower())
            if raw_id and len(raw_id_owners[raw_id.lower()]) == 1 and alias_key not in seen_team_alias_pairs:
                seen_team_alias_pairs.add(alias_key)
                team_alias_rows.append({
                    "team_id": team.id,
                    "alias_name": raw_id,
                    "source_name": "matches_all_csv_raw_id",
                })

    return {
        "audit": audit,
        "competitions": competitions_rows,
        "seasons": sorted(seasons_rows, key=lambda row: (row["competition_id"], row["start_year"], row["season_label"])),
        "teams": sorted(teams_rows, key=lambda row: row["name"].lower()),
        "team_aliases": team_alias_rows,
        "matches": sorted(matches, key=lambda row: (row["match_date"], row["competition_id"], row["stage"], row["home_team_id"])),
        "standings": standings_rows,
        "imported_competition_ids": imported_competition_ids,
        "imported_team_ids": imported_team_ids,
    }


def execute_many(conn: psycopg.Connection[Any], sql: str, rows: list[dict[str, Any]]) -> None:
    if not rows:
        return
    keys = list(rows[0].keys())
    query = sql.format(columns=", ".join(keys), placeholders=", ".join(f"%({key})s" for key in keys))
    with conn.cursor() as cur:
        for batch in iter_batches(rows):
            cur.executemany(query, batch)


def apply_dataset(conn: psycopg.Connection[Any], dataset: dict[str, Any]) -> dict[str, int]:
    imported_competition_ids = dataset["imported_competition_ids"]
    imported_team_ids = dataset["imported_team_ids"]

    with conn.cursor() as cur:
        cur.execute("begin")
        cur.execute("delete from public.predictions_engine_outputs")
        cur.execute("delete from public.team_form_features")
        cur.execute("delete from public.standings")
        cur.execute("delete from public.matches")
        cur.execute("delete from public.seasons")
        cur.execute("delete from public.team_aliases")

        execute_many(
            conn,
            """
            insert into public.competitions ({columns})
            values ({placeholders})
            on conflict (id) do update set
              name = excluded.name,
              short_name = excluded.short_name,
              country = excluded.country,
              tier = excluded.tier,
              data_source = excluded.data_source,
              source_file = excluded.source_file,
              seasons = excluded.seasons,
              team_count = excluded.team_count,
              season = excluded.season,
              status = excluded.status,
              is_featured = excluded.is_featured,
              region = excluded.region,
              competition_type = excluded.competition_type,
              event_tag = excluded.event_tag,
              start_date = excluded.start_date,
              end_date = excluded.end_date,
              country_or_region = excluded.country_or_region,
              is_international = excluded.is_international,
              is_active = excluded.is_active,
              updated_at = excluded.updated_at
            """,
            dataset["competitions"],
        )

        execute_many(
            conn,
            """
            insert into public.teams ({columns})
            values ({placeholders})
            on conflict (id) do update set
              name = excluded.name,
              short_name = coalesce(excluded.short_name, public.teams.short_name),
              country = coalesce(excluded.country, public.teams.country),
              competition_ids = excluded.competition_ids,
              aliases = excluded.aliases,
              country_code = coalesce(excluded.country_code, public.teams.country_code),
              league_name = coalesce(excluded.league_name, public.teams.league_name),
              logo_url = coalesce(excluded.logo_url, public.teams.logo_url),
              crest_url = coalesce(excluded.crest_url, public.teams.crest_url),
              search_terms = excluded.search_terms,
              is_active = excluded.is_active,
              is_featured = excluded.is_featured,
              is_popular_pick = excluded.is_popular_pick,
              popular_pick_rank = excluded.popular_pick_rank,
              updated_at = excluded.updated_at,
              region = coalesce(excluded.region, public.teams.region),
              description = coalesce(excluded.description, public.teams.description),
              cover_image_url = coalesce(excluded.cover_image_url, public.teams.cover_image_url),
              fan_count = greatest(coalesce(public.teams.fan_count, 0), coalesce(excluded.fan_count, 0)),
              team_type = excluded.team_type
            """,
            dataset["teams"],
        )

        execute_many(
            conn,
            """
            insert into public.seasons ({columns})
            values ({placeholders})
            on conflict (id) do update set
              competition_id = excluded.competition_id,
              season_label = excluded.season_label,
              start_year = excluded.start_year,
              end_year = excluded.end_year,
              is_current = excluded.is_current,
              updated_at = excluded.updated_at
            """,
            dataset["seasons"],
        )

        execute_many(
            conn,
            """
            insert into public.team_aliases ({columns})
            values ({placeholders})
            on conflict (team_id, alias_name) do update set
              source_name = excluded.source_name
            """,
            dataset["team_aliases"],
        )

        execute_many(
            conn,
            """
            insert into public.matches ({columns})
            values ({placeholders})
            on conflict (id) do update set
              competition_id = excluded.competition_id,
              season_id = excluded.season_id,
              stage = excluded.stage,
              matchday_or_round = excluded.matchday_or_round,
              match_date = excluded.match_date,
              home_team_id = excluded.home_team_id,
              away_team_id = excluded.away_team_id,
              home_goals = excluded.home_goals,
              away_goals = excluded.away_goals,
              result_code = excluded.result_code,
              match_status = excluded.match_status,
              is_neutral = excluded.is_neutral,
              source_name = excluded.source_name,
              source_url = excluded.source_url,
              notes = excluded.notes,
              updated_at = now()
            """,
            dataset["matches"],
        )

        execute_many(
            conn,
            """
            insert into public.standings ({columns})
            values ({placeholders})
            on conflict (competition_id, season_id, snapshot_type, snapshot_date, team_id) do update set
              position = excluded.position,
              played = excluded.played,
              wins = excluded.wins,
              draws = excluded.draws,
              losses = excluded.losses,
              goals_for = excluded.goals_for,
              goals_against = excluded.goals_against,
              goal_difference = excluded.goal_difference,
              points = excluded.points,
              source_name = excluded.source_name,
              source_url = excluded.source_url,
              updated_at = now()
            """,
            dataset["standings"],
        )

        cur.execute(
            """
            update public.competitions
            set is_active = false, status = 'inactive', updated_at = now()
            where id <> all(%s)
            """,
            (imported_competition_ids,),
        )

        cur.execute(
            """
            update public.teams
            set is_active = false, updated_at = now()
            where id <> all(%s)
            """,
            (imported_team_ids,),
        )

        cur.execute("select public.generate_predictions_for_upcoming_matches(1000)")
        generated_row = cur.fetchone()
        if isinstance(generated_row, dict):
            generated_predictions = next(iter(generated_row.values()))
        else:
            generated_predictions = generated_row[0]
        cur.execute("commit")

    return {
        "competitions": len(dataset["competitions"]),
        "seasons": len(dataset["seasons"]),
        "teams": len(dataset["teams"]),
        "team_aliases": len(dataset["team_aliases"]),
        "matches": len(dataset["matches"]),
        "standings": len(dataset["standings"]),
        "generated_predictions": int(generated_predictions or 0),
    }


def build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Normalize Matches - ALL.csv into the lean prediction schema and optionally load it into Supabase.",
    )
    parser.add_argument("--csv", required=True, help="Path to Matches - ALL.csv")
    parser.add_argument("--db-url", help="Postgres connection string for the target Supabase database")
    parser.add_argument("--apply", action="store_true", help="Write the normalized dataset into the target database")
    parser.add_argument("--report-json", help="Optional path to write a JSON report")
    return parser


def main() -> int:
    args = build_argument_parser().parse_args()
    csv_path = Path(args.csv).expanduser()
    if not csv_path.exists():
        print(f"CSV not found: {csv_path}", file=sys.stderr)
        return 1

    if args.apply and not args.db_url:
        print("--db-url is required when --apply is set", file=sys.stderr)
        return 1

    conn = psycopg.connect(args.db_url, row_factory=dict_row) if args.db_url else None
    try:
        existing_teams = fetch_existing_rows(
            conn,
            "teams",
            "id, name, country, team_type, short_name, logo_url, crest_url, aliases, country_code, league_name, is_featured, is_popular_pick, popular_pick_rank, description, cover_image_url, fan_count",
        ) if conn else []
        existing_competitions_rows = fetch_existing_rows(
            conn,
            "competitions",
            "id, is_featured, event_tag",
        ) if conn else []
        existing_competitions = {
            str(row["id"]): row for row in existing_competitions_rows
        }

        dataset = build_dataset(
            csv_path=csv_path,
            existing_teams=existing_teams,
            existing_competitions=existing_competitions,
        )

        report = {
            "csv": str(csv_path),
            "audit": dataset["audit"],
            "counts": {
                "competitions": len(dataset["competitions"]),
                "seasons": len(dataset["seasons"]),
                "teams": len(dataset["teams"]),
                "team_aliases": len(dataset["team_aliases"]),
                "matches": len(dataset["matches"]),
                "standings": len(dataset["standings"]),
            },
        }

        if args.apply:
            summary = apply_dataset(conn, dataset)
            report["applied"] = summary

        if args.report_json:
            report_path = Path(args.report_json).expanduser()
            report_path.parent.mkdir(parents=True, exist_ok=True)
            report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

        print(json.dumps(report, indent=2))
    finally:
        if conn:
            conn.close()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

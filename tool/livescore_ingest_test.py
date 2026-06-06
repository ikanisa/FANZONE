#!/usr/bin/env python3
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))

import livescore_ingest as ingest


class LiveScoreIngestTest(unittest.TestCase):
    def test_fetch_fixture_rows_stores_utc_starts_at_and_preserves_local_time(self):
        original_http_json = ingest.http_json

        def fake_http_json(url, *, user_agent, timeout):
            self.assertIn("/competition/734/fixtures-w/", url)
            return {
                "CompN": "World Cup 2026",
                "CompId": "734",
                "Stages": [
                    {
                        "Snm": "Group A",
                        "Events": [
                            {
                                "Eid": "1417909",
                                "Esd": 20260611210000,
                                "Eps": "NS",
                                "T1": [{"ID": "9025", "Nm": "Mexico"}],
                                "T2": [{"ID": "9287", "Nm": "South Africa"}],
                            }
                        ],
                    }
                ],
            }

        ingest.http_json = fake_http_json
        try:
            resource = ingest.LiveScoreResource(
                resource_id="livescore_world_cup_2026",
                provider_competition_id="734",
                competition_slug="world-cup-2026",
                category_slug="international",
                competition_id="fifa_world_cup",
                season_id="fifa_world_cup_2026",
                timezone_name="Africa/Kigali",
                locale="en",
                limit=200,
            )

            rows, _ = ingest.fetch_fixture_rows(
                resource,
                include_details=False,
                include_scoreboard=False,
                delay_ms=0,
                timeout=5,
                user_agent="test-agent",
            )
        finally:
            ingest.http_json = original_http_json

        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["starts_at"], "2026-06-11T19:00:00Z")
        self.assertEqual(rows[0]["local_date"], "2026-06-11")
        self.assertEqual(rows[0]["local_time"], "21:00:00")
        self.assertEqual(rows[0]["timezone_name"], "Africa/Kigali")


if __name__ == "__main__":
    unittest.main()

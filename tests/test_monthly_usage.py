import importlib.util
import io
import json
import tempfile
import unittest
from contextlib import redirect_stdout
from datetime import date, datetime, timedelta
from pathlib import Path
from unittest import mock


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "opencode-usage.1m.py"
SPEC = importlib.util.spec_from_file_location("xbar_ai_usage", SCRIPT_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class MonthlyUsageTests(unittest.TestCase):
    def test_new_stats_has_current_and_previous_month_buckets(self):
        stats = MODULE.new_stats()

        self.assertIn("month", stats)
        self.assertIn("previous_month", stats)

    def test_month_offset_handles_year_boundary(self):
        now = date(2026, 1, 1)

        self.assertTrue(MODULE.is_month_offset(date(2026, 1, 1), now, 0))
        self.assertTrue(MODULE.is_month_offset(date(2025, 12, 31), now, -1))
        self.assertFalse(MODULE.is_month_offset(date(2025, 11, 30), now, -1))

    def test_update_prompt_only_accepts_newer_versions(self):
        self.assertTrue(MODULE.is_newer_version("2.14.0", "2.13.0"))
        self.assertFalse(MODULE.is_newer_version("2.12.0", "2.13.0"))
        self.assertFalse(MODULE.is_newer_version("2.13.0", "2.13.0"))

    def test_has_usage_includes_previous_month_only_stats(self):
        stats = MODULE.new_stats()
        stats["previous_month"]["t"] = 42

        self.assertTrue(MODULE.has_usage(stats))

    def test_pi_stats_include_all_usage_entry_types_and_deduplicate_clones(self):
        now = datetime(2026, 8, 17, 12, 0, 0)
        today_ms = int(now.timestamp() * 1000)
        six_days_ago_ms = int((now - timedelta(days=6)).timestamp() * 1000)
        previous_month_timestamp = "2026-07-31T12:00:00Z"
        assistant_entry = {
            "type": "message",
            "id": "assistant-1",
            "timestamp": "2026-08-17T12:00:00Z",
            "message": {
                "role": "assistant",
                "model": "gpt-5.6-sol",
                "timestamp": today_ms,
                "usage": {
                    "input": 100,
                    "output": 20,
                    "cacheRead": 30,
                    "cacheWrite": 5,
                    "reasoning": 7,
                    "totalTokens": 155,
                },
            },
        }
        tool_entry = {
            "type": "message",
            "id": "tool-1",
            "timestamp": "2026-08-11T12:00:00Z",
            "message": {
                "role": "toolResult",
                "timestamp": six_days_ago_ms,
                "usage": {
                    "input": 10,
                    "output": 2,
                    "cacheRead": 3,
                    "cacheWrite": 0,
                    "totalTokens": 15,
                },
            },
        }
        compaction_entry = {
            "type": "compaction",
            "id": "compaction-1",
            "timestamp": previous_month_timestamp,
            "usage": {
                "input": 8,
                "output": 2,
                "cacheRead": 0,
                "cacheWrite": 0,
                "totalTokens": 10,
            },
        }
        branch_summary_entry = {
            "type": "branch_summary",
            "id": "branch-summary-1",
            "timestamp": "2026-08-01T12:00:00Z",
            "usage": {
                "input": 5,
                "output": 1,
                "cacheRead": 0,
                "cacheWrite": 0,
                "totalTokens": 6,
            },
        }

        with tempfile.TemporaryDirectory() as temp_dir:
            project_dir = Path(temp_dir) / "project"
            project_dir.mkdir()
            first_session = project_dir / "first.jsonl"
            cloned_session = project_dir / "clone.jsonl"
            entries = [assistant_entry, tool_entry, compaction_entry, branch_summary_entry]
            first_session.write_text("\n".join(json.dumps(entry) for entry in entries))
            cloned_session.write_text(json.dumps(assistant_entry))

            stats = MODULE.get_pi_stats(temp_dir, now=now)

        self.assertEqual(stats["today"], {"t": 155, "i": 100, "o": 20, "c": 35, "r": 7})
        self.assertEqual(stats["d7"]["t"], 170)
        self.assertEqual(stats["d30"]["t"], 186)
        self.assertEqual(stats["month"]["t"], 176)
        self.assertEqual(stats["previous_month"]["t"], 10)
        self.assertEqual(stats["model"], "gpt-5.6-sol")

    def test_main_renders_pi_section_and_includes_pi_in_month_total(self):
        empty = MODULE.new_stats()
        pi = MODULE.new_stats()
        pi["today"].update({"t": 155, "i": 100, "o": 20, "c": 35, "r": 7})
        pi["month"]["t"] = 200
        pi["model"] = "gpt-5.6-sol"

        output = io.StringIO()
        with mock.patch.object(MODULE, "get_oc_stats", return_value=empty), \
             mock.patch.object(MODULE, "get_qwen_stats", return_value=empty), \
             mock.patch.object(MODULE, "get_codex_stats", return_value=empty), \
             mock.patch.object(MODULE, "get_pi_stats", return_value=pi), \
             mock.patch.object(MODULE, "get_claude_stats", return_value=empty), \
             mock.patch.object(MODULE, "get_latest_version", return_value=None), \
             redirect_stdout(output):
            MODULE.main()

        menu = output.getvalue()
        self.assertTrue(menu.startswith("AI Mo 200\n"))
        self.assertIn("Pi | color=#ab47bc", menu)
        self.assertIn("--Total: 155", menu)
        self.assertIn("--Model: gpt-5.6-sol", menu)


if __name__ == "__main__":
    unittest.main()

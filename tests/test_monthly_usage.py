import importlib.util
import unittest
from datetime import date
from pathlib import Path


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


if __name__ == "__main__":
    unittest.main()

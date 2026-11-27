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
assert SPEC is not None
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
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

    def test_format_count_uses_billion_suffix(self):
        self.assertEqual(MODULE.format_count(999_999_999), "1000.0M")
        self.assertEqual(MODULE.format_count(1_000_000_000), "1.0B")
        self.assertEqual(MODULE.format_count(69_253_000_000), "69.3B")

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

        # toolResult messages are not counted (only assistant / compaction / branch_summary),
        # so the 7-day window equals today's assistant entry; reasoning is included in the total.
        self.assertEqual(stats["today"], {"t": 162, "i": 100, "o": 20, "c": 35, "r": 7})
        self.assertEqual(stats["d7"]["t"], 162)
        self.assertEqual(stats["d30"]["t"], 178)
        self.assertEqual(stats["month"]["t"], 168)
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
             mock.patch.object(MODULE, "get_antigravity_stats", return_value=empty), \
             mock.patch.object(MODULE, "get_latest_version", return_value=None), \
             redirect_stdout(output):
            MODULE.main()

        menu = output.getvalue()
        self.assertTrue(menu.startswith("AI Mo 200\n"))
        self.assertIn("Pi / omp | color=#ab47bc", menu)
        self.assertIn("--Total: 155", menu)
        self.assertIn("--Model: gpt-5.6-sol", menu)

    def test_pi_stats_merges_pi_and_omp_session_dirs(self):
        import os as _os

        now = datetime(2026, 8, 17, 12, 0, 0)
        pi_entry = {
            "type": "message",
            "id": "pi-1",
            "timestamp": "2026-08-17T10:00:00Z",
            "message": {
                "role": "assistant",
                "model": "gpt-5.6-sol",
                "timestamp": int(now.timestamp() * 1000),
                "usage": {"input": 100, "output": 20, "cacheRead": 0, "cacheWrite": 0, "totalTokens": 120},
            },
        }
        omp_entry = {
            "type": "message",
            "id": "omp-1",
            "timestamp": "2026-08-17T11:00:00Z",
            "message": {
                "role": "assistant",
                "model": "agnes-flash",
                "timestamp": int(now.timestamp() * 1000),
                "usage": {"input": 10, "output": 2, "cacheRead": 0, "cacheWrite": 0, "totalTokens": 12},
            },
        }

        with tempfile.TemporaryDirectory() as temp_dir:
            pi_dir = Path(temp_dir) / "pi"
            omp_dir = Path(temp_dir) / "omp"
            pi_dir.mkdir()
            omp_dir.mkdir()
            (pi_dir / "pi.jsonl").write_text(json.dumps(pi_entry))
            # omp holds its own entry plus a forked copy of pi's entry (same identity).
            forked_pi = dict(pi_entry)
            (omp_dir / "omp.jsonl").write_text("\n".join([json.dumps(omp_entry), json.dumps(forked_pi)]))

            env = {
                "PI_CODING_AGENT_SESSION_DIR": str(pi_dir),
                "OMP_CODING_AGENT_SESSION_DIR": str(omp_dir),
            }
            with mock.patch.dict(_os.environ, env):
                stats = MODULE.get_pi_stats(now=now)

        # The forked copy of pi-1 must be counted once, so today == pi-1 + omp-1 only.
        self.assertEqual(stats["today"], {"t": 132, "i": 110, "o": 22, "c": 0, "r": 0})
        self.assertEqual(stats["model"], "agnes-flash")

    def test_pi_stats_missing_dirs_dont_crash_or_double_count(self):
        import os as _os

        now = datetime(2026, 8, 17, 12, 0, 0)
        omp_entry = {
            "type": "message",
            "id": "omp-1",
            "timestamp": "2026-08-17T11:00:00Z",
            "message": {
                "role": "assistant",
                "model": "agnes-flash",
                "timestamp": int(now.timestamp() * 1000),
                "usage": {"input": 10, "output": 2, "totalTokens": 12},
            },
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            omp_dir = Path(temp_dir) / "omp"
            omp_dir.mkdir()
            (omp_dir / "omp.jsonl").write_text(json.dumps(omp_entry))

            env = {
                "PI_CODING_AGENT_SESSION_DIR": str(Path(temp_dir) / "missing-pi"),
                "OMP_CODING_AGENT_SESSION_DIR": str(omp_dir),
            }
            with mock.patch.dict(_os.environ, env):
                stats = MODULE.get_pi_stats(now=now)

        self.assertEqual(stats["today"], {"t": 12, "i": 10, "o": 2, "c": 0, "r": 0})
        self.assertEqual(stats["model"], "agnes-flash")

    @staticmethod
    def _ag_entry(step, ts, i, o, c=0, model=None, type_="PLANNER_RESPONSE"):
        entry = {"step_index": step, "source": "MODEL", "type": type_, "status": "DONE",
                 "created_at": ts, "input_tokens": i, "cache_read_tokens": c, "output_tokens": o}
        if model:
            entry["model"] = model
        return entry

    @staticmethod
    def _write_ag_transcript(brain_dir, conv_id, entries):
        logs = Path(brain_dir) / conv_id / ".system_generated" / "logs"
        logs.mkdir(parents=True, exist_ok=True)
        (logs / "transcript.jsonl").write_text("\n".join(json.dumps(e) for e in entries))

    def test_antigravity_stats_parses_planner_and_checkpoint_and_deduplicates(self):
        now = datetime(2026, 8, 17, 12, 0, 0)
        entries = [
            {"step_index": 0, "source": "USER_EXPLICIT", "type": "USER_INPUT", "created_at": "2026-08-17T12:00:00Z"},
            self._ag_entry(1, "2026-08-17T12:00:00Z", 100, 20, 30, model="gemini-4-neon-high"),
            self._ag_entry(2, "2026-08-11T12:00:00Z", 10, 2, 3, type_="CHECKPOINT"),
            self._ag_entry(3, "2026-07-31T12:00:00Z", 8, 2, 0, model="gemini-4-carbon-low"),
            self._ag_entry(4, "2026-07-01T12:00:00Z", 5, 1, 0),
        ]
        with tempfile.TemporaryDirectory() as temp_dir:
            desktop = Path(temp_dir) / "desktop"
            cli = Path(temp_dir) / "cli"
            self._write_ag_transcript(desktop, "conv-1", entries)
            # Same conversation copied into another directory must be counted once.
            self._write_ag_transcript(cli, "conv-1", entries)

            stats = MODULE.get_antigravity_stats([desktop, cli], now=now)

        self.assertEqual(stats["today"], {"t": 150, "i": 100, "o": 20, "c": 30, "r": 0})
        self.assertEqual(stats["d7"]["t"], 165)
        self.assertEqual(stats["d30"]["t"], 175)
        self.assertEqual(stats["month"]["t"], 165)
        self.assertEqual(stats["previous_month"]["t"], 16)
        self.assertEqual(stats["model"], "gemini-4-neon-high")
        self.assertIsNone(stats["plan_model"])
        self.assertIsNone(stats["execute_model"])

    def test_antigravity_stats_merges_desktop_and_cli_dirs_and_handles_missing_dir(self):
        import os as _os

        now = datetime(2026, 8, 17, 12, 0, 0)
        with tempfile.TemporaryDirectory() as temp_dir:
            desktop = Path(temp_dir) / "desktop"
            cli = Path(temp_dir) / "cli"
            self._write_ag_transcript(desktop, "d1", [self._ag_entry(1, "2026-08-17T10:00:00Z", 100, 20, model="gemini-4-neon-high")])
            env = {
                "ANTIGRAVITY_BRAIN_DIR": str(desktop),
                "ANTIGRAVITY_CLI_BRAIN_DIR": str(cli),
            }
            with mock.patch.dict(_os.environ, env):
                missing = MODULE.get_antigravity_stats(now=now)
                self._write_ag_transcript(cli, "c1", [self._ag_entry(1, "2026-08-17T11:00:00Z", 10, 2, 5, model="claude-opus-5-5-medium")])
                merged = MODULE.get_antigravity_stats(now=now)

        self.assertEqual(missing["today"], {"t": 120, "i": 100, "o": 20, "c": 0, "r": 0})
        self.assertEqual(merged["today"], {"t": 137, "i": 110, "o": 22, "c": 5, "r": 0})
        self.assertEqual(merged["model"], "claude-opus-5-5-medium")

    def test_main_renders_antigravity_section_and_includes_in_month_total(self):
        empty = MODULE.new_stats()
        ag = MODULE.new_stats()
        ag["today"].update({"t": 155, "i": 100, "o": 20, "c": 35, "r": 0})
        ag["month"]["t"] = 300
        ag["model"] = "gemini-4-neon-high"

        output = io.StringIO()
        with mock.patch.object(MODULE, "get_oc_stats", return_value=empty), \
             mock.patch.object(MODULE, "get_qwen_stats", return_value=empty), \
             mock.patch.object(MODULE, "get_codex_stats", return_value=empty), \
             mock.patch.object(MODULE, "get_pi_stats", return_value=empty), \
             mock.patch.object(MODULE, "get_claude_stats", return_value=empty), \
             mock.patch.object(MODULE, "get_antigravity_stats", return_value=ag), \
             mock.patch.object(MODULE, "get_latest_version", return_value=None), \
             redirect_stdout(output):
            MODULE.main()

        menu = output.getvalue()
        self.assertTrue(menu.startswith("AI Mo 300\n"))
        self.assertIn("Antigravity | color=#26a69a", menu)
        self.assertIn("--Total: 155", menu)
        self.assertIn("--Output: 20", menu)
        self.assertIn("--Cache: 35", menu)
        self.assertIn("--Model: gemini-4-neon-high", menu)
        self.assertNotIn("Plan Model:", menu)
        self.assertNotIn("Execute Model:", menu)

    def test_antigravity_stats_splits_plan_and_execute_models_only_when_present(self):
        now = datetime(2026, 8, 17, 12, 0, 0)

        def user(step, ts):
            return {"step_index": step, "source": "USER_EXPLICIT", "type": "USER_INPUT", "created_at": ts}

        plan_exit = self._ag_entry(1, "2026-08-17T12:00:01Z", 10, 2, model="gemini-4-neon-high")
        plan_exit["tool_calls"] = [{"name": "exit_plan_mode"}]
        sysmsg = {"step_index": 2, "source": "SYSTEM", "type": "SYSTEM_MESSAGE", "created_at": "2026-08-17T12:00:02Z",
                  "content": "Plan mode is off: this turn runs on the execution model"}
        plan_exec = [
            user(0, "2026-08-17T12:00:00Z"),
            plan_exit,
            sysmsg,
            self._ag_entry(3, "2026-08-17T12:00:03Z", 10, 2, model="claude-sonnet-5-5-high"),
            user(4, "2026-08-17T12:00:04Z"),
            self._ag_entry(5, "2026-08-17T12:00:05Z", 10, 2, model="gemini-4-neon-high"),
        ]
        with tempfile.TemporaryDirectory() as temp_dir:
            brain = Path(temp_dir) / "brain"
            self._write_ag_transcript(brain, "conv-pe", plan_exec)
            stats = MODULE.get_antigravity_stats([brain], now=now)
            self.assertEqual(stats["plan_model"], "gemini-4-neon-high")
            self.assertEqual(stats["execute_model"], "claude-sonnet-5-5-high")
            self.assertEqual(stats["model"], "gemini-4-neon-high")

            # A newer conversation without Plan/Execute hides the split.
            self._write_ag_transcript(brain, "conv-plain", [self._ag_entry(1, "2026-08-17T13:00:00Z", 5, 1, model="gemini-4-carbon-high")])
            stats = MODULE.get_antigravity_stats([brain], now=now)
            self.assertEqual(stats["model"], "gemini-4-carbon-high")
            self.assertIsNone(stats["plan_model"])
            self.assertIsNone(stats["execute_model"])

    def test_main_renders_antigravity_plan_and_execute_models(self):
        empty = MODULE.new_stats()
        ag = MODULE.new_stats()
        ag["today"].update({"t": 155, "i": 100, "o": 20, "c": 35, "r": 0})
        ag["month"]["t"] = 300
        ag["model"] = "gemini-4-neon-high"
        ag["plan_model"] = "gemini-4-neon-high"
        ag["execute_model"] = "claude-sonnet-5-5-high"

        output = io.StringIO()
        with mock.patch.object(MODULE, "get_oc_stats", return_value=empty), \
             mock.patch.object(MODULE, "get_qwen_stats", return_value=empty), \
             mock.patch.object(MODULE, "get_codex_stats", return_value=empty), \
             mock.patch.object(MODULE, "get_pi_stats", return_value=empty), \
             mock.patch.object(MODULE, "get_claude_stats", return_value=empty), \
             mock.patch.object(MODULE, "get_antigravity_stats", return_value=ag), \
             mock.patch.object(MODULE, "get_latest_version", return_value=None), \
             redirect_stdout(output):
            MODULE.main()

        menu = output.getvalue()
        self.assertIn("--Plan Model: gemini-4-neon-high", menu)
        self.assertIn("--Execute Model: claude-sonnet-5-5-high", menu)
        self.assertNotIn("--Model:", menu)


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Install this repository's xbar AI usage plugin."""

from __future__ import annotations

import argparse
import os
import shutil
import stat
from pathlib import Path


def find_repo_root(start: Path) -> Path:
    for path in [start, *start.parents]:
        if (path / "opencode-usage.1m.py").exists():
            return path
    raise SystemExit("Could not find opencode-usage.1m.py from the current path.")


def main() -> int:
    parser = argparse.ArgumentParser(description="Install opencode-usage.1m.py into xbar plugins.")
    parser.add_argument("--dry-run", action="store_true", help="Print planned actions without writing files.")
    parser.add_argument(
        "--plugin-dir",
        default=str(Path.home() / "Library/Application Support/xbar/plugins"),
        help="xbar plugin directory.",
    )
    args = parser.parse_args()

    repo_root = find_repo_root(Path(__file__).resolve())
    source = repo_root / "opencode-usage.1m.py"
    plugin_dir = Path(os.path.expanduser(args.plugin_dir))
    target = plugin_dir / source.name
    backup = target.with_name(target.name + ".bak.off")

    print(f"source: {source}")
    print(f"target: {target}")

    if args.dry_run:
        if target.exists():
            print(f"would backup existing target to: {backup}")
        print("would create plugin directory if needed")
        print("would copy plugin and mark it executable")
        return 0

    plugin_dir.mkdir(parents=True, exist_ok=True)
    if target.exists():
        shutil.copy2(target, backup)
        print(f"backup: {backup}")

    shutil.copy2(source, target)
    mode = target.stat().st_mode
    target.chmod(mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    print(f"installed: {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

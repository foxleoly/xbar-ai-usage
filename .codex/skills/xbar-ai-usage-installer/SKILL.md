---
name: xbar-ai-usage-installer
description: Install, update, or verify this repository's xbar AI token usage plugin for Qwen Code, Codex, Claude Code, and OpenCode on macOS. Use when the user asks to install the widget, deploy the xbar script, refresh the menu bar plugin, or check that the local plugin is wired to the current repository version.
---

# xbar AI Usage Installer

Use this skill for this repository's xbar/SwiftBar token usage widget.

## Workflow

1. Confirm the repository root contains `opencode-usage.1m.py`.
2. Run a dry-run first:

   ```bash
   python3 .codex/skills/xbar-ai-usage-installer/scripts/install_xbar_plugin.py --dry-run
   ```

3. If the dry-run target is correct and the user wants installation, run:

   ```bash
   python3 .codex/skills/xbar-ai-usage-installer/scripts/install_xbar_plugin.py
   ```

4. Verify:

   ```bash
   ls -l "$HOME/Library/Application Support/xbar/plugins/opencode-usage.1m.py"
   python3 "$HOME/Library/Application Support/xbar/plugins/opencode-usage.1m.py"
   ```

5. Ask the user to refresh xbar or run `open -a xbar` only if xbar is installed and the plugin output looks valid.

## Notes

- The installer copies the repository's `opencode-usage.1m.py` into the standard xbar plugin directory.
- It does not install xbar itself.
- It preserves an existing plugin backup as `opencode-usage.1m.py.bak.off`.
- The plugin reads local usage data only; it does not upload usage data.

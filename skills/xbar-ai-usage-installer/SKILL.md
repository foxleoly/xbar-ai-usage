---
name: xbar-ai-usage-installer
description: Agent-facing installer for this repository's xbar AI token usage plugin. Use when the user asks an agent to install, update, repair, or verify the macOS menu bar widget for Qwen Code, Codex, Claude Code, and OpenCode usage.
---

# xbar AI Usage Installer

This skill is for agents. When it triggers, install or update the xbar plugin from the current repository checkout without making the user copy commands.

## Agent Workflow

1. Confirm the repository root contains `opencode-usage.1m.py`.
2. Run a dry-run first:

   ```bash
   python3 skills/xbar-ai-usage-installer/scripts/install_xbar_plugin.py --dry-run
   ```

3. If the dry-run target is the standard xbar plugin path, install:

   ```bash
   python3 skills/xbar-ai-usage-installer/scripts/install_xbar_plugin.py
   ```

4. Verify:

   ```bash
   ls -l "$HOME/Library/Application Support/xbar/plugins/opencode-usage.1m.py"
   python3 "$HOME/Library/Application Support/xbar/plugins/opencode-usage.1m.py"
   ```

5. If `/Applications/xbar.app` or `$HOME/Applications/xbar.app` exists and the plugin output is valid, refresh xbar:

   ```bash
   open -a xbar
   ```

6. Report the install path, backup path if one was created, and whether verification passed.

## Notes

- The installer copies the repository's `opencode-usage.1m.py` into the standard xbar plugin directory.
- It does not install xbar itself.
- It preserves an existing plugin backup as `opencode-usage.1m.py.bak.off`.
- The plugin reads local usage data only; it does not upload usage data.
- Do not ask the user to run the install commands manually unless permissions or authentication block the agent.

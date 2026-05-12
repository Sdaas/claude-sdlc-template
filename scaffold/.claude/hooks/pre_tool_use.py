#!/usr/bin/env python3
"""Block bare python/pip calls that bypass the project virtualenv.

Claude Code spawns a fresh shell process for every bash command it runs.
'source .venv/bin/activate' only affects the shell it runs in — the very
next command starts a new shell with no memory of that activation.

This hook intercepts any bare python/python3/pip/pip3 call before it
executes and redirects to the correct 'uv run' equivalent. This is the
hard enforcement layer — CLAUDE.md is the instructional layer.

Both layers are needed:
  CLAUDE.md              tells Claude what to do
  pre_tool_use.py        blocks it if Claude forgets
  .claude/settings.json  injects VIRTUAL_ENV into every shell as a fallback
"""
import json
import sys

hook_input = json.load(sys.stdin)

tool_name = hook_input.get("tool_name", "")
tool_input = hook_input.get("tool_input", {})

if tool_name == "Bash":
    command = tool_input.get("command", "").strip()

    blocked_prefixes = [
        "python ",
        "python3 ",
        "pip ",
        "pip3 ",
        "python\n",
        "python3\n",
        "pip\n",
        "pip3\n",
    ]

    for prefix in blocked_prefixes:
        if command.startswith(prefix) or command == prefix.strip():
            remainder = command[len(prefix):].strip()
            base = prefix.strip()

            if base in ("pip", "pip3"):
                suggestion = f"uv add {remainder}" if remainder else "uv add <package>"
                reason = (
                    f"Bare '{base}' bypasses the project virtualenv and lockfile. "
                    f"Use '{suggestion}' instead — this keeps uv.lock in sync."
                )
            else:
                suggestion = f"uv run {remainder}" if remainder else "uv run python"
                reason = (
                    f"Bare '{base}' resolves to system Python, not the project "
                    f"virtualenv. Use '{suggestion}' instead."
                )

            print(json.dumps({
                "decision": "block",
                "reason": reason,
            }))
            sys.exit(0)

print(json.dumps({"decision": "approve"}))

#!/usr/bin/env python3
"""Claude Code statusLine helper.

Reads the statusLine JSON payload on stdin and prints one line
formatted as:

    foldername | gitbranch | sandbox | ctx Nk (P%) | Model

Segments are omitted when not applicable (no git repo -> no branch;
HSHELL != 1 -> no sandbox marker).
"""

import json
import os
import re
import subprocess
import sys


def main() -> int:
    raw = sys.stdin.read()
    try:
        data = json.loads(raw) if raw.strip() else {}
    except Exception:
        data = {}

    ws = data.get("workspace") or {}
    cwd = ws.get("current_dir") or data.get("cwd") or os.getcwd()
    model = data.get("model") or {}
    model_name = (model.get("display_name") or "").strip()
    model_id = (model.get("id") or "").strip()
    transcript = data.get("transcript_path") or ""

    folder = os.path.basename(os.path.normpath(cwd)) or cwd

    branch = ""
    try:
        r = subprocess.run(
            ["git", "-C", cwd, "branch", "--show-current"],
            capture_output=True, text=True, timeout=2,
        )
        if r.returncode == 0:
            branch = r.stdout.strip()
    except Exception:
        pass

    sandbox = "sandbox" if os.environ.get("HSHELL") == "1" else ""

    # 1M context for model ids ending in [1m]; else 200k.
    max_ctx = 1_000_000 if re.search(r"\[1m\]", model_id, re.IGNORECASE) else 200_000

    # Tokens = last assistant turn's input + cache_read + cache_creation.
    tokens = 0
    if transcript and os.path.isfile(transcript):
        try:
            last_usage = None
            with open(transcript, "r", encoding="utf-8", errors="replace") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        rec = json.loads(line)
                    except Exception:
                        continue
                    if rec.get("type") != "assistant":
                        continue
                    usage = (rec.get("message") or {}).get("usage")
                    if isinstance(usage, dict):
                        last_usage = usage
            if last_usage:
                tokens = (
                    int(last_usage.get("input_tokens") or 0)
                    + int(last_usage.get("cache_read_input_tokens") or 0)
                    + int(last_usage.get("cache_creation_input_tokens") or 0)
                )
        except Exception:
            tokens = 0

    ctx_display = f"{tokens // 1000}k" if tokens >= 1000 else str(tokens)
    pct = (tokens * 100) // max_ctx if max_ctx else 0

    # Strip trailing "(1M context)" / "[1M context]" from display_name.
    clean_model = re.sub(
        r"\s*[(\[]1M context[)\]]\s*$", "", model_name, flags=re.IGNORECASE
    )

    parts = [folder]
    if branch:
        parts.append(branch)
    if sandbox:
        parts.append(sandbox)
    parts.append(f"ctx {ctx_display} ({pct}%)")
    if clean_model:
        parts.append(clean_model)

    sys.stdout.write(" | ".join(parts) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())

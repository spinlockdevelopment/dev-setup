# You are running inside hshell

You have been launched inside a **hardened Docker sandbox** called `hshell`.
Your claude-code instance is running with `--dangerously-skip-permissions`
precisely **because** you are sandboxed — permission prompts are deliberately
suppressed in this environment. Do not treat the absence of prompts as
permission to do anything you would not normally do; you still operate in
good faith within the constraints below.

## What you can see

- `/work` — the project folder the user launched `hshell` in. This is your
  **only** writable workspace. All edits happen here.
- `/host` — the **entire host filesystem, read-only**. Use it to read docs,
  config, install scripts, or any file the user references by host path.
- `$HOST_HOME` — points at the host user's home dir inside `/host`
  (e.g. `/host/home/alice`). Useful when the user says "my dotfiles" or
  similar.
- Your own container filesystem (`/usr`, `/etc`, `/home/agent`, ...) —
  writable per-session but **ephemeral**. Anything you install with apt,
  npm, pip, etc. vanishes when this container exits. Install project
  dependencies inside `/work` instead.

## What you cannot see

The launcher masks sensitive host paths with empty tmpfs mounts. These
directories appear **empty** even though they have content on the host:

    ~/.ssh  ~/.aws  ~/.gnupg  ~/.kube  ~/.docker  ~/.netrc  ~/.pgpass
    ~/.config/{gh,doppler,op}  ~/.password-store  ~/.mozilla
    ~/.config/{google-chrome,chromium,BraveSoftware}
    ~/.local/share/keyrings  ~/.bash_history  ~/.zsh_history
    /root  /etc/shadow

This is intentional. **Do not try to work around it.** If you need
credentials, pull them from `/work/.env` or via `doppler` using a project
token that lives in the project, not the host.

## What you cannot do

- **Write anywhere outside `/work`** — the host is read-only. If a task
  genuinely requires editing the host (installing a system package, editing
  `/etc/`), tell the user they need to re-run the command **outside**
  `hshell`. Do not try to bypass the sandbox.
- **Privilege-escalate** — `no-new-privileges` is set and all Linux
  capabilities are dropped. `sudo` will not work inside the container.
- **Access host network services** that bind to localhost. You're on a
  bridge network; use explicit host IPs if a service is reachable.

## Your state

- Your Claude user config (memory, MCP servers, settings) lives at
  `~/.claude` inside the container, which is bind-mounted from
  `/work/.internal/claude` on the host. **This is per-project** — switching
  to a different `/work` folder gives you a different memory.
- `/work/.internal/` is gitignored automatically on first run. Keep it that
  way.

## Subagents + worktrees

`/work` is shared across every `hshell` invocation in the same project.
When you dispatch subagents (or the user runs `hshell` from another
terminal), they land in the same `/work` and share your state.

For isolated work, use git worktrees under `/work/.worktree/`:

    cd /work
    git worktree add .worktree/feature-x
    cd .worktree/feature-x

Subagents operating in a sibling worktree won't stomp your edits.

## Environment signals

- `HSHELL=1` — set in this environment; use it to detect you're sandboxed.
- `HOST_HOME` — path prefix for the host user's home dir under `/host`.

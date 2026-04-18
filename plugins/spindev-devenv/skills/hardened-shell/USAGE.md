# hshell — User Guide

`hshell` drops you (or an agent) into a hardened Docker sandbox where
`claude --dangerously-skip-permissions` can run in banshee mode without
risking the host. This document is the **user-facing guide**. If you're
looking for the Claude-facing decision tree and self-healing rules, see
[SKILL.md](./SKILL.md).

## Installation

One-time setup:

```bash
# 1. Build the base image (takes ~1–8 min depending on your hardware)
./scripts/build-image.sh

# 2. Symlink hshell into ~/.local/bin (no sudo needed)
./scripts/install.sh

# 3. Confirm everything is healthy
./scripts/verify.sh
```

`which hshell` should now print `~/.local/bin/hshell`. If not, add
`$HOME/.local/bin` to your `PATH` (Ubuntu 24.04 does this by default via
`/etc/profile.d/`).

## Usage

```bash
hshell                    # interactive bash inside the sandbox at /work
hshell claude             # launch claude with --dangerously-skip-permissions auto-injected
hshell claude -p "..."    # one-shot agent run, then exit
hshell <any command>      # execute that command inside the sandbox
hshell bash -c '...'      # scripted run
```

All invocations mount your **current working directory** as `/work`
inside the container. Always `cd` into a project directory first — `hshell`
refuses to run in `$HOME` or `/`.

### The first run per project

The first time you run `hshell` in a given directory, it seeds:

- `./.internal/claude/` — Claude's user config (memory, MCP, settings),
  pre-populated from `home-template/`. Persists across runs; grows per
  project.
- Appends `.internal/` to `.gitignore` (if the directory is a git repo).

Subsequent runs in the same folder pick up where the previous one left off
— memory, installed MCP servers, preferences, etc. all survive.

### Subagents & parallel sessions

Multiple `hshell` invocations from different terminals in the same project
share the same `/work` mount. To avoid stepping on each other's edits, use
git worktrees under `/work/.worktree/`:

```bash
hshell bash -c 'cd /work && git worktree add .worktree/feature-x'
# then in a different terminal:
cd <project>/.worktree/feature-x && hshell
```

Each subagent operates in a sibling worktree without conflicts.

## What the sandbox looks like

| Path inside container | Source | Access |
|---|---|---|
| `/work` | your `$PWD` on the host | **read-write** |
| `/host` | host `/` | read-only |
| `/home/agent` | ephemeral tmpfs (new per run) | read-write, ephemeral |
| `/home/agent/.claude` | `$PWD/.internal/claude/` on host | read-write, persistent |
| Various blocked paths under `/host/...` | empty tmpfs overlays | **blocked** |

### Environment signals

The container sets these so the agent can see its context:

- `HSHELL=1` — "you're sandboxed"
- `HOST_HOME=/host/home/<you>` — where your host home dir lives inside
  `/host` (useful for reading dotfiles)
- `HOME=/home/agent`, `USER=agent`

### What's pre-installed in the image

- **Languages:** Node LTS + Python (latest stable), via `mise`
- **Claude Code:** `@anthropic-ai/claude-code` CLI
- **Dev CLIs:** `git`, `gh`, `jq`, `ripgrep`, `fd`, `bat`, `tree`, `curl`,
  `wget`, `less`, `file`, `tini`, `build-essential`, `openssh-client`
- **Secrets tooling:** `doppler`
- **Signature verification:** `gnupg`, `gpgv`

Install anything else inside the container per session (`apt install` does
work as long as the install doesn't need persistence — it won't survive
past the current `hshell` invocation). For project dependencies, install
inside `/work` (npm, pip, etc.) so they persist.

## Credentials

The blocklist removes all the usual host credential stores from view:

```
~/.ssh  ~/.aws  ~/.gnupg  ~/.kube  ~/.docker  ~/.netrc  ~/.pgpass
~/.config/{gh,doppler,op}  ~/.password-store  ~/.mozilla
~/.config/{google-chrome,chromium,BraveSoftware}
~/.local/share/keyrings  ~/.bash_history  ~/.zsh_history
/root  /etc/shadow
```

These appear as empty (or permission-denied) directories inside `/host`.
If the agent needs a credential, get it into `/work` by one of these
routes:

### Option 1 — project `.env`

```bash
# in your project
echo "MY_API_TOKEN=xxx" >> .env
echo ".env" >> .gitignore   # if not already
```

The agent reads `/work/.env` like any other project file.

### Option 2 — project-scoped Doppler

`doppler` is in the image. Log in fresh per project with a project-scoped
service token that you keep in `/work/.env.doppler` (or pass once per
session):

```bash
hshell bash -c '
  doppler configure set token "$(cat /work/.env.doppler)"
  doppler run -- npm run deploy
'
```

Do **not** try to use host Doppler auth — that's intentionally blocked.

### Option 3 — explicit env var on launch

```bash
HSHELL_IMAGE=hshell:latest docker run ... # custom invocations
```

Or just inline:

```bash
hshell bash -c 'MY_TOKEN=xxx your-command'
```

## Rebuilding the image

When to rebuild:

- You changed the `Dockerfile`.
- The base image drifted (new Debian stable, package renames).
- You bumped the Node/Python pin for a new LTS.

```bash
./scripts/build-image.sh --force
```

Without `--force`, the build is a no-op if the image already exists.

### Bumping LTS pins

Node and Python are pinned in `Dockerfile`:

```dockerfile
# pinned 2026-04-14.
ENV NODE_LTS_VERSION=24.14.1 \
    PYTHON_VERSION=3.14.4
```

When new LTS lands (October for Node, October for Python), update the pins
in place, update the dated comment, and rebuild:

```bash
mise latest node@lts      # see what's current
mise latest python
# edit Dockerfile pins + comment
./scripts/build-image.sh --force
./scripts/verify.sh
```

Claude's SKILL.md has a self-healing checklist for this.

## Troubleshooting

### `hshell: image 'hshell:latest' not found`
Run `./scripts/build-image.sh`.

### `hshell: refusing to run in $HOME or /`
You're in your home directory. `cd` into a project folder first. This is
deliberate — running inside `$HOME` would mount your home as `/work` and
give the agent full write access to it.

### `which hshell` prints nothing
`~/.local/bin` is not on your `PATH`. Add it to your shell rc:
```bash
export PATH="$HOME/.local/bin:$PATH"
```
Or run `hshell` by full path.

### `docker: Error response from daemon: ... permission denied`
Your user is not in the `docker` group. Fix:
```bash
sudo usermod -aG docker "$USER"
# log out and back in
```

### Agent says it can't read `~/.ssh` or `~/.aws`
Working as designed. Put credentials in `/work/.env` or use
project-scoped Doppler. See "Credentials" above.

### Memory isn't persisting
Check that `$PWD/.internal/claude/` exists after your first run. If
you're running `hshell` from different directories and expecting shared
memory, that won't happen — memory is intentionally per-project.

### "No space left on device" during build
Docker image and build cache. Clean up:
```bash
docker system prune -a
```
Then rebuild.

### Image is weeks old — should I refresh it?
The image floats on `debian:stable-slim` and pulls the latest
`@anthropic-ai/claude-code`, but neither updates automatically. For the
freshest binary, `./scripts/build-image.sh --force` every month or two.

## Security notes

**What this sandbox does NOT protect against:**

- **Malicious image.** We built `hshell:latest` locally. If you pull a
  tampered `claude-code` package from npm, this sandbox can't save you.
- **Container escape CVEs.** Kernel bugs in the Docker runtime could let
  the container out. We drop all capabilities and `no-new-privileges` to
  minimize attack surface, but this isn't a VM.
- **Network exfiltration.** `--network=bridge` means outbound traffic
  works. Anything the agent can read in `/work` or `/host`, it can POST
  anywhere. If that's in your threat model, run with `--network=none` and
  accept that the Claude API won't work either.
- **Writes the agent asks *you* to make.** If the agent says "run this
  sudo command outside the sandbox," you're outside the sandbox.

**What it does protect against:**

- Agent writing to the host filesystem (outside `/work`).
- Agent reading host credentials at well-known paths.
- Agent privilege-escalating inside the container (caps dropped,
  no-new-privileges).
- Agent exhausting host resources (8 GB memory cap, 512 pid cap).
- Agent seeing `/root`, `/etc/shadow`, browser profiles, shell history.

## Uninstall

```bash
# Remove launcher
rm ~/.local/bin/hshell

# Remove image
docker rmi hshell:latest

# Remove skill (optional)
rm -rf ~/src/setup/.claude/skills/hardened-shell

# Remove per-project state (run in each project where you used hshell)
rm -rf .internal
```

## Customization

### Change the blocklist

Edit `scripts/hshell`, the `BLOCK_DIRS` and `BLOCK_FILES` arrays. The
blocklist is evaluated per-launch.

### Change resource limits

Edit `scripts/hshell`, the `docker run` call: `--memory=8g`,
`--pids-limit=512`. Adjust to your box.

### Pick a different base image

Edit `Dockerfile`, change `FROM debian:stable-slim`. Anything glibc-based
with an apt-get workflow will work with minor tweaks. Rebuild with
`--force`.

### Ephemeral mode (no per-project persistence)

Run with an overridden state dir:

```bash
HSHELL_IMAGE=hshell:latest docker run \
    --rm -it \
    --cap-drop=ALL --security-opt=no-new-privileges \
    --user "$(id -u):$(id -g)" \
    -v "$PWD:/work" \
    -v "/:/host:ro" \
    --tmpfs /home/agent/.claude:rw,size=64m \
    -w /work hshell:latest \
    claude --dangerously-skip-permissions
```

Or simpler: just run `claude --dangerously-skip-permissions` directly
without `hshell` if you want ephemeral state and don't need the sandbox.

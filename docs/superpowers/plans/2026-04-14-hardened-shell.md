# Hardened Shell (`hshell`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an `hshell` command that launches a locked-down Docker container so Claude (and other agents) can run in `--dangerously-skip-permissions` banshee mode without risking the host. Host is read-only and credential-masked; `$PWD` is the agent's only writable world; Claude state persists per folder in `$PWD/.internal/claude/`.

**Architecture:** A new Claude Code skill at `.claude/skills/hardened-shell/` containing a `Dockerfile` (base image with claude-code + mise-managed Python/Node LTS + dev CLIs), a `hshell` bash launcher (computes mounts + execs `docker run`), a `home-template/` seeded into each project's `.internal/claude/` on first use, and companion build/install/verify scripts. The launcher installs globally via a symlink into `/usr/local/bin`.

**Tech Stack:** Docker CE, bash 5, mise (Python + Node LTS), claude-code CLI, Node.js, standard dev CLIs (git, ripgrep, fd, bat, jq, gh, curl, doppler).

---

## File Structure

```
.claude/skills/hardened-shell/
├── SKILL.md                       # thin decision tree for Claude
├── Dockerfile                     # hshell:latest base image
├── home-template/                 # seeded to $PWD/.internal/claude/ on first run
│   ├── CLAUDE.md                  # tells the agent it is in hshell + constraints
│   └── settings.json              # permissive settings (belt + suspenders)
└── scripts/
    ├── lib.sh                     # logging + idempotency helpers (mirrors ubuntu-debloat)
    ├── hshell                     # the launcher (exec'd from /usr/local/bin)
    ├── build-image.sh             # docker build hshell:latest
    ├── install.sh                 # symlink hshell → /usr/local/bin/hshell
    └── verify.sh                  # --verify health check

claude-skills.md                   # index entry replaces the WIP stanza
CLAUDE.md                          # remove the WIP-notes pointer
hardened-shell-notes.md            # DELETED — design absorbed into the skill
```

**Responsibility split:**

- `SKILL.md` — decision tree (how Claude decides what to run).
- `Dockerfile` — base image, pinned LTS versions with dated comments for self-healing.
- `home-template/` — the "private user config" the agent sees; start empty MCP, permissive settings, sandbox-aware CLAUDE.md.
- `scripts/hshell` — the only script end-users run at runtime. Computes mounts, picks a command, execs `docker run`.
- `scripts/build-image.sh` — one-shot at setup time.
- `scripts/install.sh` — symlink to `/usr/local/bin`. Sudo required.
- `scripts/verify.sh` — read-only health check.
- `scripts/lib.sh` — shared helpers so scripts feel consistent with the rest of the repo.

---

## Task 1: Scaffold the skill directory + `lib.sh`

**Files:**
- Create: `.claude/skills/hardened-shell/scripts/lib.sh`

- [ ] **Step 1: Create the skill directory tree**

Run:

```bash
cd /home/lnxuser/src/setup
mkdir -p .claude/skills/hardened-shell/scripts
mkdir -p .claude/skills/hardened-shell/home-template
```

Expected: both directories exist with no errors.

- [ ] **Step 2: Write `scripts/lib.sh`**

Create `.claude/skills/hardened-shell/scripts/lib.sh` with:

```bash
# shellcheck shell=bash
# Shared helpers for hardened-shell scripts.
# Source with: source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if [[ -t 1 ]]; then
    C_RED='\033[0;31m'; C_GRN='\033[0;32m'; C_YEL='\033[0;33m'
    C_BLU='\033[0;34m'; C_DIM='\033[2m'; C_OFF='\033[0m'
else
    C_RED=''; C_GRN=''; C_YEL=''; C_BLU=''; C_DIM=''; C_OFF=''
fi

log_ok()   { printf "${C_GRN}[OK]${C_OFF}   %s\n" "$*"; }
log_skip() { printf "${C_BLU}[SKIP]${C_OFF} %s\n" "$*"; }
log_fail() { printf "${C_RED}[FAIL]${C_OFF} %s\n" "$*" >&2; }
log_info() { printf "${C_YEL}[..]${C_OFF}   %s\n" "$*"; }
log_step() { printf "\n${C_DIM}==>${C_OFF} %s\n" "$*"; }

VERIFY_MODE=false
for __arg in "${@:-}"; do
    [[ "$__arg" == "--verify" ]] && VERIFY_MODE=true
done
export VERIFY_MODE

IMAGE_NAME="hshell"
IMAGE_TAG="latest"
IMAGE_REF="${IMAGE_NAME}:${IMAGE_TAG}"

require_docker() {
    if ! command -v docker &>/dev/null; then
        log_fail "docker not installed; install Docker CE first (see ubuntu-debloat skill)"
        return 1
    fi
    if ! docker info &>/dev/null; then
        log_fail "docker daemon not reachable; is the service running and your user in the docker group?"
        return 1
    fi
}

image_exists() {
    docker image inspect "$IMAGE_REF" &>/dev/null
}
```

- [ ] **Step 3: Verify `lib.sh` sources cleanly**

Run:

```bash
bash -c 'set -euo pipefail; source /home/lnxuser/src/setup/.claude/skills/hardened-shell/scripts/lib.sh; log_ok "sourced"; require_docker && log_ok "docker ok"'
```

Expected: `[OK]   sourced` followed by `[OK]   docker ok` (assuming Docker is installed and running). If `require_docker` fails, that is a local env issue, not a script bug — proceed anyway.

- [ ] **Step 4: Commit**

```bash
cd /home/lnxuser/src/setup
git add .claude/skills/hardened-shell/scripts/lib.sh
git commit -m "hardened-shell: scaffold skill dir + lib.sh"
```

---

## Task 2: Write the `Dockerfile`

**Files:**
- Create: `.claude/skills/hardened-shell/Dockerfile`

- [ ] **Step 1: Look up current LTS versions for pinning**

Run on the host (outside any container):

```bash
mise latest node@lts
mise latest python
```

Record the two versions you get back — call them `NODE_LTS` (e.g. `22.11.0`) and `PY_STABLE` (e.g. `3.12.7`). Use those exact version strings when pinning below. If `mise` is not on this host, look up current Node LTS at https://nodejs.org and current Python stable at https://www.python.org/downloads/ — use the latest non-prerelease from each.

- [ ] **Step 2: Write the Dockerfile**

Create `.claude/skills/hardened-shell/Dockerfile` with the content below. Replace `NODE_LTS_VERSION` and `PYTHON_VERSION` with the values you recorded in Step 1, and keep the `# pinned YYYY-MM-DD` dated comment current so self-healing can spot drift.

```dockerfile
# syntax=docker/dockerfile:1.7

# Base: Debian stable slim. Small, current glibc, apt is easy.
FROM debian:stable-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    MISE_DATA_DIR=/opt/mise \
    PATH=/opt/mise/shims:/usr/local/bin:/usr/bin:/bin

# OS packages: shell + dev CLIs + network + build deps.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl wget gnupg \
      git ripgrep fd-find bat jq tree less \
      bash-completion procps file \
      build-essential \
      tini \
      openssh-client \
 && ln -s /usr/bin/fdfind /usr/local/bin/fd \
 && ln -s /usr/bin/batcat /usr/local/bin/bat \
 && rm -rf /var/lib/apt/lists/*

# GitHub CLI (upstream apt repo)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/*

# Doppler CLI (official install script)
RUN curl -fsSL https://cli.doppler.com/install.sh | sh -s -- --verify-signature

# mise — installed under /opt/mise so shims are on PATH for every user.
# Pinned LTS versions. Bump in place when a new LTS lands.
# pinned 2026-04-14 — replace with the versions you recorded in Step 1.
ENV NODE_LTS_VERSION=REPLACE_WITH_NODE_LTS \
    PYTHON_VERSION=REPLACE_WITH_PYTHON_STABLE

RUN curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh \
 && mise settings set experimental true \
 && mise use -g "node@${NODE_LTS_VERSION}" "python@${PYTHON_VERSION}" \
 && mise reshim

# Claude Code CLI — install from the official npm package so it uses the
# bundled node. This is the supported install path.
RUN npm install -g @anthropic-ai/claude-code \
 && claude --version

# Non-root "agent" user. UID 1000 is the common Ubuntu desktop default;
# hshell launcher overrides via --user $(id -u):$(id -g) when needed.
RUN useradd -m -u 1000 -U -s /bin/bash agent \
 && mkdir -p /home/agent/.claude /work \
 && chown -R agent:agent /home/agent /work

WORKDIR /work

# tini reaps zombies for long-running agent subprocesses
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["bash"]
```

- [ ] **Step 3: Sanity-check Dockerfile syntax with `docker build --check`**

Run:

```bash
cd /home/lnxuser/src/setup/.claude/skills/hardened-shell
docker buildx build --check .
```

Expected: no `error:` or `warning:` lines that indicate a syntax error. `buildx` may warn about non-critical style things — those are fine. If `buildx` isn't available, skip this step; Task 3 will exercise the real build.

- [ ] **Step 4: Commit**

```bash
cd /home/lnxuser/src/setup
git add .claude/skills/hardened-shell/Dockerfile
git commit -m "hardened-shell: Dockerfile with mise-pinned Node + Python LTS"
```

---

## Task 3: Write `build-image.sh` and build the image

**Files:**
- Create: `.claude/skills/hardened-shell/scripts/build-image.sh`

- [ ] **Step 1: Write `build-image.sh`**

Create `.claude/skills/hardened-shell/scripts/build-image.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

log_step "build ${IMAGE_REF}"

require_docker || exit 1

SKILL_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "${1-}" == "--verify" ]]; then
    if image_exists; then
        log_ok "image present: ${IMAGE_REF} ($(docker image inspect -f '{{.Id}}' "$IMAGE_REF"))"
        exit 0
    else
        log_fail "image not built: ${IMAGE_REF}"
        exit 1
    fi
fi

FORCE=false
[[ "${1-}" == "--force" ]] && FORCE=true

if image_exists && ! $FORCE; then
    log_skip "${IMAGE_REF} already built (use --force to rebuild)"
    exit 0
fi

log_info "building (this takes a few minutes on first run)"
docker build --tag "$IMAGE_REF" "$SKILL_DIR"
log_ok "built ${IMAGE_REF}"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x /home/lnxuser/src/setup/.claude/skills/hardened-shell/scripts/build-image.sh
```

- [ ] **Step 3: Run it — actually build the image**

```bash
/home/lnxuser/src/setup/.claude/skills/hardened-shell/scripts/build-image.sh
```

Expected: `[..]   building (this takes a few minutes on first run)` then Docker build output, ending in `[OK]   built hshell:latest`. Takes 3–8 minutes first time (most of it in `apt-get` and `npm install -g @anthropic-ai/claude-code`).

- [ ] **Step 4: Verify the built image works end-to-end**

```bash
docker run --rm hshell:latest bash -c 'node --version && python --version && claude --version && git --version && gh --version | head -1 && doppler --version && rg --version | head -1'
```

Expected: one line each with a version string, no errors. Node and Python versions should match what you pinned in Task 2 Step 1.

- [ ] **Step 5: Re-run build-image.sh to confirm idempotency**

```bash
/home/lnxuser/src/setup/.claude/skills/hardened-shell/scripts/build-image.sh
```

Expected: `[SKIP] hshell:latest already built (use --force to rebuild)` and exits 0.

- [ ] **Step 6: Commit**

```bash
cd /home/lnxuser/src/setup
git add .claude/skills/hardened-shell/scripts/build-image.sh
git commit -m "hardened-shell: build-image.sh"
```

---

## Task 4: Write the `home-template/` seed

**Files:**
- Create: `.claude/skills/hardened-shell/home-template/CLAUDE.md`
- Create: `.claude/skills/hardened-shell/home-template/settings.json`

- [ ] **Step 1: Write the sandbox-aware `CLAUDE.md`**

Create `.claude/skills/hardened-shell/home-template/CLAUDE.md`:

```markdown
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
```

- [ ] **Step 2: Write the permissive `settings.json`**

Create `.claude/skills/hardened-shell/home-template/settings.json`:

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {
    "defaultMode": "bypassPermissions",
    "allow": ["*"]
  }
}
```

- [ ] **Step 3: Verify JSON validity**

```bash
jq empty /home/lnxuser/src/setup/.claude/skills/hardened-shell/home-template/settings.json && echo "valid"
```

Expected: `valid`.

- [ ] **Step 4: Commit**

```bash
cd /home/lnxuser/src/setup
git add .claude/skills/hardened-shell/home-template/
git commit -m "hardened-shell: home-template (sandbox CLAUDE.md + permissive settings)"
```

---

## Task 5: Write the `hshell` launcher

**Files:**
- Create: `.claude/skills/hardened-shell/scripts/hshell`

- [ ] **Step 1: Write the launcher**

Create `.claude/skills/hardened-shell/scripts/hshell`:

```bash
#!/usr/bin/env bash
# hshell — launch a hardened Docker sandbox for agentic work in $PWD.
# See .claude/skills/hardened-shell/SKILL.md for the design.
set -euo pipefail

# Resolve the skill directory via the symlink in /usr/local/bin.
SELF="$(readlink -f "$0")"
SKILL_DIR="$(cd -- "$(dirname "$SELF")/.." && pwd)"
TEMPLATE_DIR="${SKILL_DIR}/home-template"

IMAGE="${HSHELL_IMAGE:-hshell:latest}"
WORK="$PWD"

# --- preflight --------------------------------------------------------------

if [[ "$WORK" == "$HOME" || "$WORK" == "/" ]]; then
    echo "hshell: refusing to run in \$HOME or /; cd into a project folder first" >&2
    exit 1
fi

if ! command -v docker &>/dev/null; then
    echo "hshell: docker not installed" >&2
    exit 1
fi

if ! docker image inspect "$IMAGE" &>/dev/null; then
    echo "hshell: image '$IMAGE' not found" >&2
    echo "       run: $SKILL_DIR/scripts/build-image.sh" >&2
    exit 1
fi

if [[ ! -d "$TEMPLATE_DIR" ]]; then
    echo "hshell: home-template not found at $TEMPLATE_DIR" >&2
    exit 1
fi

# --- per-project state ------------------------------------------------------

INTERNAL="$WORK/.internal"
CLAUDE_STATE="$INTERNAL/claude"

if [[ ! -d "$CLAUDE_STATE" ]]; then
    mkdir -p "$CLAUDE_STATE"
    cp -rT "$TEMPLATE_DIR" "$CLAUDE_STATE"
fi

# Ensure .internal is gitignored if this is a git repo.
if [[ -d "$WORK/.git" ]]; then
    GITIGNORE="$WORK/.gitignore"
    if ! grep -qxF ".internal/" "$GITIGNORE" 2>/dev/null; then
        echo ".internal/" >> "$GITIGNORE"
    fi
fi

# --- blocklist --------------------------------------------------------------
# Sensitive host paths get shadowed by empty tmpfs / /dev/null mounts
# layered on top of the /host read-only bind.

BLOCK_DIRS=(
    "$HOME/.ssh"
    "$HOME/.aws"
    "$HOME/.gnupg"
    "$HOME/.kube"
    "$HOME/.docker"
    "$HOME/.config/gh"
    "$HOME/.config/doppler"
    "$HOME/.config/op"
    "$HOME/.password-store"
    "$HOME/.mozilla"
    "$HOME/.config/google-chrome"
    "$HOME/.config/chromium"
    "$HOME/.config/BraveSoftware"
    "$HOME/.local/share/keyrings"
    "/root"
)

BLOCK_FILES=(
    "$HOME/.netrc"
    "$HOME/.pgpass"
    "$HOME/.bash_history"
    "$HOME/.zsh_history"
    "/etc/shadow"
)

BLOCK_ARGS=()
for d in "${BLOCK_DIRS[@]}"; do
    BLOCK_ARGS+=(--mount "type=tmpfs,dst=/host${d}")
done
for f in "${BLOCK_FILES[@]}"; do
    # Only mask files that actually exist; docker errors on missing sources.
    [[ -e "$f" ]] && BLOCK_ARGS+=(-v "/dev/null:/host${f}:ro")
done

# --- command selection ------------------------------------------------------
# `hshell`              → interactive bash
# `hshell claude ...`   → claude --dangerously-skip-permissions <args>
# `hshell <anything>`   → <anything> <args>

if (( $# == 0 )); then
    CMD=(bash)
    TTY_ARGS=(-it)
elif [[ "$1" == "claude" ]]; then
    shift
    CMD=(claude --dangerously-skip-permissions "$@")
    TTY_ARGS=(-it)
else
    CMD=("$@")
    # Preserve tty only if we actually have one attached.
    if [[ -t 0 && -t 1 ]]; then
        TTY_ARGS=(-it)
    else
        TTY_ARGS=(-i)
    fi
fi

# --- run --------------------------------------------------------------------

exec docker run \
    --rm "${TTY_ARGS[@]}" \
    --cap-drop=ALL \
    --security-opt=no-new-privileges \
    --pids-limit=512 \
    --memory=8g \
    --user "$(id -u):$(id -g)" \
    --network=bridge \
    --hostname hshell \
    -e HSHELL=1 \
    -e HOST_HOME="/host${HOME}" \
    -e HOME=/home/agent \
    -e USER=agent \
    -v "/:/host:ro" \
    -v "${WORK}:/work" \
    -v "${CLAUDE_STATE}:/home/agent/.claude" \
    "${BLOCK_ARGS[@]}" \
    -w /work \
    "$IMAGE" \
    "${CMD[@]}"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x /home/lnxuser/src/setup/.claude/skills/hardened-shell/scripts/hshell
```

- [ ] **Step 3: Smoke-test from a scratch project directory**

```bash
mkdir -p /tmp/hshell-smoke && cd /tmp/hshell-smoke
git init -q
/home/lnxuser/src/setup/.claude/skills/hardened-shell/scripts/hshell bash -c 'echo "HSHELL=$HSHELL"; echo "HOST_HOME=$HOST_HOME"; pwd; whoami; ls -la /host | head -3; ls /host$HOME/.ssh 2>&1 | head; cat /etc/shadow 2>&1 | head'
```

Expected output (approximately):

```
HSHELL=1
HOST_HOME=/host/home/lnxuser
/work
agent                                # or your numeric UID if not mapped
(3 lines of host / root listing)
(empty — .ssh is tmpfs'd)
cat: /etc/shadow: Permission denied  # or similar — the mount over /dev/null
```

Key things to verify:
- `HSHELL=1` is set.
- `pwd` is `/work`.
- `/host` is populated (you should see real host entries like `home`, `etc`, `usr`).
- `/host$HOME/.ssh` is empty (blocklist working).
- `/etc/shadow` read in `/host/etc/shadow` is effectively blocked — check with `cat /host/etc/shadow` → should produce empty output (because `/dev/null` mounted on top).

- [ ] **Step 4: Verify per-project state seeded**

```bash
ls -la /tmp/hshell-smoke/.internal/claude/
cat /tmp/hshell-smoke/.gitignore
```

Expected: `CLAUDE.md` and `settings.json` in `.internal/claude/`; `.internal/` appears in `.gitignore`.

- [ ] **Step 5: Verify writes land in `/work` and not on host**

```bash
/home/lnxuser/src/setup/.claude/skills/hardened-shell/scripts/hshell bash -c 'echo "from hshell" > /work/hello.txt; touch /host/tmp/should-fail-$$ 2>&1 || true'
cat /tmp/hshell-smoke/hello.txt
```

Expected: `hello.txt` exists in the project dir with content `from hshell`. The `/host/tmp/...` touch produces a `Read-only file system` error.

- [ ] **Step 6: Verify refuses to run in `$HOME`**

```bash
cd "$HOME" && /home/lnxuser/src/setup/.claude/skills/hardened-shell/scripts/hshell echo x 2>&1 || true
```

Expected: `hshell: refusing to run in $HOME or /; cd into a project folder first`.

- [ ] **Step 7: Cleanup smoke dir, commit**

```bash
rm -rf /tmp/hshell-smoke
cd /home/lnxuser/src/setup
git add .claude/skills/hardened-shell/scripts/hshell
git commit -m "hardened-shell: hshell launcher"
```

---

## Task 6: Write `install.sh`

**Files:**
- Create: `.claude/skills/hardened-shell/scripts/install.sh`

- [ ] **Step 1: Write `install.sh`**

Create `.claude/skills/hardened-shell/scripts/install.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

log_step "install hshell launcher"

SKILL_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${SKILL_DIR}/scripts/hshell"
DST="/usr/local/bin/hshell"

if [[ ! -x "$SRC" ]]; then
    log_fail "launcher not found or not executable: $SRC"
    exit 1
fi

# Verify mode — read-only check.
if [[ "${1-}" == "--verify" ]]; then
    if [[ -L "$DST" ]] && [[ "$(readlink -f "$DST")" == "$(readlink -f "$SRC")" ]]; then
        log_ok "hshell installed → $DST"
        exit 0
    fi
    log_fail "hshell not installed or points elsewhere (expected symlink to $SRC)"
    exit 1
fi

# Check existing state.
if [[ -L "$DST" ]] && [[ "$(readlink -f "$DST")" == "$(readlink -f "$SRC")" ]]; then
    log_skip "hshell already installed → $DST"
    exit 0
fi

if [[ -e "$DST" && ! -L "$DST" ]]; then
    log_fail "$DST exists and is not a symlink; refusing to overwrite"
    exit 1
fi

log_info "symlinking $SRC → $DST (needs sudo)"
sudo ln -sf "$SRC" "$DST"
log_ok "installed: $DST"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x /home/lnxuser/src/setup/.claude/skills/hardened-shell/scripts/install.sh
```

- [ ] **Step 3: Run it**

```bash
/home/lnxuser/src/setup/.claude/skills/hardened-shell/scripts/install.sh
```

Expected: sudo prompt (if not cached), then `[OK]   installed: /usr/local/bin/hshell`.

- [ ] **Step 4: Verify the global command works**

```bash
which hshell
ls -la /usr/local/bin/hshell
mkdir -p /tmp/hshell-global && cd /tmp/hshell-global && git init -q
hshell bash -c 'echo "global hshell works: $HSHELL in $(pwd)"'
rm -rf /tmp/hshell-global
```

Expected: `which hshell` prints `/usr/local/bin/hshell`; the `hshell` invocation prints `global hshell works: 1 in /work`.

- [ ] **Step 5: Re-run install.sh to confirm idempotency**

```bash
/home/lnxuser/src/setup/.claude/skills/hardened-shell/scripts/install.sh
```

Expected: `[SKIP] hshell already installed → /usr/local/bin/hshell`.

- [ ] **Step 6: Commit**

```bash
cd /home/lnxuser/src/setup
git add .claude/skills/hardened-shell/scripts/install.sh
git commit -m "hardened-shell: install.sh (symlink into /usr/local/bin)"
```

---

## Task 7: Write `verify.sh`

**Files:**
- Create: `.claude/skills/hardened-shell/scripts/verify.sh`

- [ ] **Step 1: Write `verify.sh`**

Create `.claude/skills/hardened-shell/scripts/verify.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

log_step "hshell health check"

SKILL_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail=0
step() { "$@" || fail=1; }

# 1. Docker reachable
step require_docker

# 2. Image built
if image_exists; then
    log_ok "image present: ${IMAGE_REF}"
else
    log_fail "image missing: ${IMAGE_REF} — run scripts/build-image.sh"
    fail=1
fi

# 3. Launcher installed globally as a symlink back into this skill.
if [[ -L /usr/local/bin/hshell ]] \
   && [[ "$(readlink -f /usr/local/bin/hshell)" == "$(readlink -f "${SKILL_DIR}/scripts/hshell")" ]]; then
    log_ok "launcher installed: /usr/local/bin/hshell"
else
    log_fail "launcher not installed or points elsewhere — run scripts/install.sh"
    fail=1
fi

# 4. home-template looks right.
for f in CLAUDE.md settings.json; do
    if [[ -f "${SKILL_DIR}/home-template/${f}" ]]; then
        log_ok "home-template/${f} present"
    else
        log_fail "home-template/${f} missing"
        fail=1
    fi
done

# 5. Live container check — every critical tool on PATH.
if image_exists; then
    if docker run --rm "${IMAGE_REF}" bash -c '
        set -e
        for cmd in node python claude git gh jq rg fd bat doppler curl; do
            command -v "$cmd" >/dev/null || { echo "MISSING: $cmd"; exit 1; }
        done' >/dev/null 2>&1; then
        log_ok "all expected tools present in image"
    else
        log_fail "one or more expected tools missing in image; re-run build-image.sh"
        fail=1
    fi
fi

if (( fail == 0 )); then
    log_ok "hshell is healthy"
    exit 0
else
    log_fail "hshell health check failed; see above"
    exit 1
fi
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x /home/lnxuser/src/setup/.claude/skills/hardened-shell/scripts/verify.sh
```

- [ ] **Step 3: Run it**

```bash
/home/lnxuser/src/setup/.claude/skills/hardened-shell/scripts/verify.sh
```

Expected: five-ish `[OK]` lines ending with `[OK]   hshell is healthy`, exit 0.

- [ ] **Step 4: Commit**

```bash
cd /home/lnxuser/src/setup
git add .claude/skills/hardened-shell/scripts/verify.sh
git commit -m "hardened-shell: verify.sh"
```

---

## Task 8: Write `SKILL.md`

**Files:**
- Create: `.claude/skills/hardened-shell/SKILL.md`

- [ ] **Step 1: Write `SKILL.md`**

Create `.claude/skills/hardened-shell/SKILL.md`:

```markdown
---
name: hardened-shell
description: Run Claude (or other agents) in banshee mode — `--dangerously-skip-permissions`, no prompts — inside a locked-down Docker sandbox called `hshell`. Host is read-only at `/host` with credentials masked; `$PWD` is the agent's only writable world at `/work`; Claude memory persists per project in `$PWD/.internal/claude/`. Use when the user says "hshell", "run this in a sandbox", "let claude loose", "yolo mode", or asks for a hardened environment to dispatch agents/subagents from. Also use when the user wants to install or verify `hshell`, build the image, or rotate LTS pins.
---

# hardened-shell — `hshell`

Thin skill. Real work lives in `scripts/` and `Dockerfile`. You orchestrate:
build the image, install the launcher, verify health, or — if something
breaks — self-heal the pins.

## What hshell gives the user

A single command, `hshell`, that runs a Docker container where:

- **Host is read-only** at `/host`. The agent can read any tool or file on
  the host, but cannot modify anything outside `/work`.
- **`$PWD` is writable** at `/work`. This is the agent's only write surface.
- **Sensitive host paths are masked** (blocklist): `~/.ssh`, `~/.aws`,
  `~/.gnupg`, `~/.kube`, `~/.docker`, `~/.netrc`, `~/.pgpass`, browser
  profiles, `~/.config/{gh,doppler,op}`, `~/.password-store`, shell history,
  keyrings, `/root`, `/etc/shadow`. The agent pulls creds from `/work/.env`
  or project-scoped Doppler instead.
- **Per-project Claude state** lives in `$PWD/.internal/claude/`, seeded
  from `home-template/` on first run. Survives across invocations. The
  agent's writes diverge freely per project; the template stays clean.
- **Banshee mode** — the launcher injects `--dangerously-skip-permissions`
  when invoked as `hshell claude`. The sandbox is the safety net.

## Usage

```bash
hshell                    # interactive bash in the sandbox
hshell claude             # claude with --dangerously-skip-permissions auto-injected
hshell claude -p "..."    # one-shot agent run
hshell <any command>      # exec the command inside the sandbox
```

Subagents can spawn more `hshell` invocations in the same project — they
share `/work`, so they should use git worktrees under `/work/.worktree/`
to avoid stepping on each other.

## Decision tree for Claude

1. **"install hshell" / fresh setup** →
   `scripts/build-image.sh` then `scripts/install.sh`. Verify with
   `scripts/verify.sh`.
2. **"is hshell healthy?" / "verify"** → `scripts/verify.sh`.
3. **"rebuild the image" / after Dockerfile edits** →
   `scripts/build-image.sh --force`.
4. **"it's broken"** → `scripts/verify.sh` first, fix the specific failure.

## Self-healing

Upstream drifts. When you (Claude) hit any of these, **update in place**:

- `npm install -g @anthropic-ai/claude-code` fails or installs an ancient
  version → check for package rename or newer major.
- Node or Python LTS rolls over (October for Node, October for Python) →
  run `mise latest node@lts` / `mise latest python` on the host, bump the
  `NODE_LTS_VERSION` / `PYTHON_VERSION` pins in `Dockerfile`, update the
  dated comment, rebuild with `build-image.sh --force`.
- Debian stable moves to a new codename and the base image shifts → no
  action needed (`debian:stable-slim` floats), but verify the build still
  succeeds.
- An apt package gets renamed (e.g. `fd-find` → `fd`) → fix the Dockerfile,
  rebuild.
- Doppler / gh install script URL changes → update in Dockerfile, rebuild.

**Always** update the dated `# pinned YYYY-MM-DD` comment when you bump a
version so the next reviewer can see when it was last touched.

**Never** drop sandbox guarantees to work around a build problem. If
`--user` mapping or the blocklist is fighting you, fix the real issue;
do not remove them.

## Out of scope

- Sandbox escape prevention against a malicious container image. We trust
  `hshell:latest` (we built it) and Anthropic's `claude-code` package.
- Network-layer restrictions (egress filtering, LAN blocking). If the
  threat model includes container-to-host localhost services, add
  `--network=none` or custom iptables separately.
- Host writes. Refused by design. If the agent needs to edit the host,
  the user should run the task outside `hshell`.

## Files

| File | Purpose |
|---|---|
| `Dockerfile` | `hshell:latest` image — Debian slim + mise-pinned Node/Python LTS + claude-code + dev CLIs |
| `home-template/CLAUDE.md` | Tells the agent it is sandboxed, what it can/can't see |
| `home-template/settings.json` | Permissive Claude settings (defensive; mostly moot with `--dangerously-skip-permissions`) |
| `scripts/lib.sh` | Shared logging + docker helpers |
| `scripts/hshell` | The launcher — computes mounts, execs `docker run` |
| `scripts/build-image.sh` | Build `hshell:latest` (idempotent; `--force` to rebuild) |
| `scripts/install.sh` | Symlink `hshell` into `/usr/local/bin` (needs sudo) |
| `scripts/verify.sh` | Read-only health check across image + launcher + tools |
```

- [ ] **Step 2: Verify YAML frontmatter parses**

```bash
python3 -c "
import sys, pathlib
p = pathlib.Path('/home/lnxuser/src/setup/.claude/skills/hardened-shell/SKILL.md')
text = p.read_text()
assert text.startswith('---\n'), 'missing frontmatter start'
end = text.index('\n---\n', 4)
fm = text[4:end]
assert 'name: hardened-shell' in fm
assert 'description:' in fm
print('OK')
"
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
cd /home/lnxuser/src/setup
git add .claude/skills/hardened-shell/SKILL.md
git commit -m "hardened-shell: SKILL.md (decision tree + self-healing)"
```

---

## Task 9: Update index + retire the design notes

**Files:**
- Modify: `claude-skills.md`
- Modify: `CLAUDE.md` (repo root)
- Delete: `hardened-shell-notes.md`

- [ ] **Step 1: Update `claude-skills.md`**

Open `/home/lnxuser/src/setup/claude-skills.md`. Replace the entire "Work in progress" section (currently the "hardened-shell (design phase)" stanza starting at `## Work in progress` through the end of the file) with a proper skill entry under `## Skills`. The new content to append under `## Skills` (after the existing `### ubuntu-debloat` stanza, replacing the WIP section):

```markdown
### hardened-shell

Path: `.claude/skills/hardened-shell/`
Entry points:
- `scripts/build-image.sh` — build `hshell:latest`
- `scripts/install.sh` — symlink `hshell` into `/usr/local/bin` (needs sudo)
- `scripts/verify.sh` — health check

Ships `hshell`, a launcher that drops into a hardened Docker sandbox so
Claude (and other agents) can run with `--dangerously-skip-permissions`
without risking the host. Host is bind-mounted read-only at `/host` with
a credential blocklist masking `.ssh`/`.aws`/`.gnupg`/`.netrc`/browser
profiles/etc. `$PWD` is the agent's only writable world at `/work`.
Per-project Claude state persists in `$PWD/.internal/claude/`. Subagents
share `/work` and coordinate via git worktrees under `/work/.worktree/`.

Image is Debian slim with mise-pinned Node + Python LTS, `claude-code`,
and common dev CLIs. Pins self-heal on LTS rollover (see SKILL.md).

Targets: any host with Docker CE. Latest LTS / public-GA only.
```

Make sure to **remove** the "## Work in progress" heading and the
"### hardened-shell (design phase)" stanza at the bottom of the file.

- [ ] **Step 2: Update the repo root `CLAUDE.md`**

In `/home/lnxuser/src/setup/CLAUDE.md`, delete the entire "## Work in progress" section (which currently mentions `hardened-shell-notes.md`). The skill is now shipped, so the WIP note no longer applies.

- [ ] **Step 3: Delete the design notes file**

```bash
git rm /home/lnxuser/src/setup/hardened-shell-notes.md
```

Expected: file removed from working tree and index.

- [ ] **Step 4: Verify the index reflects reality**

```bash
grep -A 1 "hardened-shell" /home/lnxuser/src/setup/claude-skills.md | head
test ! -e /home/lnxuser/src/setup/hardened-shell-notes.md && echo "notes removed"
grep -c "Work in progress" /home/lnxuser/src/setup/CLAUDE.md /home/lnxuser/src/setup/claude-skills.md
```

Expected: `hardened-shell` entry visible in index; `notes removed`; both grep counts are `0`.

- [ ] **Step 5: Commit**

```bash
cd /home/lnxuser/src/setup
git add claude-skills.md CLAUDE.md
git commit -m "hardened-shell: promote from WIP to shipped skill in index + root CLAUDE.md"
```

---

## Task 10: End-to-end smoke test + final verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full verify sweep**

```bash
/home/lnxuser/src/setup/.claude/skills/hardened-shell/scripts/verify.sh
```

Expected: all `[OK]`, final line `[OK]   hshell is healthy`, exit 0.

- [ ] **Step 2: Exercise the launcher end-to-end from a fresh project**

```bash
mkdir -p /tmp/hshell-e2e && cd /tmp/hshell-e2e && git init -q
hshell bash -c '
    set -e
    echo "--- env signals ---"
    echo "HSHELL=$HSHELL  HOST_HOME=$HOST_HOME  HOME=$HOME  USER=$USER  pwd=$(pwd)"
    echo "--- host visible ---"
    ls /host | head -5
    echo "--- blocklist check (should be empty) ---"
    ls -A "$HOST_HOME/.ssh" 2>&1 || true
    ls -A "$HOST_HOME/.aws" 2>&1 || true
    echo "--- host write blocked ---"
    (touch /host/tmp/should-fail 2>&1 || true) | head -1
    echo "--- project write works ---"
    echo "ok" > /work/proof.txt && cat /work/proof.txt
    echo "--- claude state present ---"
    ls /home/agent/.claude/
'
ls -la /tmp/hshell-e2e/.internal/claude/
cat /tmp/hshell-e2e/.gitignore
```

Expected:
- `HSHELL=1`, `HOME=/home/agent`, `pwd=/work`.
- Host listing shows real host dirs.
- Blocklist check shows empty or `(empty or inaccessible — good)`.
- Host write produces a `Read-only file system` error.
- `/work/proof.txt` contains `ok`.
- `.claude/` contains `CLAUDE.md` and `settings.json`.
- Project's `.internal/claude/` is populated and `.internal/` is in `.gitignore`.

- [ ] **Step 3: Confirm memory persistence between invocations**

```bash
cd /tmp/hshell-e2e
hshell bash -c 'echo "from run 1" > /home/agent/.claude/MEMORY.md'
hshell bash -c 'cat /home/agent/.claude/MEMORY.md'
```

Expected: second invocation prints `from run 1` — state survived across container instances.

- [ ] **Step 4: Confirm subagent/worktree pattern works**

```bash
cd /tmp/hshell-e2e
hshell bash -c 'cd /work && git worktree add .worktree/feature-x 2>&1 || true; ls .worktree/'
```

Expected: `.worktree/feature-x` appears. (Worktree creation may warn about missing initial commit — that's fine for the test.)

- [ ] **Step 5: Cleanup**

```bash
cd /tmp && rm -rf /tmp/hshell-e2e
```

- [ ] **Step 6: Final verification — plan is complete**

Read `/home/lnxuser/src/setup/docs/superpowers/plans/2026-04-14-hardened-shell.md` and confirm every task's checkboxes are ticked. `git log --oneline` should show one commit per task (roughly 8–9 commits).

---

## Rollback notes

If any task needs to be undone:

- Image: `docker rmi hshell:latest`
- Launcher symlink: `sudo rm /usr/local/bin/hshell`
- Skill directory: `rm -rf .claude/skills/hardened-shell`
- Per-project state created during smoke tests: `rm -rf <project>/.internal`

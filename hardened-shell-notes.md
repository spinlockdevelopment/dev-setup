# Hardened Shell — design notes (pickup in another session)

Status: **DRAFT / not implemented**. User wants to revise before we build it.

## Goal

A `hshell` command that drops the user into a locked-down Docker container where
Claude Code can run safely. Fast spin-up. Host filesystem read-only. Sensitive
files blocked. `$PWD` is read/write. Claude config persists via COW into
`$PWD/.internal/` instead of writing back to the host `~/.claude`.

## Constraints (from user)

- Fast to spin up when launched from the command line.
- Map the entire host system read-only.
- Block reads to sensitive locations (`.env`, `.ssh`, etc.).
- Read/write + full access to the folder the command was run from.
- Must be able to launch `claude` inside and have it run successfully.
- Claude memory/session storage is a concern — if possible, COW-map it into
  `$PWD/.internal/` (or similar) so writes stay project-local.

## Proposed shape

```
hardened-shell/
├── SKILL.md                # thin, decision-oriented
├── Dockerfile              # base image: claude-code, node, git, rg, build tools
└── scripts/
    ├── build-image.sh      # builds hshell:latest
    ├── hshell              # launcher; installed to /usr/local/bin
    └── verify.sh           # health check
```

`hshell` is ~50 lines of bash that computes mounts, sets up overlayfs, and
execs `docker run`.

## Container design

### Base image

Prebuilt `hshell:latest` with:

- `claude-code` CLI
- Node (for claude + general use)
- `git`, `ripgrep`, `fd`, `bat`, `jq`, `gh`, `curl`, `wget`
- `build-essential` (gcc, make, etc.)
- Non-root user matching host UID/GID

Built once, reused. Spin-up is a `docker run`, ~200ms once image is warm.

### Filesystem strategy — whitelist, not blocklist

**Decision: do NOT bind-mount host `/` and try to mask sensitive paths.**
Blocklists always leak (new tools create new credential files, typos in the
list, etc.). Instead, whitelist specific paths:

- `$PWD` → `/work` rw
- `/etc/resolv.conf` → ro (for DNS)
- `/etc/ssl/certs` → ro (for TLS)
- `~/.gitconfig` → ro (so git commits work with user identity)
- **Nothing else from `$HOME`**

This is simpler, safer, and easier to audit than trying to shadow `.ssh`,
`.aws`, `.gnupg`, `.kube`, `.docker/config.json`, `.netrc`, `.pgpass`, `.env*`,
browser cookies, etc.

### Hardening flags

```
docker run \
  --rm -it \
  --read-only \
  --tmpfs /tmp --tmpfs /run \
  --cap-drop=ALL \
  --security-opt=no-new-privileges \
  --pids-limit=512 \
  --memory=8g \
  --user $(id -u):$(id -g) \
  --network=bridge \
  ...
```

Default Docker seccomp profile is sufficient; custom profile is gilding the
lily unless there's a specific threat model.

### Claude state — the interesting part

Three options considered:

**A. COW into `.internal/` (user's idea; preferred default)**

Use overlayfs on the host before launching:

- `lowerdir` = `~/.claude` (host, read-only to container)
- `upperdir` = `$PWD/.internal/claude-upper`
- `workdir`  = `$PWD/.internal/claude-work`
- merged dir bind-mounted at `/home/user/.claude` inside container

Reads see host config (MCPs, memory, auth). Writes land in `$PWD/.internal/`.
Caveat: overlayfs *inside* a container needs `CAP_SYS_ADMIN` (conflicts with
hardening). Do the overlay mount on the **host** first, then bind-mount the
merged directory in.

Add `.internal/` to `.gitignore` automatically on first run.

**B. Ephemeral tmpfs**

`--tmpfs /home/user/.claude` with a seeded copy of host config at container
start. Simpler, no persistence between invocations. Good for truly isolated
sessions.

**C. Project-local only, no host config**

`-v $PWD/.internal/claude:/home/user/.claude`, no access to host claude config.
User must `claude login` on first run per project. Most secure, most friction.

**Default: A.** Flags `--ephemeral` (B) and `--isolated` (C) to switch.

## Network

Keep outbound (Claude API, apt, npm registries). `--network=bridge` is fine.
Blocking localhost/LAN access requires custom iptables — only worth it if the
threat model includes container → host services.

## Nice-to-have flags

- `--gpu` → pass NVIDIA GPU through (`--gpus=all`)
- `--ssh` → forward SSH agent socket (OFF by default, opt-in only)
- `--port 3000` → publish a port for dev servers
- `--ephemeral` / `--isolated` → switch Claude state strategy
- `--rebuild` → rebuild base image before launching

## Open questions for the next session

1. How much do we actually care about defense-in-depth vs. a reasonable default?
   (Whitelist mounts get us 95% of the value; seccomp/apparmor/userns are
   diminishing returns for most threat models.)
2. Should the base image include language toolchains (Python, Go, JDK) or stay
   minimal and let the user install per-session? Minimal spins up faster but
   first-run-per-project is slower.
3. Claude state strategy — confirm COW-into-`.internal/` is the right default,
   or is ephemeral safer as the default?
4. Do we want `hshell` to be a single bash script or a small Go binary for
   portability + speed? Bash is probably fine.
5. Should we verify the image is fresh (rebuild if >N days old) automatically?
6. Git identity: bind-mount `.gitconfig` read-only, or synthesize one inside
   the container from env vars? Bind-mount is easier, env-var approach is
   cleaner if the user has secrets in `.gitconfig` includes.
7. What happens when the user runs `hshell` in `$HOME` itself? Refuse? Warn?
   (It'd defeat the whole point.)

## What the user wants to revise

User said: "i actually want to revise that somewhat so we will pickup in
another session." Leaving this doc here as the pickup point.

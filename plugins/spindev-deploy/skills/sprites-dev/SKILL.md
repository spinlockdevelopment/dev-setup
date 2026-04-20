---
name: sprites-dev
description: Use when running any `sprite` CLI command or calling the sprites.dev API from Windows/Git Bash — prevents path mangling, flag-ordering bugs, and large-file upload failures. Trigger on any mention of Fly.io Sprites, sprites.dev, `sprite exec`, `sprite api`, `sprite console`, `sprite checkpoint`, `sprite url`, uploading files into a sprite, or deploying/restarting a service in a sprite.
---

# sprite CLI & sprites.dev API — correct usage on Windows/Git Bash

This skill exists because every rule below comes from a real failure. The `sprite` CLI works fine on Linux and macOS; on Windows under Git Bash it silently mangles paths and flags in ways that look like the remote did something weird. Follow the rules here and those classes of bugs go away.

## The core problem: Git Bash path conversion

Git Bash on Windows auto-converts anything that looks like a Unix path into a Windows path before the child process sees it. That silently breaks `sprite` in three ways:

| What you write | What Git Bash actually sends | Result |
|---|---|---|
| `sprite exec -- uname -a` | `sprite exec -- uname -a` | `-a` parsed as a `sprite` flag, not `uname`'s |
| `sprite exec -- cat /etc/os-release` | `sprite exec -- cat C:/Program Files/Git/etc/os-release` | File not found inside the sprite |
| `sprite api /v1/sprites/rd-demo` | `sprite api C:/Program Files/Git/v1/sprites/rd-demo` | Malformed URL |
| `sprite exec --dir /app -- cmd` | `sprite exec --dir C:/Program Files/Git/app -- cmd` | `chdir` fails inside the sprite |

## Rules

### 1. Wrap commands in `bash -c`

Never pass flags or paths directly to `sprite exec`. Go through `bash -c` so the remote bash owns parsing:

```bash
# WRONG — flags get misinterpreted
sprite exec -- uname -a
sprite exec -- python3 --version

# RIGHT — bash -c protects everything
sprite exec -- bash -c "uname -a"
sprite exec -- bash -c "python3 --version"
sprite exec -- bash -c "cat /etc/os-release"
sprite exec -- bash -c "cd /app && pip install -r requirements.txt"
```

### 2. Set `MSYS_NO_PATHCONV=1` for every API call

`sprite api` takes a URL path as its first argument. Git Bash mangles it unless path conversion is disabled:

```bash
# WRONG — path gets mangled
sprite api /v1/sprites/rd-demo/services

# RIGHT — disable path conversion
MSYS_NO_PATHCONV=1 sprite api /v1/sprites/rd-demo/services
```

### 3. API flag ordering: path first, then `--`, then curl flags

The syntax is `sprite api <path> -- [curl-options]`. Curl flags like `-X PUT` go **after** `--`:

```bash
# WRONG — -X parsed as a sprite flag
sprite api -X PUT /v1/sprites/rd-demo/services/web
MSYS_NO_PATHCONV=1 sprite api -- -X PUT /v1/sprites/rd-demo/services/web

# RIGHT — path first, then --, then curl flags
MSYS_NO_PATHCONV=1 sprite api /v1/sprites/rd-demo/services/web -- -X PUT \
  -H "Content-Type: application/json" \
  -d '{"cmd":"python3","args":["app.py"]}'
```

### 4. File uploads: relative paths only

The `--file` flag uses a `source:dest` format. Windows drive letters (`C:`) collide with the `:` separator:

```bash
# WRONG — C: conflicts with source:dest separator
sprite exec --file "C:/Users/User/data/geo.db:/app/data/geo.db" -- echo ok

# RIGHT — cd to the source directory first, use a relative path
cd data/
sprite exec --file "geo.db:/app/data/geo.db" -- bash -c "ls -lh /app/data/geo.db"
```

### 5. Compress large files before upload

Files over roughly 20 MB can hit HTTP 502 during upload. Compress first, decompress inside the sprite:

```bash
cd data/
gzip -k -9 geo.db                                    # creates geo.db.gz locally
sprite exec --file "geo.db.gz:/app/data/geo.db.gz" -- \
  bash -c "cd /app/data && gzip -d geo.db.gz && ls -lh geo.db"
rm geo.db.gz                                          # clean up local copy
```

### 6. Avoid `--dir` entirely; `cd` inside `bash -c`

The `--dir` flag value is path-mangled on Windows. Do the `cd` inside the remote bash instead:

```bash
# WRONG — /app becomes C:/Program Files/Git/app
sprite exec --dir /app -- pip install flask

# RIGHT
sprite exec -- bash -c "cd /app && pip install flask"
```

## Service management

### Create or update a service

```bash
MSYS_NO_PATHCONV=1 sprite api /v1/sprites/SPRITE_NAME/services/SERVICE_NAME -- \
  -X PUT -H "Content-Type: application/json" \
  -d '{
    "cmd": "python3",
    "args": ["app.py"],
    "dir": "/app",
    "http_port": 5000,
    "env": {"KEY": "value"}
  }'
```

Service fields: `cmd` (string), `args` (string[]), `dir` (string), `http_port` (number), `env` (map), `needs` (string[] — dependencies).

### Common service operations

```bash
# List
MSYS_NO_PATHCONV=1 sprite api /v1/sprites/SPRITE_NAME/services

# Logs
MSYS_NO_PATHCONV=1 sprite api /v1/sprites/SPRITE_NAME/services/SERVICE_NAME/logs

# Restart via stop + start (the restart endpoint is unreliable)
MSYS_NO_PATHCONV=1 sprite api /v1/sprites/SPRITE_NAME/services/SERVICE_NAME/stop  -- -X POST
MSYS_NO_PATHCONV=1 sprite api /v1/sprites/SPRITE_NAME/services/SERVICE_NAME/start -- -X POST
```

### URL management

```bash
sprite url                               # show URL (deprecated; prefer `sprite info`)
sprite url update --auth public          # anyone can access
sprite url update --auth sprite          # org members only
```

## Checkpoints

```bash
sprite checkpoint create --comment "description"
sprite checkpoint list
sprite restore v1                        # restore to named checkpoint
```

## Staging deploy flow

The six-step pattern for standing up a short-lived preview of a
repo-hosted app on a public sprites.dev URL. Each app layers its own
file list, entrypoint, env, and auth on top:

1. **Create + select.** `sprite create <name>` then `sprite use <name>`
   (drops a `.sprite` marker in cwd; gitignore it).
2. **Upload in one exec.** Repeated `--file local:remote` flags on a
   single `sprite exec`, with a cheap sanity-check command after the
   `--` (e.g. `bash -c "ls /app && python3 -c 'import app'"`).
3. **Mint per-deploy secrets.** `SECRET=$(python3 -c "import secrets;
   print(secrets.token_hex(32))")` — never commit, never reuse across
   sprites.
4. **Register the service.** `sprite api /v1/sprites/<name>/services/<svc>
   -- -X PUT -H "Content-Type: application/json" -d '{...}'` with
   `cmd`, `args`, `dir`, `http_port`, and any per-deploy `env` secrets.
   Re-running the `PUT` replaces the service — that's the iterate loop.
5. **Flip URL auth.** `sprite url update --auth public` for external
   preview, or keep `sprite` (default) for org-only. Pair `public`
   with an app-layer auth gate; don't run unauthed on an indexable URL.
6. **Capture the URL.** `sprite info` (preferred; `sprite url` is
   deprecated).

**Teardown** — missing from the quick-ref table below:

```bash
sprite destroy <name> --force   # --force skips the TTY prompt; scripting-safe
```

For a worked example of this flow against a real invite-gated Python
app, see [TodSmith `shared/runbooks/sprites-deploy.md`](https://github.com/SmithFamilyPlayground/TodSmith/blob/main/shared/runbooks/sprites-deploy.md).

## Quick reference

| Task | Command |
|---|---|
| Run command in sprite | `sprite exec -- bash -c "command"` |
| Interactive shell | `sprite console` |
| Upload file | `cd dir/ && sprite exec --file "file:/dest/file" -- bash -c "ls /dest/file"` |
| API GET | `MSYS_NO_PATHCONV=1 sprite api /v1/sprites/NAME/endpoint` |
| API PUT/POST | `MSYS_NO_PATHCONV=1 sprite api /v1/sprites/NAME/endpoint -- -X PUT -d '{...}'` |
| Set active sprite | `sprite use SPRITE_NAME` |
| List sprites | `sprite list` |

## Self-healing

If a rule here turns out to be wrong (upstream fixed something, new failure mode discovered), update this file. Every rule should trace back to an actual failure — when adding a new one, prefer a one-line note about the failure that produced it over a long rationale.

**This skill is served from a read-only plugin cache** (`~/.claude/plugins/cache/spindev-deploy@spinlockdevelopment/<version>/`). Edits there do not persist and do not propagate. To actually apply the fix, edit the authoritative copy at `plugins/spindev-deploy/skills/sprites-dev/SKILL.md` in a clone of `spinlockdevelopment/dev-setup`, commit (bringup: straight to `main`; protected: feature branch + PR), and push. Consumers pick it up on their next `/plugin marketplace update`.

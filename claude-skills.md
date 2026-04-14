# Claude skills index

Authoritative catalog of every skill in this repo. Update this file whenever
a skill is added, removed, or materially changed.

## Installing a skill elsewhere

Skills here auto-load when Claude Code runs inside this repo. To reuse one in
another project or your user profile, symlink it:

```bash
# project-level (autoload in the target project only)
ln -s ~/src/setup/.claude/skills/<name> <target-project>/.claude/skills/<name>

# user-level (autoload in every project for your user)
ln -s ~/src/setup/.claude/skills/<name> ~/.claude/skills/<name>
```

Keep symlinks — don't copy. That way updates in this repo propagate
everywhere the skill is installed.

## Skills

### ubuntu-debloat

Path: `.claude/skills/ubuntu-debloat/`
Entry point: `scripts/run-all.sh` (or `scripts/run-all.sh --verify`)

Debloats a fresh Ubuntu desktop install and sets it up for Claude Code and
development. Removes games, office apps, Firefox, and snapd (with an apt pin
to keep it out). Installs Chrome, Docker CE, mise-managed Python/Node/Go/JDK,
Android Studio, and VS Code from native upstream repos. Enables
unattended-upgrades and `ufw`. Ships idempotent scripts with a `--verify`
mode and self-heals on upstream version drift (via
`scripts/check-versions.sh`).

Targets: Ubuntu 24.04+ desktop. Latest LTS / public-GA only.

## Work in progress

### hardened-shell (design phase)

Path: `hardened-shell-notes.md` (root of repo, not yet a skill)

Planned `hshell` command that drops the user into a locked-down Docker
container where Claude Code can run safely: host filesystem whitelisted
read-only, `$PWD` read/write, Claude state COW-mapped into `$PWD/.internal/`.
User plans to revise the design before implementation. Pick up from the
notes file in a fresh session.

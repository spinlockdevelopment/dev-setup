# dev-setup — Multi-agent plugin collection

This repo is a **Codex CLI plugin marketplace**, **Claude Code plugin marketplace**, and **Gemini CLI extension collection**. It publishes specialized skills, slash commands, hooks, and scripts for developer environments.

## Consumption Models

### Codex CLI (Marketplace)
This repo contains a Codex marketplace at
`.agents/plugins/marketplace.json`. The marketplace entries point at the
same local plugin folders used by Claude and Gemini.

```bash
codex plugin marketplace add /path/to/dev-setup
```

### Gemini CLI (Extensions)
This repo contains three Gemini CLI extensions. Install them individually:

```bash
gemini extensions install ./plugins/spindev-core
gemini extensions install ./plugins/spindev-devenv
gemini extensions install ./plugins/spindev-deploy
```

### Claude Code (Marketplace)
Add this marketplace and enable plugins in `.claude/settings.json`. See [README.md](README.md) for details.

## Project Structure

```
plugins/
  spindev-core/
    .codex-plugin/plugin.json       ← Codex manifest
    .claude-plugin/plugin.json      ← Claude manifest
    gemini-extension.json           ← Gemini manifest
    commands/                       ← Slash commands (.toml for Gemini, .md for Claude)
    skills/                         ← Agent skills (SKILL.md shared across agents)
    agents/                         ← Subagents (.md shared across agents)
    hooks/                          ← PreTool hooks (hooks.json polyglot)
```

## Available Commands

| Command | Purpose |
|---|---|
| `/end-session` | Wrap up work, sync docs, and (optionally) ship a PR |
| `/init-project` | Bring a repo up to baseline conventions |
| `/pr-prepass` | Local mirror of PR auto-review CI |
| `/review-plan` | Pre-implementation hardening for plans |
| `/create-gh-token` | Mint and wire a project-specific GitHub PAT |

## Engineering Standards

- **Shared Skills**: `SKILL.md` files are the authoritative source of procedural knowledge for Codex, Claude, and Gemini.
- **Polyglot Hooks**: `hooks/hooks.json` supports both Claude's `PreToolUse` and Gemini's `BeforeTool` events.
- **Command Wrappers**: Each plugin provides `.md` (Claude) and `.toml` (Gemini) wrappers in the `commands/` directory.

## Maintenance

When updating a skill, ensure changes are reflected across Codex,
Claude, and Gemini metadata. Test changes with the target CLIs when
possible.

## Project Mode
Bringup. Commits go straight to `main`.

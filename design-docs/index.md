# Overview

`dev-setup` is a multi-agent plugin marketplace that publishes one set
of skills, slash commands, hooks, and subagents to three CLI agents at
once: Claude Code, OpenAI Codex CLI, and Google Gemini CLI. Each
piece of content lives in a single canonical location under
`plugins/<plugin>/`; per-agent manifests in the same plugin folder
make the same files discoverable from each harness.

The audience is the small group of operators (and the agents working
on their behalf) who use this checkout to bring up new projects, wrap
up sessions cleanly, and reproduce a known development environment on
a fresh machine. It is a personal toolkit before it is anything else;
opinions are explicit, and most skills trace each rule to a real
incident that motivated it.

The repo solves a fragmentation problem. Without it, the same set of
operator habits — "always squash-merge", "always pin LTS", "always
back up to two destinations" — would have to be re-encoded once per
agent (Claude `.md` skills, Gemini extensions, Codex marketplace
entries) and would inevitably drift apart. By publishing a single
shared `skills/` tree behind agent-specific manifests, the same
guidance reaches every agent the operator uses, and an update in one
place propagates to all three on the next `/plugin marketplace
update`.

The repo is in **bringup mode**: commits land directly on `main`, no
feature branches, no PR workflow yet. Promotion to protected mode
(branch protection, mandatory PRs, squash-merge enforcement) happens
when the first feature branch + PR lands. Skills target only LTS or
public-GA upstream versions — never bleeding edge.

## At a glance

| | |
|---|---|
| Repository | <code>https://github.com/spinlockdevelopment/dev-setup</code> |
| Primary languages | Bash (51 scripts), Markdown (46 docs), JSON manifests (14), TOML commands (6) |
| Default branch | `main` |
| Project mode | Bringup (commits to `main` directly) |
| Plugins shipped | `spindev-core`, `spindev-devenv`, `spindev-deploy`, `spindev-docs` |
| Target harnesses | Claude Code · Codex CLI · Gemini CLI |
| License | Not declared in repo |

## How to read this site

- **[Architecture](architecture.md)** describes how the marketplace is
  organized: the four-plugin grouping, how each agent discovers its
  content from the shared layout, and the conventions every plugin
  follows.
- **[Components](components.md)** walks each plugin in turn — what it
  is for, what skills and subagents it ships, and which slash
  commands and hooks come with it.
- **[Development](development.md)** is the operator-facing how-to:
  adding a new skill, slash command, subagent, hook, or whole plugin;
  the validation and self-update flow.
- **[Glossary](glossary.md)** defines the terms this site uses
  consistently — *skill*, *subagent*, *hook*, *plugin*, *marketplace*,
  *harness* — since not all three target agents use them in identical
  ways.

# dev-setup - Multi-agent plugin collection

This repo is a Codex CLI plugin marketplace, Claude Code plugin
marketplace, and Gemini CLI extension collection. It publishes three
plugins of shared skills, command wrappers, hook scripts, and companion
setup scripts.

## Codex Layout

```
.agents/plugins/marketplace.json        Codex marketplace catalog
plugins/<plugin>/.codex-plugin/plugin.json
plugins/<plugin>/skills/<skill>/SKILL.md
plugins/<plugin>/skills/<skill>/README.md
plugins/<plugin>/skills/<skill>/scripts/
```

Codex consumes the same `SKILL.md` files as Claude and Gemini. Treat
`plugins/<plugin>/skills/<skill>/SKILL.md` as the authoritative agent
workflow and `README.md` as the human-facing overview.

## Plugin Catalog

- `spindev-core`: project/session lifecycle skills (`end-session`,
  `gh`, `init-project`, `review-plan`) and the `pr-prepass` agent prompt.
- `spindev-devenv`: developer-machine setup and sandboxing
  (`create-gh-token`, `hardened-shell`, `my-status-line`,
  `ubuntu-debloat`).
- `spindev-deploy`: deployment-target references (`flyio`,
  `sprites-dev`).

## Maintenance Rules

- Keep Claude, Gemini, and Codex metadata in sync when plugin names,
  descriptions, versions, skills, commands, or install instructions
  change.
- Add Codex plugin metadata in
  `plugins/<plugin>/.codex-plugin/plugin.json`.
- Add Codex marketplace entries in `.agents/plugins/marketplace.json`.
- Do not edit installed plugin caches; update this source checkout.
- Preserve existing user changes in the worktree.

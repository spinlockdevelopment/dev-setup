# review-plan

Hardens a freshly generated implementation plan before you execute it.

Runs a simplification pass (DRY / YAGNI / scope) plus an adversarial
cross-model pass (`/codex:adversarial-review`) over a plan file, lets
you triage findings, applies accepted edits, and — for long plans —
injects `### Checkpoint` review blocks at logical subsystem / layer /
dependency breaks. Detects parallel-track plans and offers a
worktree-per-track execution model.

Trigger with `/review-plan` or phrases like "review the plan", right
after `superpowers:writing-plans` produces a plan.

## More

- Claude-facing decision tree, flags, prerequisites: [`SKILL.md`](./SKILL.md)
- Install intent + symlink instructions: [root README](../../../README.md)
- Catalog entry: [`claude-skills.md`](../../../claude-skills.md)

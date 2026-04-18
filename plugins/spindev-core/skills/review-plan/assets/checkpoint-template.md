---

### Checkpoint <LETTER> — after Tasks <N>-<M>

Before starting Task <M+1>, run the cross-model checkpoint review.

- [ ] **Step 1: Identify the batch range**

Record the SHAs that span this batch:

```bash
CHECKPOINT_BASE=<SHA at start of this batch, or the previous checkpoint's HEAD>
CHECKPOINT_HEAD=$(git rev-parse HEAD)
```

- [ ] **Step 2: Dispatch same-model code-reviewer**

Use `superpowers:requesting-code-review` to dispatch the `superpowers:code-reviewer` subagent:

- WHAT_WAS_IMPLEMENTED: Tasks <N> through <M>
- PLAN_OR_REQUIREMENTS: the relevant task sections of this plan
- BASE_SHA: `$CHECKPOINT_BASE`
- HEAD_SHA: `$CHECKPOINT_HEAD`
- DESCRIPTION: "Checkpoint <LETTER>: Tasks <N>-<M>"

- [ ] **Step 3: Run cross-model codex review**

```bash
/codex:review --wait --scope branch --base $CHECKPOINT_BASE
```

Capture the full output. Do not paraphrase — the verbatim output is the review.

- [ ] **Step 4: Consolidate findings**

Merge both reviews by severity. Treat findings mentioned by both reviewers as high-confidence.

- Fix all Critical and Important issues before continuing.
- Note Minor issues as follow-ups under a `## Review Follow-ups` section at the bottom of this plan.

- [ ] **Step 5: Verify fixes**

- Re-run the test commands for tasks <N> through <M>.
- If fixes were substantive, re-dispatch `superpowers:code-reviewer` on the updated range.
- If a Critical issue came from codex, re-run `/codex:review` on the updated range.

Do not start Task <M+1> until this checkpoint is green.

---

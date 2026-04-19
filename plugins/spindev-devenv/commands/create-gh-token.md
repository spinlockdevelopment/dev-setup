---
description: Mint a fine-grained GitHub PAT tailored to this project (asks 4 short questions), then validate it and wire it into the project's HTTPS git remote so pushes work without a credential prompt
---

Invoke the `create-gh-token` skill to mint a fine-grained GitHub
Personal Access Token tailored to this project. Ask the four
questions (create-repos? org-wide vs select repos? sub-permissions?
branch-protection plan?), produce the concise PAT-creation
checklist, then run `scripts/create-gh-token.sh` to validate the
pasted token and rewrite the project's HTTPS remote URL. Token
lives only in `.git/config`, never pushed.

Arguments: $ARGUMENTS

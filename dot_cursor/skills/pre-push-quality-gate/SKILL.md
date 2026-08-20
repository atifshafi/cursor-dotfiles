---
name: pre-push-quality-gate
description: >-
  Run a structured pre-push quality gate before pushing code. Covers lint,
  CodeRabbit review, test verification, and credential leak checks. Enforces
  the restart rule: if any step causes code changes, restart from step 1.
  Use when the user mentions push, pre-push, quality gate, ready to push,
  or before pushing code.
---

# Pre-Push Quality Gate

Run this checklist before every `git push`. Each step validates the output of prior steps.

**RESTART RULE:** If ANY step requires code changes, restart from Step 1. A lint fix can break a test. A test fix can change coverage. Each step validates all previous steps.

## Detect Repo Type

Determine which repo you are in and apply the matching gate:

| Indicator | Repo Type | Gate |
|-----------|-----------|------|
| `playwright.config.ts` present | Playwright (console-e2e) | Gate A |
| `cypress.json` or `cypress/` present | Cypress (clc-ui-e2e) | Gate B |
| `pytest.ini` or `setup.py` present | Python (ai_systems) | Gate C |

## Gate A: Playwright Repos (console-e2e)

```
Pre-Push Checklist:
- [ ] Step 1: Lint & typecheck
- [ ] Step 2: CodeRabbit review
- [ ] Step 3: Verify tests
- [ ] Step 4: Credential scan
- [ ] Step 5: Final diff review
```

**Step 1 — Lint & Typecheck**
```bash
npm run lint:check
```
Fix all errors. If any fixes were made, **RESTART from Step 1**.

**Step 2 — CodeRabbit Review**
Run `/coderabbit:review uncommitted` or review the diff manually for:
- Logic gaps and error handling omissions
- Selector best practices (prefer `getByRole`/`getByText` over CSS)
- Missing `test.step()` for multi-step scenarios
- Hardcoded waits (`waitForTimeout`)

If moderate+ findings require code changes, fix them and **RESTART from Step 1**.

**Step 3 — Verify Tests**
Run the relevant spec files to confirm they pass:
```bash
npx playwright test <changed-spec-files>
```
If tests fail, fix and **RESTART from Step 1**.

**Step 4 — Credential Scan**
Check staged files for credential leaks:
```bash
git diff --cached --name-only | xargs grep -l -i -E '(password|token|secret|api.key|bearer)' 2>/dev/null
```
If any matches are real credentials (not variable names or templates), remove them before pushing.

**Step 5 — Final Diff Review**
```bash
git diff --cached --stat
```
Confirm only intended files are staged. No `.env`, `.auth/`, `node_modules/`, or `test-results/`.

## Gate B: Cypress Repos (clc-ui-e2e)

Same structure as Gate A, with these command differences:

- **Step 1:** `npx eslint . && npm run lint:fix` (check for changes after fix)
- **Step 3:** `npx cypress run --spec <changed-spec-files>` (or `--headed` for debugging)

## Gate C: Python Repos (ai_systems)

- **Step 1:** `pytest tests/unit/ && pytest tests/regression/` for changed apps
- **Step 2:** `/coderabbit:review uncommitted`
- **Step 3:** Verify knowledge YAML is valid (no syntax errors in changed `.yaml` files)
- **Step 4:** Confirm `.mcp.json`, `settings.local.json`, and token files are NOT staged
- **Step 5:** `git diff --cached --stat` final review

## After All Steps Pass

Confirm with the user before running `git push`. Never push without explicit approval.

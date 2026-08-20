---
name: verify-bug-fix
description: >-
  End-to-end ACM QE workflow: given a JIRA bug key and a live OpenShift/ACM
  environment, gathers JIRA and GitHub context, confirms the fix is in the
  running downstream build (release branch, merge date, optional pod grep),
  maps prerequisites with neo4j-rhacm plus oc checks, runs UI or API
  verification with Playwright MCP, and drafts JIRA verdict comments. Use when
  the user says verify bug, verify fix, bug verification, confirm fix, test fix,
  check if fixed, is the bug fixed, close bug after verification, cherry-pick
  landed, or environment readiness before verifying a fix. Not for: writing new
  product code, authoring Polarion cases, or generic cluster health without a JIRA.
compatibility: >-
  Requires oc and network to the cluster API; gh or GitHub MCP; jira MCP for
  ticket reads and optional writes; neo4j-rhacm MCP for dependency-informed
  prereqs (degrade to heuristics if unavailable); user-playwright MCP for
  console and CSRF-aware API calls. Optional acm-search and acm-kubectl. Cursor
  Task tool or Claude Code Task for three parallel readonly subagents in Phase 1.
metadata:
  skill-standard: anthropic-agent-skills
  version: "1.2.0"
  category: workflow-automation-mcp
disable-model-invocation: true
---

# Verify Bug Fix (ACM)

End-to-end workflow to verify **one JIRA bug** against **one real environment**. This skill is **portable**: it does **not** rely on Engram or other local-only knowledge bases.

## Progressive disclosure (how to load this skill)

This skill follows the **Agent Skills** pattern (Anthropic: *The Complete Guide to Building Skills for Claude*, 2026 PDF; progressive disclosure and folder layout).

| Level | Source | Purpose |
|-------|--------|---------|
| 1 | YAML `description` above | When to invoke; stays in tool metadata |
| 2 | This `SKILL.md` body | Phases, gates, orchestration |
| 3 | `references/*.md` | Detailed bug-type and environment procedures — load when executing that phase |

Keep Level 2 scannable; open `references/verification-patterns.md` and `references/environment-checks.md` instead of duplicating long tables here.

## Mandatory gates

1. **Environment required**: If the user does not provide a cluster/console target (URL, kubeconfig, or clear named env), use the `acm-environment-finder` skill (Mode 1: Find) to locate one matching the bug's fix version. Only ask the user if the finder returns no viable candidates.
2. **Read-only by default**: `oc get`, `oc describe`, logs, GitHub/JIRA reads — no permission needed.
3. **State changes** (`oc apply`, `oc patch`, operator refresh, JIRA comment/transition): follow global `.cursorrules` — **ask first**, wait for explicit approval.
4. **JIRA transitions**: Never transition to Closed without user approval of the drafted comment and verdict.
5. **Kubeconfig isolation**: Use a session-specific `KUBECONFIG` path; verify with `oc whoami --show-server` before hub/spoke work.

On skill start, create a **TodoWrite** covering: Phase 0 intake (+ env discovery + scope + Engram recall) → Phase 1 parallel agents → Phase 2 merge → Phase 2b code review → Phase 2.5 prereqs → Phase 2.75 health gate → Phase 3 verify (A: backend, B: UI) → Phase 4 verdict/JIRA → Phase 4.5 learning → cleanup.

---

## ASK QUESTIONS FIRST

| Missing input | Ask |
|---------------|-----|
| JIRA key | Exact key (e.g. ACM-33072) |
| Environment | Console URL, API URL, which cluster, kubeconfig location |
| Credentials | How to log in (kubeadmin vs SSO vs Keycloak user); FG-RBAC test user if needed |
| Risk tolerance | OK to create inform-only policies / size-0 pools? OK to refresh catalog? |

---

## Use cases and success criteria

**Category:** Workflow automation with multiple MCP servers (per Anthropic: skills teach *how*; MCP provides *access*).

| Use case | Trigger | Result |
|----------|---------|--------|
| Single-bug verification | User gives ACM-* key + env | Verdict table (FIXED / NOT FIXED / BLOCKED) with DOWNSTREAM tag and evidence |
| Cherry-pick readiness | User asks if fix is in 2.YY nightly | Branch analysis + optional Tier C code check before any UI work |
| Prereq-only assessment | User asks if env can reproduce bug X | Phase 2.5 gap table without Phase 3 |

**Success (qualitative):** User can paste the verdict table into JIRA; another QE can reproduce the same conclusion from the documented steps. **Iteration:** If the skill under-triggers, add trigger phrases to `description`; if over-triggers, tighten the "Not for" clause.

---

## Examples

### Example 1 — Console UI layout bug

**User:** "Verify ACM-31343 is fixed on https://console-openshift-console.apps…"

**Actions:** Phase 1 parallel → Phase 2 Tier A shows PR merged to `release-2.17` → Phase 2.5: neo4j hints + `oc get clusterpool` (create size-0 pool **only after** user approves) → Phase 3: Playwright screenshots at multiple viewports → Phase 4: draft "Verified fixed on …-DOWNSTREAM-…".

### Example 2 — Backend proxy error message

**User:** "Confirm ACM-30204 on this hub; kubeconfig in …"

**Actions:** Tier C `oc exec` into console pod + grep for new error-handling pattern; Playwright `browser_evaluate` `fetch` for API body. Verdict FIXED with grep snippet and response excerpt.

### Example 3 — Fix on main only

**User:** "Verify ACM-33072 on 2.17 nightly."

**Actions:** PR Analyzer shows merge to `main` only, no `release-2.17` → **BLOCKED** before heavy UI; JIRA draft cites missing cherry-pick.

---

## Testing and iteration (for skill authors)

Per Anthropic testing guidance, validate three dimensions when changing this skill:

1. **Triggering:** Paraphrases ("is this JIRA fixed on bm12?") should still match intent in `.cursorrules` + `description`. Unrelated queries should not load this skill.
2. **Functional:** Run one closed bug (known FIXED) and one open bug with main-only PR (known BLOCKED); outputs must match.
3. **Regression:** After edits, re-check that `references/` paths resolve and `compatibility` still lists true requirements.

Bring failing chat excerpts back into the skill text (tighten gates, add troubleshooting row).

---

## Troubleshooting

| Symptom | Cause | What to do | Verdict Impact |
|---------|--------|------------|----------------|
| Skill never loads | Sparse user wording | User names JIRA key + "verify" / "confirm fix"; or invoke skill by name | N/A |
| BLOCKED but dev insists fix shipped | Tier C not run | Run `oc exec` grep or image label check from `acm-operations` Op 3 | May upgrade BLOCKED → FIXED if code found |
| Playwright login loops | Wrong IDP tab | Snapshot; use Keycloak-specific selectors per `references/environment-checks.md` | Falls back to backend-only if unresolved |
| Neo4j empty | Schema drift | Fall back to JIRA component + `references/environment-checks.md` capability matrix | Prereq confidence drops to LOW |
| Playwright stuck after navigate | Login redirect / slow load | `browser_snapshot`; increase wait; confirm route | Retry once, then fall back to backend-only |
| 403 on console API | Wrong user session | Confirm RBAC; retry with cluster-admin only to isolate | May indicate NOT_FIXED if RBAC-related bug |
| Empty policy list | Wrong context | Wrong namespace or hub vs spoke kubeconfig | Recheck kubeconfig; not a verdict issue |
| Pool UI empty but CR exists | UI filter / permissions | Refresh; check console filter; confirm user can `get clusterpools` | May be Trap 2 (environment issue) |
| Eval fetch CORS / network | Cross-origin path | Use same-origin path; mirror URL from working Network tab call | Falls back to backend-only for API checks |
| Jira MCP unavailable | Token expired | Re-authenticate; check env vars | Cannot start — STOP |
| acm-source unavailable | Not configured | Skip source cross-validation | Loses 1 Tier 1 evidence point |
| acm-search unavailable | Not connected | Use direct `oc` commands (slower) | No verdict impact (equivalent path exists) |
| acm-kubectl unavailable | Not configured | Manual spoke commands or skip spoke checks | May reduce prereq coverage |

---

## Delegated skills (do not duplicate)

| Skill | When |
|-------|------|
| `~/.cursor/skills/acm-environment-finder/SKILL.md` | Phase 0: No environment provided → auto-discover a hub matching the bug's fix version |
| `~/.cursor/skills/acm-operations/SKILL.md` | Op 1: full DOWNSTREAM build tag; Op 3: fix-in-image checks; Op 2 only if user approves refresh |
| `~/.cursor/skills/jenkins-expert/SKILL.md` | Optional — user wants a **new** env or pipeline parameters for a snapshot |

Bundled references (Level 3): `references/environment-checks.md` and `references/verification-patterns.md`.

---

## MCP and tools

| MCP / tool | Role |
|------------|------|
| `jira` | `get_issue`, `search_issues`, `add_comment`, `transition_issue` (writes need approval) |
| `github` or `gh` | PR list by JIRA key, base branch, merge date |
| `neo4j-rhacm` | Phase 2.5 — component dependencies for prerequisite planning |
| `user-playwright` | **All** browser automation (login, navigation, screenshots, `browser_evaluate` + `fetch`) |
| `acm-search` | Recommended for fleet-wide prerequisite checks (when target matches connected hub in `notes/notes.md` line 2). Use `find_resources` for resource existence checks across clusters. Fall back to `oc` if cluster mismatch or MCP errored. |
| `acm-kubectl` | Spoke commands (`clusters`, `kubectl`) when managed cluster access is needed |

**Do not** use `cursor-ide-browser` for OCP login-heavy flows — Playwright is default (password fields, OIDC).

---

## Hard rules (evidence quality)

1. **Branch ≠ build**: `main`-only merges are **not** in `release-2.XX` nightlies until merged/cherry-picked to that branch.
2. **Report full DOWNSTREAM tag** in every verdict table (not CSV semver alone). See `acm-operations` Op 1. When the catalog uses a floating tag (e.g. `latest-2.17`), use the fallback method below to resolve the dated tag.
3. **Playwright over cursor-ide-browser** for console and OAuth forms.
4. **OIDC**: use **ID token** for `oc login --token` when using token grant.
5. **Console proxy / CSRF**: use in-page `fetch` via `browser_evaluate`; include `X-CSRFToken` from `document.cookie`.
6. **Code inspection is valid**: `oc exec` into console pod + `grep` on compiled output counts as definitive when UI trigger is impractical.
7. **Cherry-pick discovery**: `gh pr list --search "ACM-XXXXX" --state all --base release-2.YY` in relevant repos (console, backplane, etc. — infer from component).
8. **Multi-bug sessions**: when verifying several tickets on the same env, batch PR branch analysis **once** before deep env work.
9. **PR code review is mandatory**: Before declaring FIXED, review the actual code diff (`gh pr diff`) to confirm the change is correct, minimal, and doesn't introduce side effects. A fix being "in the build" is necessary but not sufficient.
10. **DOWNSTREAM tag from floating catalog** (fallback): When `acm-operations` Op 1 cannot resolve a dated tag because the catalog uses a floating tag (e.g. `latest-2.17`), use this sequence:
    - `oc get csv -n <acm-ns> --no-headers | grep advanced-cluster-management` → get version (e.g. `2.17.0-236`)
    - `oc get csv <csv-name> -n <acm-ns> -o jsonpath='{.metadata.annotations.createdAt}'` → get build date
    - Format as: `<version>-DOWNSTREAM-<YYYY-MM-DD>` (e.g. `2.17.0-DOWNSTREAM-2026-05-15`)
    - The `createdAt` annotation is the bundle build timestamp — it tells you when the nightly was produced.

---

## Phase 0 — Intake

1. Parse **JIRA key** and **environment** from user message.
2. **Determine scope** (from user input or natural language):
   - **Full** (default): All phases through Phase 3 + verdict. Produces FIXED/NOT FIXED/BLOCKED with any qualifier.
   - **Presence-only** ("is the fix in the build?", "cherry-pick check"): Phases 0-2b only. Maximum verdict = FIXED (code-only). Skips Phases 2.5, 2.75, and 3. JIRA template includes: "Fix presence confirmed. Full verification pending." Skill MUST NOT offer to transition ticket to Closed. Creates TodoWrite reminder to return for full verification.
   - **Prereq-only** ("can this env reproduce the bug?"): Phases 0-2.5 only. Output = gap table. No verdict issued.
3. If environment missing:
   - Extract ACM version from JIRA `fix_versions` (e.g. "ACM 2.17.0" → search for `2.17`).
   - Run `~/.cursor/skills/acm-environment-finder/SKILL.md` (Mode 1: Find) with that version.
   - If the finder returns candidates, proceed with the best match (healthiest, freshest, with kubeconfig artifact).
   - If the finder returns nothing viable → ask the user for an environment.
   - For bugs requiring specific capabilities (hosted clusters, spoke clusters, CNV/MTV), pass those as criteria to the finder or filter candidates after discovery.
4. Initialize TodoWrite with phases below.
5. **Engram context recall** (optional, additive — skip silently if Engram unavailable):

   ```
   engram_recall("verify <JIRA-KEY>")
   engram_recall("<component> verification patterns")
   ```

   - If previous attempt found on the same ticket: surface to user ("Previous session found BLOCKED due to missing cherry-pick on [date]. Has anything changed?"). If user confirms unchanged → skip to verdict with same conclusion.
   - If relevant component patterns found: incorporate into Phase 2.5 prereq planning.
   - If Engram unavailable or returns nothing: proceed normally. This is additive context, not a hard dependency.

6. Schedule **three parallel subagents** (Cursor **Task** tool with `subagent_type: generalPurpose` or `explore`, readonly for Phase 1):

### Subagent 1 — JIRA Analyzer

- `jira` `get_issue` for the key.
- Extract: summary, description, steps to reproduce, expected/actual, component, fix versions, links, attachments.
- Classify bug type (UI-layout, UI-functional, backend, RBAC, data).
- Output: **structured bug profile** JSON-like bullet list.

### Subagent 2 — Environment Assessor

- Connect: standard `oc login` or OIDC ID-token login per `references/environment-checks.md`.
- Run `acm-operations` **Op 1** mentally: catalog pod → bundle digest → `oc image info` → DOWNSTREAM tag.
- Check capabilities: MCH flags, FG-RBAC, managed clusters, add-ons (CNV/MTV), Hive/pools, policies, OAuth IDPs.
- Incorporate **neo4j-rhacm**: given component name from JIRA, run dependency-oriented Cypher (see Phase 2.5) to list likely dependent operators/subsystems; map to `oc` checks.
- Output: **environment profile** + server URL + ACM namespace used.

### Subagent 3 — PR Analyzer

- `gh pr list --search "<KEY>" --state all --json number,title,state,mergedAt,baseRefName` across inferred repos (start with `stolostron/console` for Console component; expand if issue points elsewhere).
- Determine merge target branches; identify missing `release-2.XX` cherry-picks.
- Output: **fix presence hypothesis** (likely-in-build vs likely-not) with PR numbers and dates.

Wait for **all three** before Phase 2.

---

## Phase 2 — Merge, fix presence, strategy

1. Merge the three reports into a single working summary.
2. **Fix presence (three tiers)**:

   - **Tier A — Branch match**: Is there a merged PR to the **same branch** that produced this downstream build (e.g. `release-2.17`)?
   - **Tier B — Date**: If ambiguous, compare PR `mergedAt` to bundle **build-date** (merge must be before build). **Pipeline lag note**: If Tier A passes but PR merged <24 hours ago AND Tier C is unavailable, treat as lower confidence (pipeline race possible — see `acm-operations` Op 3 timeline: 0-6h = NO, 6-12h = MAYBE, 12-24h = LIKELY, 24h+ = YES). Recommend Tier C grep to confirm.
   - **Tier C — Code**: If still uncertain, `oc exec` + grep or `oc image info` labels / VCS ref per `acm-operations` Op 3 patterns.

3. If fix **not** in build → **BLOCKED** (cherry-pick or upgrade path). Document for JIRA draft. **Do not** claim NOT FIXED for missing code — blocker is separate.
4. If fix **in** build → proceed to Phase 2b (code review) before UI work.

### Multi-PR Fixes (with dependency awareness)

If Phase 1 finds multiple PRs referencing the Jira key:

1. **Classify each**: PRIMARY fix vs RELATED cleanup vs TEST-ONLY.
2. **Dependency ordering** (if `neo4j-rhacm` MCP available): query the component graph for relationships between affected repos/components.
   - If dependency exists (e.g., backend API → UI consumer): verify the upstream (backend) PR first.
   - If no dependency edge: verify in any order.
3. **Fallback ordering** (if neo4j unavailable): backend PRs before frontend PRs, framework/shared-lib PRs before consumer PRs.
4. **Gating**: ALL PRIMARY PRs must pass Tier A/B to proceed. Any single PRIMARY miss = BLOCKED.
5. **Recording**: Document all PR numbers + verification order in the verdict table.

---

## Phase 2b — PR code review (fix correctness)

**Purpose**: Understand what the code change actually does so that Phase 3 verification is informed and thorough. The code review serves two goals:
1. Confirm the fix logically addresses the root cause (a fix can be "in the build" but still be wrong).
2. Identify what else the change touches so Phase 3 can include targeted regression checks on adjacent functionality — not just the direct ticket repro.

### Step 1 — Read the diff

Run `gh pr diff <PR_NUMBER> --repo <repo>` for each fix PR. For large PRs, focus on:
- The file(s) directly related to the bug (e.g. the component/page mentioned in JIRA).
- Test files — do they cover the reported scenario?

### Step 2 — Assess fix correctness

For each PR, determine:

| Question | How to answer |
|----------|---------------|
| Does the change address the root cause described in JIRA? | Compare PR diff against bug description / dev comments |
| Is the change minimal and scoped? | Large refactors alongside a one-line fix → higher risk |
| Are tests added/updated for the fix? | Check if test expectations match the expected behavior from JIRA |
| Could the change break adjacent functionality? | Check if modified code is shared by other call sites |

### Step 3 — Risk and side-effect assessment

Classify:
- **Low risk**: Single-value change, default removed/added, CSS-only fix with test coverage.
- **Medium risk**: Logic change affecting shared utility, API parameter addition, refactored flow.
- **High risk**: Large refactor bundled with fix, changed function signatures used by multiple callers.

For medium/high risk: note specific areas to watch during UI verification (Phase 3). For example, if a utility function was refactored, verify both the originally-broken page AND any other page that uses the same utility.

### Step 4 — Record findings

Add to the evidence bundle:
- Fix summary (what the code change actually does, in plain language).
- Risk level.
- Any areas to spot-check during verification beyond the direct repro.

If the code review reveals the fix is **clearly wrong** (e.g. addresses wrong component, introduces obvious null-ref), mark **NOT FIXED (code review)** without needing UI verification.

---

## Phase 2.5 — Prerequisite analysis (neo4j + cluster)

**Purpose**: Ensure the environment can exercise the repro **before** spending time in UI.

### Step 1 — Dependency graph (neo4j-rhacm)

Ask the graph what the affected subsystem depends on (adapt labels to your graph schema — see `.cursor/rules/neo4j-rhacm.mdc` in automation workspace for patterns). Example intent:

```cypher
MATCH (source)-[r]->(target)
WHERE toLower(source.label) CONTAINS $componentHint
RETURN target.label AS dependency, type(r) AS rel
LIMIT 50
```

Use results to **prioritize** operator and CRD checks — not as a substitute for `oc`.

### Step 2 — Map repro text to prerequisites

From JIRA steps, list concrete needs:

- Operators (CNV, MTV, MCE, Hive, …) → `oc get csv -A`
- MCH feature flags → `oc get mch -n <ns> -o yaml`
- Users / IDPs / MCRAs → `oauth`, `user`, `multiclusterroleassignments`
- Resources (VM, policy, pool, placement, spoke) → targeted `oc get`

**acm-search alternative** (when target cluster matches connected hub): Use `find_resources` for broad existence checks before targeted `oc` queries:
- `find_resources(kind="ClusterServiceVersion", namespace="open-cluster-management*")` — all installed operators at once
- `find_resources(kind="ManagedCluster", outputMode="list")` — enumerate spokes
- `find_resources(kind="VirtualMachine")` or `find_resources(kind="Policy")` — verify prerequisite resources exist

These supplement `oc` (faster for fleet-wide checks) but do not replace it for detailed YAML inspection. If results are empty and resources should exist, verify with `oc get` (possible index staleness).

### Step 3 — Gap table

For each prerequisite: **PRESENT** | **MISSING** | **UNKNOWN**.

### Step 4 — Missing items

For every **MISSING** that requires **create/patch**:

1. Show exact YAML or command.
2. Ask user: **"Proceed to create/patch on cluster X?"**
3. If **no** → BLOCKED (cannot verify) or partial verification with explicit limitations.
4. If **yes** → use **minimal** test objects (`inform` policies, `size: 0` pools, `bug-verify-*` names). Re-run Step 3 until satisfied or blocked.

### Step 5 — Gate to Phase 3

Only enter execution when prereqs are met or user accepts reduced scope in writing.

---

## Phase 2.75 — Environment Health Gate

**Purpose**: Catch functional degradation that prerequisite checks miss. Phase 2.5 confirms operators/CRDs **exist**; this phase confirms they're **working correctly**. Prevents wasting 5-10 minutes of Playwright work on an environment where the bug's subsystem is degraded.

Invoke `~/.cursor/skills/acm-live-investigator/SKILL.md` at **Quick depth**, scoped to the bug's subsystem:

| Health Gate Result | Action |
|-------------------|--------|
| Critical issues found (pods crashlooping, routes unreachable, database corrupted) | **BLOCKED (environment)** — skip Phase 3 entirely |
| Minor issues found (non-critical warnings, slow but functional) | Warn user, ask: "Environment has minor issues: [list]. Proceed with verification anyway? [Yes / No]" |
| Healthy | Proceed to Phase 3 |

This catches diagnostic traps (1-14 from `diagnostics/diagnostic-traps.md`) that Phase 2.5 cannot detect:
- Trap 1: MCH status stale (operators installed but not reconciling)
- Trap 2: console-mce pod down (feature tabs missing despite CSV healthy)
- Trap 13: ConsolePlugin backend unreachable (plugins registered but broken)
- Trap 3: search-postgres data loss (search indexer healthy, database empty)

If `acm-live-investigator` skill is not available or times out: proceed with a warning ("Health check skipped — if verification produces unexpected results, consider running a cluster health check first.").

---

## Phase 3 — Execute verification

**Primary goal**: Confirm the fix is working. Two paths run in sequence; Path B is conditional.

### Phase 3A — Backend Verification (ALWAYS runs)

1. **Resource state**: `oc get/describe` resources affected by the bug.
2. **Tier C evidence** (if not already done in Phase 2): `oc exec deploy/<component> -- grep "<fix-indicator>" <path>`.
3. **Source cross-validation** (if acm-source MCP available): `search_code(query="<distinctive string from fix PR>", repo="<component repo>")`. If the fix pattern is found in source at the deployed version → Tier 1 evidence. If NOT found → red flag even when Tier A passed (possible merge conflict dropped the change); warn user and suggest Tier C before proceeding.
4. **API behavior checks**: `oc exec` or `browser_evaluate` fetch with CSRF for console proxy endpoints.
5. **Log inspection**: `oc logs deploy/<component> --tail=100` — check for error patterns from the JIRA.

### Phase 3B — UI Verification (conditional on credentials + Playwright)

**Skip conditions** (any one → skip to Phase 3B-Skip):
- No console credentials available → qualifier = "code-only"
- Playwright MCP unavailable → qualifier = "backend-only"

If skipping: set verdict qualifier and proceed to Phase 4 with Phase 3A evidence only.

**If proceeding:**

1. **Login**: always **user-playwright** MCP.
   - Standard: `browser_fill_form` on kubeadmin/htpasswd fields.
   - OIDC/Keycloak: follow env-specific flow; prefer stable selectors; snapshot on failure.
   - FG-RBAC: use the **affected** user from user input.

2. **By bug type** — follow `references/verification-patterns.md`:
   - UI layout: multiple viewports + zoom if in repro.
   - UI functional: step-through with snapshots on ambiguity.
   - Backend: `browser_evaluate` async `fetch` with CSRF header; capture status + body.
   - RBAC: repeat flows under limited user.
   - Data: CLI + UI table alignment.

3. **Spokes**: if repro needs spoke, confirm `ManagedCluster` is **Available** and which kubeconfig/context to use (`acm-kubectl` if configured).

4. **Save screenshots** to `/tmp/screenshots/verify-<JIRA-KEY>-<step>.png` for use in Phase 4 JIRA comment.

### Playwright Recovery Protocol (Phase 3B)

On Playwright failure mid-verification:

1. Capture the error message + last `browser_snapshot` result.
2. **Retry once**: fresh `browser_navigate` to the console URL (new session).
3. If retry succeeds: resume from the failed step.
4. If retry fails: fall back to Phase 3A evidence only.
   - Set verdict qualifier = "backend-only, UI blocked by Playwright failure"
   - Include the Playwright error in the evidence bundle (user may want to investigate separately)
   - Do NOT declare NOT_FIXED based on Playwright failure alone — the fix may work, the browser tooling just couldn't confirm it.

### Step 2 — Regression spot-checks (informed by Phase 2b)

After confirming the direct fix works, run targeted regression checks based on Phase 2b findings. The regression scope is proportional to risk:

- **Low risk** (with tests in PR): Direct repro only — Step 1 is sufficient.
- **Low risk** (no tests): Direct repro + one adjacent check on the same page/flow.
- **Medium risk** (with tests): Direct repro + check shared call sites (up to 3).
- **Medium risk** (no tests): Direct repro + all shared call sites identified in Phase 2b.
- **High risk** (any): Direct repro + systematic check of ALL call sites identified in Phase 2b.

**ACM-specific regression examples:**
- Console regression → check other pages using the same utility (e.g., if `fireManagedClusterView()` fixed, also check template details page).
- GRC regression → check policy table AND template views if shared compliance logic changed.
- Search regression → check multiple resource types if search-api filter logic changed.
- Virt regression → check VM actions on both list and detail views if shared action handler changed.

### Step 3 — Record evidence

Record **evidence bundle**: build tag, PR links, commands run (read-only), screenshots or redacted JSON snippets. Include both Phase 3A results AND Phase 3B results (or skip reason).

---

## Phase 4 — Verdict and JIRA

### Pre-verdict gate: failure-signature disambiguation

Before finalizing a **NOT FIXED** verdict, check whether the observed symptom matches a known infrastructure trap or failure signature that could be masquerading as a persistent bug:

1. Search `acm-knowledge` MCP: `search_knowledge(query="failure signature <subsystem> <observed symptom>")`
2. Cross-reference `diagnostics/diagnostic-traps.md` for matching trap patterns (14 documented traps where the obvious diagnosis is wrong — e.g., Trap 2: console-mce pod down causing missing feature tabs, Trap 8: search-api down breaking multiple pages).
3. If a match is found → reclassify as **BLOCKED (environment)** — the environment issue is preventing valid verification, not the fix being wrong.
4. If no match → proceed with NOT FIXED as the final verdict.

If `acm-knowledge` MCP is unavailable, scan the relevant failure-signatures file directly: `notes/knowledge/failures/<subsystem>/failure-signatures.md`.

### Verdict table (required)

| Field | Value |
|-------|--------|
| JIRA | ACM-XXXXX |
| Verdict | FIXED / NOT FIXED / BLOCKED |
| Qualifier | (full) / (code-only) / (backend-only) / (code review) / (cherry-pick) / (pipeline lag) / (environment) |
| Confidence | HIGH / MEDIUM / LOW (from evidence tier weights) |
| DOWNSTREAM tag | full string |
| Fix PR(s) | #numbers + branches |
| Evidence | bullets with tier tags |
| Secondary issues | optional |

### Verdict + Qualifier combinations

| Verdict | Qualifier | When | JIRA Action |
|---------|-----------|------|-------------|
| FIXED | (full) | Code present + UI verified (Phase 3A + 3B pass) | Close ticket |
| FIXED | (code-only) | Code confirmed, UI not possible (no credentials) | Close with note |
| FIXED | (backend-only) | Backend verified, Playwright unavailable/failed | Close with note |
| NOT FIXED | (standard) | Bug still reproduced in Phase 3B | Reopen |
| NOT FIXED | (code review) | Fix is incorrect per Phase 2b analysis | Reopen with PR feedback |
| BLOCKED | (cherry-pick) | Fix not in target branch (main-only) | Comment, leave open |
| BLOCKED | (pipeline lag) | Merged to branch but build predates fix | Comment, leave open |
| BLOCKED | (environment) | Cluster unhealthy for valid verification (Phase 2.75 or failure-sig gate) | Comment, leave open |

### JIRA actions

1. Draft comment in markdown/plain suitable for JIRA.
2. Ask user: post comment? transition to Closed?
3. On approval: `add_comment` (with `attachment_paths` and `inline_attachment_paths` for screenshots if available), then `transition_issue` if appropriate.

### Evidence tier weights (for confidence scoring)

Per `diagnostics/evidence-tiers.md` in the knowledge DB:

| Evidence | Tier | Weight | Source |
|----------|------|--------|--------|
| Branch match (Tier A) | 1 | 1.0 | `gh api repos/.../compare` |
| Build date >= merge date (Tier B) | 1 | 1.0 | DOWNSTREAM tag vs `mergedAt` |
| Code grep in container (Tier C) | 1 | 1.0 | `oc exec` |
| acm-source cross-validation | 1 | 1.0 | acm-source MCP `search_code` |
| UI repro passes (Phase 3B) | 1 | 1.0 | Playwright |
| PR code review positive (Phase 2b) | 2 | 0.5 | `gh pr diff` analysis |
| Backend logs clean (Phase 3A) | 2 | 0.5 | `oc logs` |

**Confidence calculation**: sum of achieved Tier weights / maximum possible weight.
- **HIGH** (>= 0.8): 4+ Tier 1 evidences achieved.
- **MEDIUM** (0.5–0.79): 2-3 Tier 1 evidences.
- **LOW** (< 0.5): Mostly Tier 2 / inference.

Include confidence in the verdict table: `FIXED (full, confidence: HIGH — 5 Tier 1 evidences)`.

---

## Cleanup

If test resources were created with approval, delete them and note cleanup in the session summary. Remove temp pull-secret files from disk.

---

## Phase 4.5 — Post-Verdict Learning

Store verification outcomes for future sessions. This makes every verification a learning opportunity.

1. **Engram store** (if available):

   ```
   engram_remember("Verified ACM-XXXXX: <verdict> (<qualifier>) on <DOWNSTREAM tag>. Key finding: <1 sentence>.")
   ```

2. **Knowledge DB update** (per auto-update protocol — no permission needed for `notes/knowledge/` writes):
   - If the verification revealed a **new failure pattern** not already in `failures/<subsystem>/failure-signatures.md` → append it with today's date and evidence.
   - If the verification discovered a **new diagnostic trap** (environment issue masquerading as a bug) → flag for manual review. Do not auto-append to `diagnostic-traps.md` without verification against a second environment.

3. **Skip conditions**: If Engram is unavailable or knowledge DB path is unreachable, skip silently. Learning is additive, never blocking.

---

## Relationship to `acm-bug-hunter`

| Skill | Direction |
|-------|-----------|
| `acm-bug-hunter` | Adversarial **discovery** of defects from requirements/tests |
| `verify-bug-fix` | Controlled **confirmation** that a **known** JIRA is resolved on a **given** build |

They complement each other; do not merge workflows.

---

## Quick reference — verdict meanings

- **FIXED (full)**: Code present in build + UI verification passes + backend clean.
- **FIXED (code-only)**: Code present + code review positive, but UI verification not possible (no credentials).
- **FIXED (backend-only)**: Backend verification passes, Playwright unavailable or failed.
- **NOT FIXED (standard)**: Code present + defect still reproduced (regression or insufficient fix).
- **NOT FIXED (code review)**: Code present but fix is clearly incorrect (wrong component, introduces new defect).
- **BLOCKED (cherry-pick)**: Code absent from target branch — needs cherry-pick.
- **BLOCKED (pipeline lag)**: Code merged to branch but build predates the merge — needs newer build.
- **BLOCKED (environment)**: Cluster unhealthy or infrastructure issue preventing valid verification.

---

## Subagent prompt templates (copy when spawning)

**JIRA Analyzer prompt**: "Read JIRA issue ACM-XXXX via jira MCP get_issue. Return: summary, repro steps, expected/actual, component, fix versions, bug type classification (UI-layout/UI-functional/backend/RBAC/data), and any attachment hints. Read-only."

**Environment Assessor prompt**: "Using oc (session kubeconfig), determine OpenShift server, ACM namespace, installed CSV, full DOWNSTREAM build tag per acm-operations Op 1, and capabilities: managed clusters, FG-RBAC, CNV/MTV, Hive pools, policies, OAuth IDPs. Query neo4j-rhacm for dependencies of the JIRA component (replace placeholder with actual component name). Return environment profile and dependency-based prereq hints. Read-only oc only."

**PR Analyzer prompt**: "Using gh/GitHub MCP, list all PRs referencing ACM-XXXX in stolostron/console (and other repos if issue indicates). For each: number, state, mergedAt, baseRefName. Assess whether fix is merged to release-2.YY vs main only. Read-only."

---

## Anti-patterns (do not do)

- Declaring FIXED without build-tag evidence.
- Declaring FIXED without reading the PR diff (Phase 2b). UI passing is necessary but not sufficient — the code must be reviewed for correctness and side effects.
- Declaring NOT FIXED without checking failure-signatures and diagnostic-traps (Phase 4 pre-verdict gate). The symptom may be an environment issue, not a failed fix.
- Skipping Phase 2.5 for console bugs that clearly need policies/pools/users.
- Skipping Phase 2.75 health gate and then blaming a broken cluster on the fix.
- Using curl-only console proxy tests without solving CSRF.
- Silent downgrade to "partial verify" without user consent (see global shortcut rule). Use verdict qualifiers instead.
- Pushing git branches or changing Jenkins without explicit user requests.
- Asking the user for an environment without first trying `acm-environment-finder` to auto-discover one.
- Declaring NOT_FIXED based solely on Playwright failure — the fix may work, the browser tooling just couldn't confirm it.
- Closing a ticket from presence-only mode (quick mode guardrail: never offer JIRA transition without Phase 3 verification).

---

## File map

| File | Contents |
|------|-----------|
| `SKILL.md` (this file) | Orchestration, phases, gates |
| `references/verification-patterns.md` | Bug-type decision trees |
| `references/environment-checks.md` | Build tag, OIDC, PR branch, capability matrix |

---

## Appendix — Phase diagram (textual)

```
Intake (scope + env-finder + Engram recall) → [JIRA ∥ Env ∥ PR] → Merge → Fix in build?
   no → BLOCKED (cherry-pick / pipeline lag)
   yes → Code Review (gh pr diff) → correct?
      no → NOT FIXED (code review)
      yes → Neo4j+prereq gaps → Health gate (acm-live-investigator Quick)
         unhealthy → BLOCKED (environment)
         healthy → Verify (3A: backend + 3B: UI) → Failure-sig check → Verdict → JIRA draft → Learning → cleanup
```

---

## Appendix — CSRF fetch sketch (Playwright evaluate)

Agent should adapt URLs/paths to the repro. Pattern:

```javascript
async () => {
  const token = document.cookie.split('; ').find(c => c.startsWith('csrf-token='))?.split('=')[1];
  const res = await fetch('/path/from/repro', { method: 'PUT', credentials: 'same-origin', headers: { 'X-CSRFToken': token, 'Content-Type': 'application/json' }, body: '{}' });
  return { status: res.status, text: await res.text() };
}
```

---

## Appendix — Cherry-pick signal

If the fix PR merged **only** to `main` (no merge to the release branch that produced the nightly) and the user env is a `release-2.17` downstream build, default hypothesis: **fix not in build** until Tier C proves otherwise.

---

## Appendix — Evidence checklist

- [ ] JIRA key and summary referenced
- [ ] DOWNSTREAM tag
- [ ] Server URL
- [ ] PR numbers + branches
- [ ] Screenshots or API response snippet or grep excerpt
- [ ] Prereq table outcome
- [ ] Phase 2.75 health gate result
- [ ] acm-source cross-validation result (if available)
- [ ] Evidence tier weights + confidence level
- [ ] Clear verdict string with qualifier
- [ ] Engram learning stored (Phase 4.5)

---

## Maintenance

When ACM graph schema or catalog layout changes, update `references/environment-checks.md` and `.cursor/rules/neo4j-rhacm.mdc` cross-reference — not duplicated here.

---

## Version

Skill authored for Cursor IDE personal skills path: `~/.cursor/skills/verify-bug-fix/`. AI-repo twin is intentionally out of scope here; see handoff document under `ai_systems/.claude/skills/acm-bug-fix-verifier/`.

---

## Expanded Neo4j query intents (Phase 2.5)

The exact property names depend on the RHACM graph import. Prefer **small exploratory queries** before large traversals.

**Upstream dependencies** (what must work for component X):

```text
Intent: "What does Console depend on?" → match Console node, follow outgoing DEPENDS_ON / REQUIRES / INTEGRATES_WITH edges, cap depth 2-3.
```

**Blast radius** (optional, when verifying infra bugs):

```text
Intent: "What consumes Search?" → incoming edges to Search component; use to decide whether to check search-collector, indexer, or RBAC for search.
```

If MCP returns empty results: fall back to JIRA **component** field + team convention (Console → governance/virt subsystems named in ticket).

---

## Multi-repo PR search order

1. `stolostron/console` — default for **Component = Console** and most UI defects.
2. `stolostron/backplane-operator` or `stolostron/multiclusterhub-operator` — install/operand issues.
3. `stolostron/governance-policy-framework` / related — policy engine not rendering.
4. `stolostron/cluster-lifecycle-e2e` / `stolostron/clc-ui-e2e` — rarely contain product fixes; use for **test patterns** only.

Always record **which repo** each PR belongs to in the verdict table.

---

## JIRA comment templates (drafts — user approves)

**Default format** (preferred — Atif / ACM Console QE standard; one line, attach screenshot separately):

```text
Verified on <FULL_DOWNSTREAM_TAG> (CSV <CSV_VERSION>), closing the ticket.
```

Examples:
- `Verified on 2.17.0-DOWNSTREAM-2026-05-15 (CSV 2.17.0-236), closing the ticket.` (see ACM-33683)
- `Verified on 2.17.0-DOWNSTREAM-2026-05-20 (CSV 2.17.0), closing the ticket.`

Rules:
- **Always** use this short form unless the user asks for a longer narrative.
- `<FULL_DOWNSTREAM_TAG>` = `acm-operations` Op 1 or verify-bug-fix floating-catalog fallback (`<version>-DOWNSTREAM-<YYYY-MM-DD>`).
- `<CSV_VERSION>` = installed ACM CSV identifier (e.g. `2.17.0-236` or `2.17.0` from `oc get csv -n <acm-ns>`).
- Attach verification screenshot **inline in the comment** via JIRA MCP `add_comment` with `attachment_paths` + `inline_attachment_paths` (see `jira-integration.mdc`). Do **not** rely on issue-level attachments only.
- Do **not** embed long repro steps in the comment.
- **Never** post or transition JIRA without explicit user approval.

Use this short form when the fix is straightforward and the code review confirms correctness. The DOWNSTREAM tag is the evidence that the build was tested.

**FIXED (code-only)** — use when UI verification was not possible:

```text
Verified (code-only) on <FULL_DOWNSTREAM_TAG> (CSV <CSV_VERSION>), closing the ticket.
Note: UI verification not possible (<reason: no credentials / Playwright unavailable>). Fix confirmed via branch match + code grep + PR review.
```

**FIXED (backend-only)** — use when Playwright failed mid-verification:

```text
Verified (backend-only) on <FULL_DOWNSTREAM_TAG> (CSV <CSV_VERSION>), closing the ticket.
Note: UI verification incomplete (Playwright failure). Backend confirmed via oc exec + log inspection.
```

**FIXED (with detail)** — use when additional context helps future readers:

```text
Verified on <FULL_DOWNSTREAM_TAG>, closing the ticket.
Fix PR: stolostron/<repo>#XXXX.
```

**NOT FIXED**:

```text
Still reproducible on <FULL_DOWNSTREAM_TAG>.
PR #XXXX is merged to <branch> but <reason if mismatch>.
Evidence: <screenshot/API/grep summary>.
```

**BLOCKED (missing cherry-pick)**:

```text
Cannot verify as fixed: fix PR #XXXX merged to main only; no merge to release-2.YY observed.
Env build <FULL_DOWNSTREAM_TAG> does not contain the fix.
Need cherry-pick to release-2.YY before QE verification.
```

**BLOCKED (prereq)**:

```text
Verification blocked: <missing prereq>.
QE can resume after <user action / cluster setup>.
```

---

## Parallelism rules

- Phase 1: **always** parallelize JIRA + Env + PR subagents.
- Phase 2.5: sequential with user gate on creates — do not parallelize mutating cluster ops.
- Phase 3: single browser session per environment to avoid cookie races; serialize if two URLs share auth.

---

## Definition of Done (agent session)

- [ ] Verdict table produced
- [ ] DOWNSTREAM tag always included when cluster was accessed
- [ ] PR code review performed (diff read, risk assessed, side effects checked)
- [ ] Prereq gap table produced (even if empty)
- [ ] User explicitly approved any cluster mutations and JIRA writes performed
- [ ] Cleanup done or explicitly waived by user

---

## Out of scope

- Writing new product code fixes
- Polarion test case authoring (use `write-testcase-console`)
- Cypress/Playwright **test repo** commits (use automation skills)
- Performance/load testing
- Security scanning beyond what repro requires

---

## Glossary

| Term | Meaning |
|------|---------|
| DOWNSTREAM tag | Dated ACM build identifier for JIRA |
| Tier A/B/C | Branch, date, code-level fix presence checks |
| Prereq | Anything repro needs beyond "ACM installed" |
| BLOCKED | Cannot reach a valid FIXED/NOT FIXED conclusion |

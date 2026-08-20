---
name: virt-ui-drift-detector
description: >-
  Periodically detects UI drift between upstream ACM Console / kubevirt-plugin
  source code and the console-e2e virt test automation (42 Playwright + 4
  Cypress Polarion test cases). Compares selectors, translations, routes, and
  test IDs from upstream repos against local constants, page objects, and
  components. Generates a drift report and auto-fixes code for review. Supports
  scheduled runs via the loop skill and manual triggers. Use when user says
  "run drift check", "check for UI drift", "scan for selector changes",
  "schedule drift check", "virt drift", or "UI changes affecting tests".
  Do NOT use for writing new test automation (use write-automation-script-playwright).
---

# Virt UI Drift Detector

Detect upstream UI changes in `stolostron/console` and `kubevirt-ui/kubevirt-plugin` that affect the 46 virt-related Polarion test cases (42 migrated to Playwright, 4 still in Cypress) before the pipeline breaks.

---

## Scope

### Polarion Test Cases Tracked (46 automated)

**Playwright -- fg-rbac project (32 IDs):**
RHACM4K-61726, 61727, 61728, 61729, 61730, 61731, 61732, 61733, 61734,
61779, 61797, 61823, 61825, 61735, 61864, 61865, 61867, 61736, 61944,
61866, 60255, 60254, 61863, 61856, 61862, 60467, 60468, 60229, 60251,
60239, 61846, 59217

**Playwright -- fleet-virt project (10 IDs):**
RHACM4K-60558, 60560, 60769, 60770, 60771, 60772, 60309, 60311, 60310, 60258

**Cypress -- not yet migrated (4 IDs):**
RHACM4K-60559, 59218, 59220, 53868

**22 additional documented test cases** exist without automation -- tracked for awareness but not monitored for code drift.

### Upstream Sources Watched

| Source | Repo | What We Track |
|--------|------|---------------|
| ACM Console | `stolostron/console` | Routes, translations, `data-testid`, component structure |
| kubevirt-plugin | `kubevirt-ui/kubevirt-plugin` | Fleet Virt selectors, VM action labels, CCLM modal elements |

### Test Code Directories Monitored (auto-discovered)

| File Type | Directories Scanned | Discovery |
|-----------|---------------------|-----------|
| Constants | `src/constants/` | 4 known files + scan for new virt/rbac files |
| Page Objects | `src/pages/fleet-virt/`, `src/pages/fg-rbac/`, `src/pages/infrastructure/` | **Auto** -- reads every `.ts` file in each directory |
| Components | `src/components/fleet-virt/`, `src/components/fg-rbac/` | **Auto** -- reads every `.ts` file in each directory |
| Shared Libs | `src/lib/fg-rbac/`, `src/lib/openshift-login.ts` | **Auto** -- reads every `.ts` file in `fg-rbac/`; named file for login |
| Spec files | `src/tests/fleet-virt/`, `src/tests/fg-rbac/` | **Auto** -- searches all files in each directory |
| Fixtures | `src/fixtures/fleet-virt-test.ts`, `src/fixtures/fg-rbac-test.ts` | Named files |

New page objects, components, and spec files are automatically picked up.
No skill update needed when adding files to existing directories.

**Remote repo:** `stolostron/console-e2e` (branch: `main`)
**Data source:** All test code is fetched from GitHub remote — never from local checkout.
This avoids contamination from feature branches, uncommitted changes, or stale clones.

---

## ASK QUESTIONS FIRST

On first run (no baseline exists), ask:

| Question | Why |
|----------|-----|
| ACM version to track (e.g., 5.1) | Sets the upstream branch for `stolostron/console`. See **Version Mapping** below. |
| CNV version (e.g., 4.23) | Sets the upstream branch for `kubevirt-ui/kubevirt-plugin` |
| Live cluster URL (optional) | Enables Phase 1C live DOM validation |

On subsequent runs, use the version from the last baseline. Only ask if the user overrides.

### Version Mapping (internal to public)

Starting with ACM 2.18 / OCP 4.18, Red Hat rebranded to a new major version
scheme. The `acm-source` MCP and `list_versions()` use **internal** version
numbers (2.x / 4.x). Reports, emails, and user-facing output MUST use
**public** version numbers (5.x).

| Internal (MCP / branch) | Public (reports) | Branch |
|-------------------------|-----------------|--------|
| ACM 2.18 | ACM 5.0 | `release-2.18` |
| ACM 2.19 | ACM 5.1 | `main` (current dev) |
| OCP 4.18 | OCP 5.0 | (same offset) |

**Conversion rule:** `public_major = internal_minor - 13` for ACM (2.18=5.0,
2.19=5.1). OCP follows the same offset (4.18=5.0). When `list_versions()`
returns a new internal version on `main`, compute the public version from
the offset -- do not hardcode.

**In practice:**
- Call `set_acm_version("2.19")` in the MCP, but present as "ACM 5.1" in reports.
- Call `set_cnv_version("4.23")` -- CNV has not rebranded, use as-is.
- Baselines store the internal version (`acmVersion: "2.19"`) for MCP
  compatibility; the public version is derived at report time.

---

## Engram Integration

Before starting:
```
engram_recall(context="virt drift detector baseline cluster version")
engram_recall(context="ACM console selector changes fleet-virt")
```

After completing:
```
engram_remember(content="Virt drift check <date>: <N> breaking, <N> warning, <N> info. ACM <ver>, CNV <ver>. Key changes: <summary>", type="semantic", entities=["virt-ui-drift-detector", "console-e2e"], topics=["drift-check", "selectors"])
```

---

## MANDATORY: Phase Gate Enforcement

On skill start, IMMEDIATELY create a TodoWrite with ALL phases:

```
TodoWrite (merge=false):
  phase-0  | Phase 0: Pre-flight (version, baseline, cluster check) | pending
  phase-1  | Phase 1: Parallel scan (3 subagents)                   | pending
  phase-2  | Phase 2: Diff analysis                                  | pending
  phase-3  | Phase 3: Drift report + auto-fix                       | pending
  phase-4  | Phase 4: Baseline update + Engram store                | pending
```

Gate rules:
1. Phase 1 requires ALL launched subagents to return results before marking complete.
2. Phase 3 presents fixes for user review -- NEVER auto-apply without approval.
3. Phase 4 saves the new baseline only after the user has reviewed the report.

---

## Phase 0: Pre-flight

1. **Check ACM version** -- call `get_current_version()` on `acm-source` MCP.
2. **Detect CNV development version** -- call `list_versions()` on `acm-source` MCP.
   In the output, find the CNV version tagged `(main)` -- this is the active
   development version that maps to the `main` branch of `kubevirt-ui/kubevirt-plugin`.
   Example: if `list_versions()` shows `CNV 4.23 -> main (main)`, use `4.23`.
   Do NOT simply pick the highest version number -- the highest GA version
   (tagged `(latest)`) maps to a release branch, not `main`.
   NEVER hardcode a CNV version — always auto-detect from the `(main)` tag.
   If the previous baseline has a different CNV version, log the version change
   in the drift report header.
3. **Check for baseline** -- look for the most recent JSON file in
   `~/.cursor/skills/virt-ui-drift-detector/assets/baselines/`.
   If no baseline exists, this is the first run -- the skill will create an initial
   baseline without producing a drift report.
4. **Check for live cluster** -- follow this priority order:
   a. **Read `~/Documents/work/notes/notes.md` lines 1-3.** The user maintains
      a standing cluster reference there in a fixed format:
      - Line 1: ACM version label (e.g., `5.0 -`)
      - Line 2: Console URL (e.g., `https://console-openshift-console.apps...`)
      - Line 3: `kubeadmin` password
      Extract the URL and password. Attempt a quick reachability check
      (`browser_navigate` to the URL, or a lightweight HTTP probe). If reachable,
      use it for Phase 1C. If the URL returns an error, is blank, or the file
      doesn't exist — move to step (b). Do NOT ask the user; just skip silently.
   b. **Fall back to Engram** -- call `engram_recall(context="last ACM cluster URL")`.
   c. **If nothing found** -- skip live validation entirely. Log:
      "Live validation skipped — no cluster available (notes.md unreachable,
      no Engram record). Source-only comparison."
   Never block the run to ask the user for a cluster URL during scheduled runs.
5. **Set versions** -- call `set_acm_version()` and `set_cnv_version()` to target
   the correct upstream branches. Use the CNV version auto-detected in step 2.
6. **Version alignment check** -- compare the ACM version from `notes.md` line 1
   (e.g., "5.0") against the target scan version (e.g., "5.1"). If they differ,
   log a warning: "Live cluster runs ACM {X}, source scan targets ACM {Y}.
   Live DOM findings will be tagged [INFERRED: version mismatch]."
   Store this mismatch flag for use in Phase 2 (the diff-analyzer tags all
   live-DOM drift items with the version caveat) and Phase 4 (the email report
   includes a version mismatch notice).
7. **Knowledge DB lookup**: Read `ui/fleet-virt.md` and `automation/playwright/fleet-virt.md` from the knowledge DB at `/Users/ashafi/Documents/work/notes/knowledge/` for current Fleet Virtualization UI knowledge, selectors, and testing gotchas.

---

## Phase 1: Parallel Scan (3 subagents, fan-out)

Launch simultaneously using the Task tool with **shared Cursor subagent types**
(not `generalPurpose`). Each type has built-in knowledge of the relevant MCP
tools and ACM conventions.

### Subagent A: Source Scanner

**Cursor Subagent:** `ui-discovery`
**Template:** `subagents/source-scanner.md`

Fill placeholders:
- `{ACM_VERSION}`: from Phase 0
- `{CNV_VERSION}`: from Phase 0
- `{CNV_BRANCH}`: from Phase 0 (version-to-branch mapping via `list_versions()`)

The `ui-discovery` subagent type knows how to use the `acm-source` MCP.
The custom template uses a **hybrid approach**:
- **kubevirt-plugin selectors**: shallow `git clone` + exhaustive `grep`
  (replaces MCP `search_code` which caps at 30 results and misses selectors)
- **ACM Console selectors, translations, routes, PF version**: `acm-source` MCP
  (reliable, focused results)

Output includes `attributeType` (`data-test` or `data-testid`) and `sourceFile`
per selector for downstream attribute normalization and co-occurrence detection.

### Subagent B: Test Code Analyzer

**Cursor Subagent:** `pattern-analyzer`
**Template:** `subagents/test-code-analyzer.md`

The `pattern-analyzer` subagent type knows the `console-e2e` repo structure
(constants, page objects, components, services, fixtures). The custom template
overrides two behaviors:

1. **Data source:** Performs a **shallow clone** of `stolostron/console-e2e@main`
   into a temp directory, then uses local `cat`/`ls`/`grep` for all reads and
   searches. Zero GitHub API calls — no rate limits, no gaps. NEVER reads from
   the local checkout. This ensures comparison is always against committed main.
2. **Extra extraction:** Also finds absence assertions (`not.toBeVisible`,
   `toHaveCount(0)`) that the standard pattern-analyzer doesn't cover.

After the subagent returns, run the fragility scorer and cross-check script.
Both accept a directory path to avoid redundant clones:

```bash
# Clone once for both scripts
VERIFY_CLONE=$(mktemp -d)
git clone --depth 1 --branch main --single-branch --quiet \
  https://github.com/stolostron/console-e2e.git "$VERIFY_CLONE" 2>/dev/null

# Fragility scoring
python3 scripts/fragility-score.py "$VERIFY_CLONE"

# Deterministic cross-check against subagent output
bash scripts/extract-local-selectors.sh "$VERIFY_CLONE"

# Cleanup
rm -rf "$VERIFY_CLONE"
```

If the cross-check script's `absenceAssertions.count` differs from the
subagent's count, log a warning: "Absence assertion count mismatch:
script={X}, subagent={Y}. Investigate grep command in subagent template."

### Subagent C: Live Validator (conditional)

**Cursor Subagent:** `live-validator`
**Template:** `subagents/live-validator.md`

Fill placeholders:
- `{CLUSTER_URL}`: from Phase 0 (Engram or user input)

The `live-validator` subagent type knows how to use the browser MCP
(navigate, snapshot, click, screenshot) and `oc` CLI for backend checks.
The custom template specifies which pages to visit (Fleet Virt, RBAC) and
includes a **Tab Detection Protocol** that detects and iterates page tabs,
snapshotting each tab separately. This captures which `data-test` elements
are visible on which tab — preventing false positives when elements exist
but are hidden on non-default tabs.

Only launch if a cluster URL is available (from `notes.md` lines 1-3 or Engram).

If a password was found in `notes.md` line 3, pass it as `{CLUSTER_PASSWORD}`
so the live validator can authenticate with `kubeadmin`.

**If no cluster is available:** Skip this subagent. Log: "Live validation
skipped -- no cluster available. Source-only comparison."

---

## Phase 1 → Phase 2 Gate Validation

Before proceeding to Phase 2, the orchestrator MUST verify Phase 1 outputs:

1. **File existence check**: Confirm these files exist and are non-empty:
   - `assets/scan-source-{YYYY-MM-DD}.json`
   - `assets/scan-testcode-{YYYY-MM-DD}.json`
   - `assets/scan-live-{YYYY-MM-DD}.json` (only if live validator was launched)
2. **JSON validity check**: Parse each file as JSON. If any fails, the subagent
   output was malformed — re-run that subagent.
3. **Minimum field check**: Verify each file contains expected top-level keys:
   - scan-source: `selectors`, `translations`, `routes`
   - scan-testcode: `constants`, `pageObjectLocators`, `dependencyGraph`, `orphans`, `summary`
   - scan-live: `pages`, `perspectives`
4. **Fragility report**: Run `fragility-score.py` if not already done. Save output.

If any check fails, log the failure and re-run the affected subagent before
proceeding. Do NOT advance to Phase 2 with incomplete data.

---

## Phase 2: Diff Analysis

**Template:** `subagents/diff-analyzer.md`

### Context Offloading (prevent context overflow)

Phase 1 subagents can return large payloads (hundreds of translations, dozens
of locators). Do NOT inline all outputs into the diff-analyzer prompt. Instead:

1. **Save each Phase 1 output to a file:**
   ```
   assets/scan-source-{YYYY-MM-DD}.json    ← Subagent A output
   assets/scan-testcode-{YYYY-MM-DD}.json  ← Subagent B output
   assets/scan-live-{YYYY-MM-DD}.json      ← Subagent C output (if available)
   ```
   Also save the fragility report and absence assertions to files if they
   exceed ~50 lines.

2. **Pass file paths + compact summaries to the diff-analyzer:**
   Instead of `{SOURCE_SCANNER_OUTPUT}` containing the full JSON, pass:
   ```
   Source Scanner: assets/scan-source-2026-07-23.json
   Summary: 47 selectors (23 fleetVirt, 18 rbac, 6 infra), 312 translations,
   14 routes, 89 test IDs. PF version: pf-v6-c. ACM 5.0 / CNV 4.22.
   ```
   Do the same for each input.

3. **The diff-analyzer reads sections on demand** using the `Read` tool as it
   works through each step (e.g., read only the `translations` section when
   doing Layer 2 matching, read only the `dependencyGraph` section for Step 4).

This keeps the diff-analyzer's initial context small (~3,000 tokens of
instructions + summaries) and lets it load data incrementally per step.

### Launch (MANDATORY — structural enforcement)

Launch a single `generalPurpose` subagent (`run_in_background: false`) with the
file paths and summaries. This MUST be a blocking Task call — the orchestrator
cannot proceed to Phase 3 until the diff-analyzer subagent completes.

**Enforcement gate:** After the subagent returns, write a marker file:
```
echo "<subagent_id>" > assets/phase2-launch.marker
```
Phase 3 MUST read this marker file and verify it contains a valid subagent ID.
If the file does not exist, Phase 3 MUST refuse to proceed and report:
"Phase 2 diff-analyzer was not launched. Run is invalid."

**DO NOT perform the diff analysis inline.** The diff-analyzer template contains
a 9-step protocol with evidence requirements, impact chain tracing, and
hallucination guards (Rule 0) that cannot be replicated by the orchestrator
working from memory.

The analyzer compares all inputs and classifies each drift item.
For classification rules, read `references/drift-categories.md`.
For the upstream-to-test-code mapping, read `references/selector-mapping.md`.

**Absence assertion check**: If `extract-local-selectors.sh` found any
absence assertions (`not.toBeVisible`, `toHaveCount(0)`), cross-reference
those selectors against Phase 1A results. Flag any that reference selectors
no longer present upstream — these are **vacuous assertions** that pass
forever without testing anything (severity: BREAKING).

### Drift Categories

| Severity | Meaning | Example |
|----------|---------|---------|
| BREAKING | Test will fail at runtime | Selector removed, route changed, test ID renamed |
| WARNING | Test may become fragile | Translation wording changed, new UI element not tested |
| INFO | No immediate test impact | Upstream added new test IDs we could adopt |

Output: structured drift report (JSON + markdown).

---

## Phase 3: Report + Auto-Fix

### Step 3a: Drift Report

The orchestrator presents the drift report to the user:
- Summary: N breaking, N warning, N info items
- Locator health: avg fragility score, high-risk count, strategy distribution
- Per-item table: what changed, which files affected, before/after values
- Chronically unstable elements (from `drift-history.jsonl`, if 3+ occurrences)
- Vacuous assertions (if any detected)
- Recommended actions per item

If **zero drift items** detected: report "No drift detected" and proceed to
Phase 4 (baseline update). Skip Step 3b.

### Step 3b: Code Fixer (MANDATORY when drift exists)

**Template:** `subagents/code-fixer.md`

**Gate check:** If `driftItems.filter(severity in [BREAKING, WARNING]).length > 0`,
the orchestrator MUST launch the code-fixer subagent. Do NOT skip this step.
Launch a `generalPurpose` subagent.

Fill placeholders:
- `{DRIFT_ITEMS}`: the BREAKING and WARNING items from the diff report

The fixer generates specific `StrReplace` edits for the user's local checkout.
It references files by relative path (e.g., `src/constants/fleet-virt.ts`) with
before/after values. These edits are for the user to review and apply manually
to whichever branch they're working on.

The fixer generates edits for each drift item:
- Constants file updates (new selector values in `fleet-virt.ts`, `fg-rbac.ts`)
- Page object locator updates (new `getByRole` names, `data-test` values)
- Spec assertion updates if UI text changed

**All edits are presented for user review. NEVER auto-apply.**

After presenting edits, ask: "Should I apply these fixes?"

---

## Phase 4: Baseline Update

1. **Build the new baseline by joining scan-source and scan-testcode outputs:**
   `~/.cursor/skills/virt-ui-drift-detector/assets/baselines/{YYYY-MM-DD}.json`
   Follow the schema in `assets/baseline-template.json`.

   **CRITICAL: Key Format Join (do NOT copy from previous baseline)**

   The scan-source file uses raw selector values as keys (e.g., `"vm-advanced-search-button"`).
   The baseline schema uses constant-path names (e.g., `"FLEET_VIRT_ADVANCED_SEARCH.openButton"`).
   To build the baseline, JOIN the two scan outputs:

   For each constant-path in `scan-testcode-{date}.json` → `constants` section:
   a. Extract its selector value (e.g., `FLEET_VIRT_ADVANCED_SEARCH.openButton` → `"[data-test=\"vm-advanced-search-button\"]"`)
   b. Strip the CSS selector wrapper to get the raw value (e.g., `"vm-advanced-search-button"`)
   c. Look up that raw value in `scan-source-{date}.json` → `selectors.fleetVirt` or `selectors.rbac`
   d. If found: use the source scanner's `sourceFile` and `attributeType` fields
   e. If not found: set `sourceFile` to `"NOT FOUND in upstream"` and note the mismatch

   This produces the baseline's expected format (constant-path keys + upstream metadata)
   without copying stale data from the previous baseline.

   Never copy forward from the previous baseline. Every field must come from
   fresh scan data.

2. **Append drift items to the history log** (`assets/drift-history.jsonl`):
   For each BREAKING or WARNING drift item, append one JSON line:
   ```json
   {"date":"YYYY-MM-DD","acm":"5.0","cnv":"4.22","severity":"BREAKING","category":"selector","element":"FLEET_VIRT_SEARCH.searchInput","before":"old-value","after":"new-value","file":"fleet-virt.ts","fixed":false}
   ```
   This enables trend analysis on subsequent runs. If the same element appears
   in the history 3+ times, flag it as **chronically unstable** in the report.

3. Store the run summary in Engram:
   ```
   engram_remember(content="Virt drift check {date}: {breaking} breaking, {warning} warning, {info} info. ACM {ver}, CNV {ver}.", type="semantic", entities=["virt-ui-drift-detector"], topics=["drift-check"])
   ```

4. **Email the report** to `ashafi@redhat.com` via Google Workspace MCP:
   ```
   CallMcpTool: google-workspace -> send_gmail_message(
     user_google_email="ashafi@redhat.com",
     to="ashafi@redhat.com",
     subject="[Drift Check] ACM {ver} — {breaking} breaking, {warning} warning, {info} info",
     body="<html drift report>",
     body_format="html"
   )
   ```
   The HTML body should include:
   - Date and ACM/CNV versions
   - **Drift summary table** — for each drift item include:
     - severity, category, element, before/after, file
     - **Impacted Polarion IDs** — from the `impactChain.polarionIds` field. Display
       as comma-separated IDs (e.g., `RHACM4K-61726, RHACM4K-61863`). This tells
       the reader exactly which test cases will break or be affected.
     - **Impact path** — brief chain (e.g., `constant → UserDetailsPage → role-assignment-global-access.spec.ts → RHACM4K-61726`)
   - Locator health: avg fragility score, high-risk count, strategy distribution
   - **Orphan report** — if orphan constants or page objects were detected, list
     them in a dedicated section titled "Orphan Detection":
     - Unused constants (name, file, value)
     - Unused page objects (file, reason)
   - Chronically unstable elements (from history, if any)
   - If zero drift: a short "No drift detected" confirmation
   - **Paths checked** — a section titled "Scope: Paths Analyzed" listing every
     path that was scanned, grouped by source. This reminds the user which files
     are covered so they can spot anything missing:

     **Upstream sources (acm-source MCP):**
     - `stolostron/console` (branch: main) — routes, translations, data-testid, selectors
     - `kubevirt-ui/kubevirt-plugin` (branch: release-{CNV_VER}) — Fleet Virt selectors, VM actions

     **Test code (GitHub MCP — stolostron/console-e2e@main):**
     - Constants: `src/constants/fleet-virt.ts`, `fg-rbac.ts`, `selectors.ts`, `app.ts`
     - Page objects (auto-discovered): `src/pages/fleet-virt/`, `src/pages/fg-rbac/`, `src/pages/infrastructure/`
       → list each file actually found and read (e.g., `FleetVirtPage.ts`, `VmDetailsPage.ts`, ...)
     - Components (auto-discovered): `src/components/fleet-virt/`, `src/components/fg-rbac/`
       → list each file actually found and read
     - Shared libs (auto-discovered): `src/lib/fg-rbac/`, `src/lib/openshift-login.ts`
       → list each file actually found and read
     - Spec searches: `src/tests/fleet-virt/`, `src/tests/fg-rbac/`
     - Route searches: `FLEET_VIRT_ROUTES`, `RBAC_ROUTES` across `src/`
     - PF version: `pf-v` prefix across `src/constants/`, `src/pages/`, `src/components/`

     **Live cluster:** URL if used, or "Skipped — no cluster available"

   Keep the email concise — no inline images, just styled HTML tables.
   If the Gmail MCP is unavailable, skip emailing and report in chat only.

5. Report completion to the user in chat with:
   - Drift summary (breaking/warning/info counts)
   - Locator health score (avg fragility from `fragility-score.py`)
   - Chronically unstable elements (from history, if any)
   - Next scheduled check date (if loop is active)

---

## Common Issues

### acm-source MCP Unreachable
If `get_current_version()` or any acm-source tool returns a connection error:
1. Check MCP server status in Cursor settings
2. Try `list_repos` as a lightweight health check
3. If persistent: abort and report "acm-source MCP unavailable. Cannot run drift check."

### Subagent Returns Empty or Malformed Results
- **Source Scanner empty:** Upstream branch may not exist. Run `list_versions` to
  verify. If branch doesn't exist, abort with message.
- **Test Code Analyzer empty:** The shallow clone of `console-e2e@main` may
  have failed (network issue, repo access). Check the clone's stderr output.
  Retry the clone once. If it still fails, abort with message.
- **Both empty:** Abort the run. Report: "Unable to gather upstream or test code data."

### GitHub Clone Fails (console-e2e)
If `git clone` of `stolostron/console-e2e` fails:
1. Verify network connectivity (e.g., `curl -s https://github.com`)
2. Check that `git` credentials / SSH keys allow access to the private repo
3. If persistent: abort and report "Cannot clone console-e2e. Cannot fetch test code."

### Kubevirt-plugin Clone Fails
If `git clone` of `kubevirt-ui/kubevirt-plugin` fails in the Source Scanner:
1. Check that the branch `{CNV_BRANCH}` exists (run `list_versions()` to verify mapping)
2. kubevirt-plugin is a PUBLIC repo — no auth needed. If clone fails, it is likely
   a network issue or the branch was deleted/renamed.
3. Fallback: try cloning `main` branch instead of `{CNV_BRANCH}`.
4. If persistent: the Source Scanner reports `"kubevirtCloneError"` in its output.
   The diff-analyzer treats all kubevirt selectors as "unknown" and skips them.

### Subagent Timeout
If a Phase 1 subagent runs longer than 120 seconds without output:
1. Check if acm-source MCP is responsive (`list_repos`)
2. If MCP is fine but subagent is stuck: kill and retry once
3. If retry also stalls: abort and report which subagent failed

---

## Scheduling

### Auto-Schedule (Mon/Wed/Fri at 12:30 PM)

Runs the **full skill** (all phases) automatically. Zero maintenance.

**How it works:**

1. macOS `launchd` fires on Mon/Wed/Fri at 12:30 PM → writes `~/.cursor/drift-trigger`
2. Cursor `stop` hook (`drift-scheduled-check.sh`) checks for the trigger file
   after every agent session ends
3. If trigger exists → deletes it → returns a `followup_message` that starts
   the full skill pipeline (Phase 1 through Phase 4)
4. The skill runs to completion and reports findings

**Timing behavior:**

- If Cursor is open at 12:30 PM → runs after the current chat ends
- If Cursor is closed at 12:30 PM → trigger file waits; runs after the first
  chat ends once Cursor is reopened
- If Mac is asleep at 12:30 PM → launchd fires on wake; Cursor picks it up
- If multiple triggers accumulate → only one runs (trigger file is overwritten)

**Installed components:**

- Plist: `~/Library/LaunchAgents/com.ashafi.drift-detector-trigger.plist`
- Hook: `~/.cursor/hooks/drift-scheduled-check.sh` (in `stop` event, `loop_limit: 1`)

```bash
# Check if scheduled
launchctl list | grep drift

# Temporarily disable
launchctl unload ~/Library/LaunchAgents/com.ashafi.drift-detector-trigger.plist

# Re-enable
launchctl load ~/Library/LaunchAgents/com.ashafi.drift-detector-trigger.plist

# Force a run now (simulate launchd trigger)
echo "$(date '+%Y-%m-%dT%H:%M:%S')" > ~/.cursor/drift-trigger

# Change days/time → edit the plist, then unload + load
```

### Manual Trigger

Intent phrases: "run drift check", "check for UI drift", "scan for selector
changes", "virt drift", "UI changes affecting tests"

### CI Integration (no AI needed)

`scripts/drift-check-ci.sh` runs a standalone baseline comparison in ~2 seconds.
No MCP, no browser, no AI. Add it as a Jenkins pre-step:
```groovy
stage('Selector Drift Check') {
  steps {
    sh 'bash .cursor-skills/drift-check-ci.sh . .drift-baseline.json'
  }
}
```
Exit codes: 0=clean, 1=BREAKING drift, 2=WARNING drift, 3=script error.

---

## First Run Behavior

When no baseline exists in `assets/baselines/`:

1. Run Phase 0 and Phase 1 as normal (ask for versions, scan upstream + local + live).
2. Run Phase 2 as a **cross-comparison** — compare upstream source (Phase 1A) against
   local test code (Phase 1B) and live DOM (Phase 1C). Even without a previous baseline,
   this catches mismatches between what upstream defines and what the test code uses
   (e.g., translation casing drift, missing selectors, stale PF prefixes).
3. Run Phase 3 to present findings. On first run, categorize items as "initial alignment
   issues" rather than "drift from baseline."
4. Run Phase 4 to save the initial baseline.
5. Report: "Initial baseline captured with cross-comparison findings. Future runs will
   also detect drift from this baseline."

---

## MCP Quick Reference

| Need | Method | Tool |
|------|--------|------|
| Current ACM/CNV version | `acm-source` MCP | `get_current_version`, `list_versions` |
| Set ACM branch | `acm-source` MCP | `set_acm_version` |
| Set CNV branch | `acm-source` MCP | `set_cnv_version` |
| ACM Console selectors | `acm-source` MCP | `search_code`, `find_test_ids` |
| kubevirt-plugin selectors | Shell (git clone + grep) | Shallow clone of `kubevirt-ui/kubevirt-plugin`, then `grep -rn 'data-test'` |
| UI translations | `acm-source` MCP | `search_translations` |
| Navigation routes | `acm-source` MCP | `get_routes` |
| Component source code | `acm-source` MCP | `get_component_source` |
| Live page DOM snapshot | `playwright` MCP | `browser_navigate`, `browser_snapshot` |
| Live page screenshot | `playwright` | `browser_take_screenshot` |
| Session memory | `engram` | `engram_recall`, `engram_remember` |
| Email drift report | `google-workspace` | `send_gmail_message` |

---

## Skill File Structure

```
~/.cursor/skills/virt-ui-drift-detector/
  SKILL.md                          # This file (orchestrator)
  scripts/
    extract-local-selectors.sh      # Deterministic local selector extraction (~1s)
    fragility-score.py              # Locator fragility scoring (0-100 per locator)
    drift-check-ci.sh              # Standalone CI baseline comparison (no MCP/AI needed)
  references/
    drift-categories.md             # Classification rules for 7 drift types
    selector-mapping.md             # Maps upstream selectors to test code locations
  subagents/
    source-scanner.md               # Phase 1A: upstream source scanning
    test-code-analyzer.md           # Phase 1B: fallback if scripts fail
    live-validator.md               # Phase 1C: browser-based DOM validation
    diff-analyzer.md                # Phase 2: compare + classify drift
    code-fixer.md                   # Phase 3B: generate code fixes
  assets/
    baseline-template.json          # Schema for snapshot baselines
    baselines/                      # Timestamped baseline JSON files
    drift-history.jsonl             # Append-only log of all drift items across runs
```

---

## Trigger Validation Prompts

Prompts that SHOULD trigger this skill:
- "run drift check"
- "check for UI drift"
- "scan for selector changes"
- "any upstream UI changes affecting my tests?"
- "schedule drift check every 2 days"
- "virt drift"

Prompts that SHOULD NOT trigger this skill:
- "write a new test for VM snapshots" → use write-automation-script-playwright
- "fix this flaky test" → use failure-debugger
- "what selectors does the role assignment wizard use?" → use acm-source MCP directly
- "update the PF version in fleet-virt.ts" → direct code edit, no skill needed

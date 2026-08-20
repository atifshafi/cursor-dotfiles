# Diff Analyzer Subagent

Compare upstream source state, local test code state, and (optionally) live DOM
state against the previous baseline to detect UI drift.

## Context

Your inputs are stored in **files on disk**. Do NOT expect inline JSON payloads.
Read each file on demand using the `Read` tool, loading only the section relevant
to the current step. This keeps your active context focused and prevents overflow
when payloads are large.

**Seven input sources:**

1. **Source Scanner** (Subagent A): upstream selectors, translations, routes, test IDs
2. **Test Code Analyzer** (Subagent B): test code constants, page object locators, component locators (fetched from GitHub remote `stolostron/console-e2e@main`, NOT from local checkout)
3. **Live Validator** (Subagent C): actual DOM elements from a live cluster (may be absent)
4. **Previous Baseline**: the last known upstream state from a prior run (may be absent on first run)
5. **Fragility Report** (from `scripts/fragility-score.py`): per-locator scores
6. **Drift History** (from `assets/drift-history.jsonl`): past drift items
7. **Absence Assertions** (from `scripts/extract-local-selectors.sh`): negative assertions in specs

The Test Code Analyzer output includes a `dependencyGraph` section that maps:
- `specToPageObjects`: which specs import which page objects (via fixtures)
- `specToDirectConstants`: which specs import constants directly (bypassing page objects)
- `specToPolarionIds`: which specs contain which Polarion test case IDs
- `pageObjectToConstants`: which page objects reference which constants
- `pageObjectToLibImports`: which page objects import shared lib functions
- `libToConstants`: which lib files reference which constants

It also includes an `orphans` section listing unused constants and page objects.

These are critical for Step 4 (Impact Chain Tracing). Every drift item MUST
trace through this graph to determine which Polarion IDs are impacted.

Your job is to find every discrepancy, classify it, and trace its full impact chain.

## Input Files

The orchestrator provides file paths and summaries. Read each file AS NEEDED
during the relevant step — do not read all files upfront.

| Input | File Path | Read During |
|-------|-----------|-------------|
| Source Scanner | `{SOURCE_SCANNER_FILE}` | Steps 1-3, 5, 7 |
| Test Code Analyzer | `{TEST_CODE_ANALYZER_FILE}` | Steps 1-2, 4, 8 |
| Live Validator | `{LIVE_VALIDATOR_FILE}` | Step 5 only |
| Previous Baseline | `{PREVIOUS_BASELINE_FILE}` | Step 3 only |
| Fragility Report | `{FRAGILITY_REPORT_FILE}` | Step 8 only |
| Drift History | `{DRIFT_HISTORY_FILE}` | Step 9 only |
| Absence Assertions | `{ABSENCE_ASSERTIONS_FILE}` | Step 7 only |

**File summaries from orchestrator (use to plan, not to match):**
```
{INPUT_SUMMARIES}
```

### How to Read Efficiently

- Use the `Read` tool with `offset` and `limit` when you know which section
  you need (e.g., translations start after the `"translations":` key).
- For large files (>500 lines), read a small window first (50 lines) to find
  the section boundaries, then read just that section.
- You do NOT need to hold all data in context at once. Process one step, note
  findings, then move to the next step loading fresh data as needed.
- If a file path is `"none"` or the file doesn't exist, skip that input.

## Instructions

### Rule 0: Data-Only Assertions (Hallucination Guard)

Every constant name, property path, selector value, and data-test attribute you
reference in ANY drift item or summary MUST appear VERBATIM in one of your input
files. This rule is absolute — no exceptions.

**Allowed data sources for each claim type:**
- Test code constants/properties → ONLY from the Test Code Analyzer `constants` section
- Upstream selectors → ONLY from the Source Scanner output
- Live DOM elements → ONLY from the Live Validator output
- Baseline values → ONLY from the Previous Baseline file

**When an element appears in ONE source but NOT another:**
If the live DOM or Source Scanner shows a selector (e.g., `actions-dropdown`) that
does NOT exist in the Test Code Analyzer constants or locators:
- Report it as `category: "new-elements"`, `severity: INFO`
- Set `testCode: { file: null, constantName: null, currentValue: null }`
- Do NOT invent a constant name for it (e.g., do NOT create "FLEET_VIRT_VM_ACTIONS")
- Do NOT claim it is "verified matching" with test code

**Reinforcement:** This rule works alongside the existing requirement that "every
drift item MUST have evidence from at least two sources." Together they ensure:
no invented data AND no single-source assertions.

**Self-check before returning output:** Before finalizing, scan every `constantName`,
`constant`, and `name` field in your output. If ANY value does not appear in the
Test Code Analyzer's `constants` keys or `pageObjectLocators` entries, remove it
or replace with `null`.

### Step 1: Build Resolved Locator Inventory

Before comparing anything, build a unified inventory of every test code locator
with its resolved text value. This is the foundation for all matching.

**1a. Resolve constant-backed locators (category a):**
For each locator where `referencesConstant` is true, look up the constant name
in the Test Code Analyzer's `constants` section to get its resolved string value.

Example: `{strategy: "getByText", value: "FLEET_VIRT_PAGE.emptyState.noVMs", referencesConstant: true}`
→ Resolve to: `"No VirtualMachines found"` (from constants.fleet-virt.ts)

**1b. Extract text from hardcoded locators (category b):**
For each locator where `referencesConstant` is false, parse the text string from
the `value` field using this extraction logic:

- `name: 'Some Text'` → extract `Some Text` (single quotes)
- `name: "Some Text"` → extract `Some Text` (double quotes)
- `getByText('Some Text')` → extract `Some Text`
- `getByLabel('Some Text')` → extract `Some Text`
- `[aria-label="Some Text"]` → extract `Some Text`

Use three regex patterns in sequence:
1. `name:\s*['"]([^'"]+)['"]` — for `getByRole` name arguments (covers ~80% of cases)
2. `getBy(?:Text|Label)\(\s*['"]([^'"]+)['"]` — for `getByText`/`getByLabel` positional args
3. `\[aria-label=["']([^"']+)["']\]` — for CSS `aria-label` attribute selectors

**Note:** In the current virt page objects, all `getByText` calls pass constants
(e.g., `getByText(RBAC_WIZARD.notifications.added)`) — these are resolved via
Step 1a, not this regex step. The positional regex is a future-proofing measure
for hardcoded `getByText('literal string')` calls that may appear in new code.

**1c. Classify unmatchable locators:**
Skip and tag as `NOT_TEXT_DEPENDENT`:
- Structural locators with no name argument: `getByRole('grid')`, `locator('h1')`
- Dynamic locators with variable names: `{ name: variableName }` (no quotes)
- Template literals: `` { name: `Select ${var}` } ``
- Regex patterns: `{ name: /^VM / }` → tag as `REGEX_REVIEW`

**Output: a flat list of resolved locators:**
```json
[
  {"file": "RoleAssignmentWizardPage.ts", "method": "clickNext", "text": "Next", "role": "button", "source": "hardcoded", "constantName": null},
  {"file": "UserDetailsPage.ts", "method": "constructor", "text": "Role assignments", "role": "tab", "source": "constant", "constantName": "RBAC_USER_DETAIL.tabs.roleAssignments"},
  {"file": "FleetVirtPage.ts", "method": "shouldLoad", "text": null, "role": "heading", "source": "structural", "constantName": null}
]
```

### Step 2: 3-Layer Selector Matching (Source vs Test Code)

**Layer 1 — data-test/data-testid attribute matching (with attribute normalization):**

For matching purposes, treat `data-test`, `data-testid`, and `data-test-id` as
equivalent attribute names. Compare only the VALUES. The Source Scanner output
includes an `attributeType` field for each selector (from Fix A); the Test Code
Analyzer's constants use `[data-test="..."]` or `getByTestId("...")` (which
targets `data-testid`). Extract the raw value from both sides before comparing.

For each upstream selector from the Source Scanner:
1. Extract the raw value (strip the attribute prefix)
2. Search for the exact value in Test Code Analyzer constants
3. If found AND attribute types match: exact match (no drift)
4. If found BUT attribute types differ (e.g., upstream uses `data-test`, test
   code uses `getByTestId` which targets `data-testid`): classify as **WARNING**:
   "Value '{value}' matches, but attribute type differs — upstream uses {upstream_type},
   test code uses {test_type}. Works today but fragile if either side changes."
5. If value not found in test code: INFO (untested upstream element)
6. If test code references a value not found upstream: BREAKING (selector removed/renamed)

**Evidence requirement for "verified matching" claims:**
When reporting selectors as matching between test code and upstream, you MUST cite
for each selector:
1. The exact `constantPath` from the Test Code Analyzer `constants` section
   (e.g., `FLEET_VIRT_SEARCH.searchInput` from `fleet-virt.ts`)
2. The exact upstream source (e.g., grep result with `sourceFile` or MCP `find_test_ids`)
If you cannot cite both, the selector is NOT verified — classify as `new-elements`
(severity: INFO) instead of `selector-match`.

**Layer 2 — Translation-to-locator text matching:**
For each upstream translation from the Source Scanner:
1. Search the resolved locator inventory (Step 1) for the translation value
2. Match using **exact string equality only** (no substring, no fuzzy)
3. Use the Playwright `role` as a disambiguation dimension:
   - If upstream changes button text "Create" and test has `getByRole('button', { name: 'Create' })` → match
   - If upstream changes heading text "Create" but test only has button → no match
4. **Ambiguity check** — consult `translationValueCounts` from the Source Scanner:
   - If the matched text value has `count >= 2` in `translationValueCounts`
     (meaning 2+ different translation keys share this exact string), tag
     the match as `LOW_CONFIDENCE`. This means we can't be sure WHICH
     occurrence of "Role" changed — the one our test uses, or a different one.
   - `LOW_CONFIDENCE` matches require corroboration before classifying as
     BREAKING. Corroboration sources (any one is sufficient):
     a. **Baseline comparison**: the translation key that changed is the SAME
        key that was previously mapped to this locator in the last baseline
     b. **Live DOM validation**: navigate to the page where this locator is
        used and confirm the rendered text actually changed
   - If no corroboration found: downgrade from BREAKING to **WARNING** with
     note: "Ambiguous text match — N translation keys share this value.
     Manual verification recommended."
   - If `count == 1` (unique value): classify normally as BREAKING
5. For each match: trace through the dependency graph (Step 4) to find impacted Polarion IDs

**Layer 3 — Route matching:**
For each upstream route from the Source Scanner:
1. Match against route constants (`FLEET_VIRT_ROUTES`, `RBAC_ROUTES`)
2. If path changed → BREAKING (page object `goto()` navigates wrong)
3. If new route added → INFO

### Step 3: Baseline Comparison (Source Now vs Source Before)

If a previous baseline exists, compare the current Source Scanner output against it.

**Comparison method:** Match selectors by VALUE (the raw `data-test` string),
not by key name. This handles naming convention differences between baseline
versions and source scanner output.

1. **Added selectors**: value present now, absent in baseline → INFO
2. **Removed selectors**: value absent now, present in baseline → apply
   co-occurrence detection (see below), then BREAKING if test code uses it
3. **Changed selectors**: same key, different value → BREAKING
4. **Added translations**: INFO
5. **Changed translations**: compare old value against resolved locator inventory.
   If any locator uses the old value → BREAKING (test will fail)
6. **Changed routes**: BREAKING
7. **PF version change**: BREAKING (all CSS class selectors will break)

**Recurrence detection (drift-history cross-reference):**

For each drift item found, check `drift-history.jsonl` for matching entries.
Match by `element` field name. If a match is found:

1. **Extract the raw value** from the history's `after` field by stripping
   parenthetical metadata annotations. History entries contain commentary
   like `"data-test=\"save-search-name\" (attribute type mismatch, CHRONICALLY UNSTABLE)"`.
   Strip everything from the first `(` onward to get the raw value for comparison.
2. **Compare the raw `after` value** against the current upstream value.
   If they are identical: this is a recurrence — increment the occurrence counter.
   If they differ: this is a NEW drift item (the upstream value changed since
   the last check). Classify independently — do NOT inherit the previous severity.
3. Count total occurrences. If 3+ occurrences: flag as **chronically unstable**.

**File-scoped co-occurrence detection (for removed selectors):**

When a selector value from the baseline is NOT found in the current scan:

1. Check if the baseline entry has a `sourceFile` field (v3.0+ baselines only).
   If the baseline is v2.0 (no `sourceFile`), skip co-occurrence and classify
   the removal as BREAKING (current behavior).
2. If `sourceFile` is present: search the CURRENT scan for any NEW selectors
   (values not in baseline) that have the SAME `sourceFile`.
3. If one or more new selectors share the same file:
   - Classify as **WARNING**: "Possible rename in {sourceFile}: '{old_value}'
     removed, '{new_value}' added. Verify manually."
   - List all candidates (there may be multiple new selectors in the same file)
4. If no new selectors share the same file: classify as **BREAKING**: "Selector
   '{old_value}' removed from {sourceFile}. No replacement found in same file."

This avoids the false positives that fuzzy string matching would produce (e.g.,
`vm-advanced-search-button` and `vm-adv-search-toolbar` share a prefix but are
different elements in different files).

### Step 4: Impact Chain Tracing

For EVERY drift item found in Steps 2-3, trace the full impact chain using
the dependency graph from the Test Code Analyzer output:

**Path A — constant-backed locators:**
1. **Identify the constant** (if the locator references one)
2. **Find page objects** that use this constant (from `dependencyGraph.pageObjectToConstants`)
3. **ALSO find lib files** that use this constant (from `dependencyGraph.libToConstants`),
   then find page objects that import those lib files (from `pageObjectToLibImports`)
4. **Find specs** that use these page objects (from `dependencyGraph.specToPageObjects`)
5. **ALSO find specs** that directly import this constant (from `dependencyGraph.specToDirectConstants`)
6. **Find Polarion IDs** for all matched specs (from `dependencyGraph.specToPolarionIds`)

**Path B — hardcoded locators (no constant):**
1. The locator is in a specific file (page object, component, or lib file)
2. If in a **lib file**: find page objects that import this lib (from `pageObjectToLibImports`)
3. Find specs that use these page objects (from `dependencyGraph.specToPageObjects`)
4. Find Polarion IDs for those specs

**Path C — directly-imported constants:**
Some specs import constants directly (e.g., `RBAC_ROLES`) and use them in
assertions without going through a page object. When a constant changes:
1. Check `dependencyGraph.specToDirectConstants` for specs that import it
2. Find Polarion IDs for those specs
3. The impact chain skips the page object layer entirely

Every drift item MUST include the full `impactChain` in its output.

### Step 5: Live DOM Validation (if available, with tab awareness)

If Live Validator output is present:

1. For each element the tests expect to interact with, check if it exists in the DOM
2. **Tab-aware classification** — when a page has `tabStructure` (non-null):
   a. For each expected selector, search ALL tabs' `dataTestIds` arrays
   b. If found on the **default tab**: no issue (normal match)
   c. If found on a **non-default tab** but NOT on the default tab:
      classify as **WARNING**: "Element '{selector}' exists but only on tab
      '{tabName}', not the default tab '{defaultTab}'. Tests must navigate
      to this tab first."
   d. If **not found on ANY tab**: classify as **BREAKING**: "Element
      '{selector}' exists in upstream source but is not rendered on any tab
      in the live DOM."
3. **When `tabStructure` is null** (page has no tabs): fall back to checking
   the flat `dataTestIds` list as before.
4. **Wizard comparison (disambiguation):**
   Compare `wizardScopeTypes` from the live scan against `SCOPE_TYPES` constant
   values (text labels: "Global access", "Select cluster sets", "Select clusters").
   Compare `wizardSteps` (visible step labels like "Scope", "Roles", "Review")
   against step name text in `RBAC_WIZARD` constants — NOT against
   `WIZARD_STEP_IDS` (programmatic element IDs like "scope-selection",
   "identities", etc.). `WIZARD_STEP_IDS` is a different data type (element IDs
   vs visible labels) and may be orphaned (never imported by any spec).
   If scope types differ: WARNING. If step labels differ: WARNING.
5. If table column headers differ from constant values: WARNING

**When live validation is skipped entirely** (no cluster available):
- `tabStructure` data is unavailable
- Tab-aware classification is INACTIVE — all classification falls back to
  source-only comparison (Steps 2-3)
- Include in the report: "Tab-aware classification unavailable (no live cluster).
  Elements on non-default tabs may be reported as BREAKING when they are
  actually present but hidden behind a tab."

### Step 6: Classify Each Drift Item

Apply these classification rules:

| Category | Severity | Condition |
|----------|----------|-----------|
| Selector drift | BREAKING | Upstream `data-test` / `data-testid` value changed or removed, AND test code references the old value |
| Selector drift | WARNING | Attribute type mismatch — value matches but `data-test` vs `data-testid` differs |
| Selector drift | INFO | Upstream added a new `data-test` not present in test code |
| Translation drift | BREAKING | UI text used in a resolved locator (`getByRole({name: 'X'})` or constant) changed upstream |
| Translation drift | WARNING | UI text changed but only used in assertions, not locators |
| Route drift | BREAKING | URL path changed for a route used in page object `goto()` |
| Route drift | INFO | New route added upstream |
| Test ID drift | BREAKING | `data-testid` renamed or removed, test code uses old value |
| Test ID drift | INFO | New `data-testid` added upstream |
| PatternFly drift | BREAKING | PF CSS class prefix changed (e.g., `pf-v6-c` to `pf-v7-c`) |
| Live DOM drift | BREAKING | Element expected by test not found on ANY tab in live DOM |
| Live DOM drift | WARNING | Element present in live DOM but on non-default tab (requires tab navigation) |
| Live DOM drift | WARNING | Element present in live DOM but with different properties |
| Vacuous assertion | BREAKING | Negative assertion references a selector no longer present upstream |
| Locator fragility | WARNING | Locator scored >= 80 |
| Locator fragility | INFO | Locator scored 60-79 |
| Chronically unstable | WARNING | Same element appears in `drift-history.jsonl` 3+ times |
| Orphan constant (full) | INFO | Entire constant never imported outside constants |
| Orphan constant (property) | INFO | Specific property of an imported constant never accessed |
| Orphan page object | INFO | Page object exists but no fixture/spec uses it |

**Orphan pass-through rule:** The Test Code Analyzer provides a definitive,
grep-verified orphan list with three scopes: `full-object`, `property-group`,
and `property`. Do NOT independently re-derive orphan status. Pass through the
test-code-analyzer's `orphans.unusedConstants` list unchanged into your
`orphanReport`. You may generate INFO drift items referencing them, but the
orphan list itself comes from the test-code-analyzer — not from your analysis.

### Step 7: Vacuous Assertion Check

If absence assertions are provided:
1. For each negative assertion, extract the selector being checked
2. Cross-reference against Source Scanner upstream selectors
3. If the selector is NOT present upstream, classify as BREAKING vacuous assertion

### Step 8: Fragility Summary

Include a summary of locator health from the fragility report:
- Total locators, average fragility score (0–100)
- Count of high-risk locators (score ≥ 60)
- Strategy distribution (how many getByRole vs CSS vs data-test)
- Top 5 most fragile locators with file paths

### Step 9: History Trend Analysis

If drift history is provided:
1. Count how many times each element appears across past runs
2. Flag elements with 3+ appearances as "chronically unstable"
3. Include in the report with dates of each occurrence

## Output Format

Return your findings as a single JSON structure:

```json
{
  "analysisTimestamp": "<ISO 8601>",
  "baselineDate": "<date of previous baseline or 'none'>",

  "summary": {
    "breaking": 0,
    "warning": 0,
    "info": 0,
    "total": 0
  },

  "driftItems": [
    {
      "id": "drift-001",
      "category": "selector | translation | route | testId | patternfly | liveDom | orphan",
      "severity": "BREAKING | WARNING | INFO",
      "description": "<human-readable summary>",
      "upstream": {
        "key": "<selector/translation/route key>",
        "value": "<current upstream value>",
        "source": "<file or MCP tool that reported it>"
      },
      "testCode": {
        "file": "<relative path in console-e2e>",
        "line": 42,
        "constantName": "<constant reference, or null for hardcoded locators>",
        "currentValue": "<value in test code>",
        "locatorStrategy": "<getByRole | getByText | locator | etc>",
        "locatorRole": "<button | tab | heading | null>"
      },
      "confidence": "HIGH | LOW",
      "confidenceReason": "<null if HIGH, otherwise: 'N translation keys share value \"X\"'>",
      "corroborated": true,
      "corroborationSource": "<baseline | liveDom | null>",
      "baseline": {
        "value": "<value in previous baseline, or null>"
      },
      "liveDom": {
        "found": true,
        "actualValue": "<what the DOM shows, or null>"
      },
      "impactChain": {
        "upstreamSource": "<upstream file where the element is defined, if known>",
        "constant": "<constant name, e.g. RBAC_RA_TABLE.toolbar.createButtonLabel>",
        "constantFile": "<e.g. src/constants/fg-rbac.ts>",
        "pageObjects": ["<src/pages/fg-rbac/RoleAssignmentWizardPage.ts>"],
        "components": ["<src/components/fg-rbac/RoleAssignmentsTable.ts>"],
        "specFiles": ["<src/tests/fg-rbac/role-assignment-global-access.spec.ts>"],
        "polarionIds": ["RHACM4K-61726", "RHACM4K-61863"]
      },
      "recommendedFix": "<what needs to change in test code>"
    }
  ],

  "selectorVerification": {
    "verified": [
      {
        "value": "vm-search-input",
        "testCodeEvidence": { "constant": "FLEET_VIRT_SEARCH.searchInput", "file": "fleet-virt.ts" },
        "upstreamEvidence": { "source": "acm-source search_code", "found": true },
        "liveDomEvidence": { "found": true }
      }
    ],
    "notInTestCode": [
      {
        "value": "actions-dropdown",
        "source": "live-dom",
        "note": "Present in live DOM but no matching constant or locator in test code"
      }
    ]
  },

  "orphanReport": {
    "unusedConstants": [
      {
        "scope": "full-object | property-group | property",
        "name": "<constant or property path>",
        "file": "<constants file>",
        "childCount": "<number, only for property-group scope>",
        "reason": "<why it is orphaned>"
      }
    ],
    "unusedPageObjects": [
      {
        "file": "<page object path>",
        "reason": "<not instantiated in any fixture>"
      }
    ],
    "note": "Orphan data passed through from Test Code Analyzer (grep-verified). Not re-derived by this analyzer."
  },

  "markdownReport": "<formatted markdown table of all drift items>"
}
```

The `markdownReport` field should contain a complete, human-readable report
structured as:

```markdown
# Virt UI Drift Report -- <date>

## Summary
- BREAKING: N items (tests WILL fail)
- WARNING: N items (tests MAY become fragile)
- INFO: N items (no test impact, opportunities)

## BREAKING Items
| # | Category | Description | Test File | Before | After | Fix |
|---|----------|-------------|-----------|--------|-------|-----|

## WARNING Items
| # | Category | Description | Test File | Before | After | Fix |
|---|----------|-------------|-----------|--------|-------|-----|

## INFO Items
| # | Category | Description | Upstream Source | Details |
|---|----------|-------------|----------------|---------|
```

## Important

- **Rule 0 compliance**: Every constant name, property path, and selector value
  in your output MUST appear verbatim in an input file. See Rule 0 above.
- Every drift item MUST have evidence from at least two sources (e.g., source
  scanner shows value X, test code shows value Y).
- Do NOT report drift for items that match exactly between source and test code.
- Do NOT invent, synthesize, or fabricate constant names or property paths.
  If a selector exists in live DOM or upstream but not in test code, report it
  under `selectorVerification.notInTestCode` — never under `verified`.
- Be precise about which FILE and LINE in the test code needs updating.
- The `recommendedFix` must be specific enough for the code-fixer subagent to
  generate the exact `StrReplace` edit.
- Orphan data comes from the Test Code Analyzer — pass it through unchanged.

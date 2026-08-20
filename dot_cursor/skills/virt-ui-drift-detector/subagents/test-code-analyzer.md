# Test Code Analyzer Subagent

**Cursor Subagent Type:** `pattern-analyzer`
**Shared Agent Reference:** `~/.cursor/agents/pattern-analyzer.md`

Scan the `stolostron/console-e2e` repo (remote, branch `main`) for all UI element
references used by virt-related test automation. Extract every selector, locator
strategy, route constant, and hardcoded UI string.

## Context

You are a `pattern-analyzer` specialist running in **drift detection mode**. Your
standard capabilities (repo structure knowledge: constants, page objects, components,
services, fixtures) are all available. This template overrides two behaviors:

1. **Data source override:** Use a **shallow clone** instead of local file reads.
2. **Extra extraction:** Also find absence assertions for vacuous check.

You are scanning test automation code from `stolostron/console-e2e@main` to build
a complete inventory of what UI elements the tests depend on. This inventory will
be compared against upstream source code to detect drift.

**Source:** GitHub remote — `stolostron/console-e2e`, branch `main`
**Tool:** Shallow `git clone` — all operations are local after the initial clone.

**CRITICAL: DATA SOURCE — SHALLOW CLONE (ZERO API CALLS)**

**Single data source: shallow clone.** Clone `console-e2e@main` once, use it
for ALL steps — file reads, searches, directory listings, everything.

```bash
DRIFT_CLONE=$(mktemp -d)
git clone --depth 1 --branch main --single-branch --quiet \
  https://github.com/stolostron/console-e2e.git "$DRIFT_CLONE" 2>/dev/null
```

This approach is:
- **Zero API calls** — no GitHub Search API, no Contents API, no rate limits
- **Complete** — searches every file, no pagination limits
- **Fast** — all local I/O, no network round-trips per file
- **Atomic** — one snapshot of `main` used consistently across all steps

All Steps (1 through 8) read from `$DRIFT_CLONE`. Use `cat` to read files,
`ls` to list directories, `grep` to search. No GitHub MCP calls needed.

After all steps complete, clean up: `rm -rf "$DRIFT_CLONE"`

This ensures the comparison is always against committed main, regardless of
what branch is checked out locally.

## Instructions

### Step 1: Read Constants Files

Read these files from the shallow clone:

```bash
cat "$DRIFT_CLONE/src/constants/fleet-virt.ts"
cat "$DRIFT_CLONE/src/constants/fg-rbac.ts"
cat "$DRIFT_CLONE/src/constants/selectors.ts"
cat "$DRIFT_CLONE/src/constants/app.ts"
```

Also check for new constants files:
```bash
ls "$DRIFT_CLONE/src/constants/"*.ts
```
If new virt-related constants files are added in the future, they will follow
the same naming convention in `src/constants/`. Read any additional `.ts`
files that contain virt/rbac/fleet selectors.

For each exported constant, capture:
- The constant name (e.g., `FLEET_VIRT_SEARCH.searchInput`)
- The selector value (e.g., `[data-test="vm-search-input"] input`)
- The selector type: `data-test`, `data-testid`, `aria-label`, `css-class`, `id`, `role-text`

### Step 2: Discover and Read Page Objects (auto-discovery)

**List directories**, then read every `.ts` file found from the clone:

```bash
ls "$DRIFT_CLONE/src/pages/fleet-virt/"*.ts 2>/dev/null
ls "$DRIFT_CLONE/src/pages/fg-rbac/"*.ts 2>/dev/null
ls "$DRIFT_CLONE/src/pages/infrastructure/"*.ts 2>/dev/null
```

For every `.ts` file found, read it with `cat`. This ensures new page objects
are automatically picked up without updating this template.

If a directory does not exist, skip it and note it in the output.

For each locator in each file, capture:
- The property or method name (e.g., `searchInput`, `vmTable`)
- The locator strategy: `getByRole`, `getByLabel`, `getByText`, `getByTestId`, `locator`
- The locator value (e.g., `button, { name: 'Create role assignment' }`)
- The line number
- Whether it references a constant from Step 1

### Step 3: Discover and Read Components (auto-discovery)

**List directories**, then read every `.ts` file from the clone:

```bash
ls "$DRIFT_CLONE/src/components/fleet-virt/"*.ts 2>/dev/null
ls "$DRIFT_CLONE/src/components/fg-rbac/"*.ts 2>/dev/null
```

For every `.ts` file found, read it with `cat`. This ensures new components
are automatically picked up without updating this template.

If a directory does not exist, skip it and note it in the output.

For each locator, capture the same fields as Step 2.

### Step 3b: Discover and Read Shared Lib Functions (auto-discovery)

Shared utility functions in `src/lib/` can contain locators that are imported by
page objects. These locators are invisible if only page objects are scanned.

**List the virt-related lib directory from the clone:**

```bash
ls "$DRIFT_CLONE/src/lib/fg-rbac/"*.ts 2>/dev/null
cat "$DRIFT_CLONE/src/lib/openshift-login.ts"
```

For every `.ts` file found, read it with `cat`. Extract locators the same way
as Steps 2-3. Also note which constants each lib file imports (these are part
of the dependency chain: constant → lib function → page object → spec).

`src/lib/openshift-login.ts` contains login locators and a PF CSS class
selector (`.pf-v6-c-alert`) that is drift-vulnerable.

If a directory does not exist, skip it.

For each locator found, capture the same fields as Step 2, plus mark the file
as `source: "lib"` to distinguish it from page objects and components.

### Step 4: Search for Inline UI References in Spec Files

Use the **shallow clone** (not GitHub Search API) to grep for inline locators:

```bash
grep -rn "page\.getByRole\|page\.getByText\|page\.getByTestId\|page\.locator" \
  "$DRIFT_CLONE/src/tests/fleet-virt/" "$DRIFT_CLONE/src/tests/fg-rbac/" \
  --include="*.ts"
```

For each match, capture:
- File path and line number
- The locator strategy and value
- Flag it as `INLINE_LOCATOR` (these are anti-patterns but still need drift tracking)

### Step 5: Extract Route References

Use the **shallow clone** to grep for route usage:

```bash
grep -rn "FLEET_VIRT_ROUTES\|RBAC_ROUTES" "$DRIFT_CLONE/src/" --include="*.ts"
grep -rn "\.goto(" "$DRIFT_CLONE/src/pages/fleet-virt/" "$DRIFT_CLONE/src/pages/fg-rbac/" \
  "$DRIFT_CLONE/src/pages/infrastructure/" --include="*.ts"
```

For each route, capture:
- The constant name (e.g., `FLEET_VIRT_ROUTES.vmList`)
- The actual URL path value
- Which page object uses it

### Step 6: Extract PatternFly Version Usage

Use the **shallow clone**:

```bash
grep -rn "pf-v" "$DRIFT_CLONE/src/constants/" "$DRIFT_CLONE/src/pages/" \
  "$DRIFT_CLONE/src/components/" --include="*.ts"
```

Capture the PF version prefix string used (e.g., `pf-v6-c`).

### Step 7: Search for Absence Assertions

Use the **shallow clone**:

```bash
grep -rn "not\.toBeVisible\|toHaveCount(0)\|not\.toBeAttached\|not\.toBeEnabled\|not\.toContainText" \
  "$DRIFT_CLONE/src/tests/fleet-virt/" "$DRIFT_CLONE/src/tests/fg-rbac/" \
  --include="*.ts"
```

For each match, capture:
- File path and line number
- The assertion type and the selector being asserted on
- Flag as `ABSENCE_ASSERTION`

### Step 8: Build Dependency Graph (Impact Tracing)

Build three maps that enable full impact tracing from any selector change
to the specific Polarion test cases it would break.

**Step 8a: Spec-to-PageObject imports**

Use the **shallow clone** to extract all import statements from spec files:

```bash
grep -rn "^import " "$DRIFT_CLONE/src/tests/fleet-virt/" \
  "$DRIFT_CLONE/src/tests/fg-rbac/" --include="*.ts"
```

Also read fixture files from the clone to trace page object instantiation:
```bash
cat "$DRIFT_CLONE/src/fixtures/fleet-virt-test.ts"
cat "$DRIFT_CLONE/src/fixtures/fg-rbac-test.ts"
```

Build map: `{specFile -> [pageObjectFiles, componentFiles]}` by tracing:
spec imports fixture → fixture instantiates page objects → page objects listed.

**ALSO capture direct spec-to-constant imports.** Some specs import constants
directly (e.g., `import { RBAC_ROLES } from '@constants/fg-rbac'`) and use
them in assertions without going through a page object. Extract from the grep
output above — look for any import from `@constants/*`. Build a
`specToDirectConstants` map: `{specFile -> [constantNames]}`.

To capture which sub-properties each spec actually uses, grep at **property
level** (not just top-level name). For each directly-imported constant, run:
```bash
grep -rn "RBAC_ROLES\.\|SCOPE_TYPES\.\|RBAC_WIZARD\.\|GRANULARITY_OPTIONS\.\|MCRA_RESOURCE\.\|WIZARD_STEP_IDS\.\|WIZARD_SELECT_IDS\." \
  "$DRIFT_CLONE/src/tests/" --include="*.ts"
```

Parse the output to build `specToDirectConstantProperties`:
`{specFile -> ["RBAC_ROLES.expected", "SCOPE_TYPES.global", ...]}`.

This is critical for two reasons:
1. If a directly-imported constant changes upstream, the impact chain is:
   constant → spec → Polarion ID (no page object in between).
2. For **property-level orphan detection** (Step 8d): a spec may import
   `RBAC_ROLES` but only use `.expected` and `.permissions`. The remaining
   properties are orphaned even though the top-level name is imported.

**ALSO capture page-object-to-lib imports.** Extract from page object files:
```bash
grep -rn "from '@lib/" "$DRIFT_CLONE/src/pages/fleet-virt/" \
  "$DRIFT_CLONE/src/pages/fg-rbac/" "$DRIFT_CLONE/src/pages/infrastructure/" \
  --include="*.ts"
```
Build a `pageObjectToLibImports` map: `{pageObjectFile -> [libFilePaths]}`.

This captures the chain: constant → lib function → page object → spec.

**Step 8b: Spec-to-Polarion IDs**

Use the **shallow clone**:

```bash
grep -rn "RHACM4K-[0-9]*" "$DRIFT_CLONE/src/tests/fleet-virt/" \
  "$DRIFT_CLONE/src/tests/fg-rbac/" --include="*.ts" -o
```

Build map: `{specFile -> [polarionIds]}`
Extract Polarion IDs from test titles (e.g., `RHACM4K-60558` in `test('RHACM4K-60558 ...)`).

**Step 8c: PageObject-to-Constants (and Lib-to-Constants)**

From Steps 2, 3, and 3b, compile which page object/component/lib files reference
which constants. Use the `referencesConstant` field already captured per locator.

Build maps:
- `{pageObjectFile -> [constantNames]}`
- `{libFile -> [constantNames]}` (e.g., `src/lib/fg-rbac/role-assignment-actions.ts` → `["RBAC_RA_TABLE.toolbar.createButtonLabel"]`)

**Step 8d: Orphan Detection (Property-Level)**

Orphan detection operates at TWO levels: top-level constants AND individual
properties. A constant like `RBAC_RA_TABLE` may be imported by 2 files, but
if only 2 of its 26 leaf properties are ever accessed, the other 24 are
property-level orphans.

**Phase 1 — Top-level check (fast filter):**

For each top-level exported constant from Step 1 (e.g., `WIZARD_STEP_IDS`,
`RBAC_RA_TABLE`, `FLEET_VIRT_SEARCH`), run:
```bash
grep -r "<TOP_LEVEL_NAME>" "$DRIFT_CLONE/src/" --include="*.ts" -l \
  | grep -v '/constants/'
```
If no results → the entire constant is a **fully orphaned** constant.
Report it once: `{ scope: "full-object", name: "WIZARD_STEP_IDS" }`.
No property-level scan needed for fully orphaned constants.

**Phase 1b — Scalar vs object classification:**

Before running property-level checks, classify each constant as **scalar** or
**object**. Scalar constants (string values like `` `.${PF}-spinner` `` or
`'some-selector'`) are used directly as `page.locator(PF_SPINNER)` — they
have no properties and Phase 2 does not apply to them. If a scalar constant
passes the Phase 1 import check, it is fully used and NOT orphaned.

To classify: read the constant's definition from Step 1. If the value after
`export const NAME =` starts with `{` → object. If it starts with a quote
(`` ` ``, `'`, `"`) → scalar. Skip Phase 2 for scalar constants.

**Phase 2 — Property-level check (for partially-used object constants):**

For each **object-type** constant that IS imported somewhere (passed Phase 1),
run ONE compound grep to find all property access:
```bash
grep -rn "<TOP_LEVEL_NAME>\." "$DRIFT_CLONE/src/" --include="*.ts" \
  | grep -v '/constants/'
```
Parse the output to extract the set of property paths actually accessed
(e.g., `RBAC_RA_TABLE.toolbar.createButtonLabel`, `RBAC_RA_TABLE.emptyState.title`).

Also collect property paths from already-gathered data (no extra grep needed):
- `pageObjectToConstants` map (Step 8c) — property paths from page objects
- `libToConstants` map (Step 8c) — property paths from lib files
- `specToDirectConstantProperties` (Step 8a) — property paths from specs

Union all these sources to get the complete set of **used properties**.

Compare against the full set of leaf properties from Step 1. Any leaf property
NOT in the used set is a **property-level orphan**.

**Phase 3 — Practical grouping:**

If ALL leaf properties under a sub-object are orphaned, collapse them into
one entry at the sub-object level:
- If `RBAC_RA_TABLE.columns.role`, `.columns.subjectName`, `.columns.type`,
  etc. are ALL orphaned → report as: `{ scope: "property-group",
  name: "RBAC_RA_TABLE.columns", childCount: 8 }`
- If only SOME leaves under a sub-object are orphaned → report each
  individually: `{ scope: "property", name: "RBAC_RA_TABLE.toolbar.createButtonId" }`

**Orphan page objects:**

Page object files from Steps 2-3 that are NOT instantiated in any fixture
file (Step 8a). List them as `{ file: "<path>", reason: "..." }`.

## Output Format

Return your findings as a single JSON structure:

```json
{
  "scanTimestamp": "<ISO 8601>",
  "source": "github:stolostron/console-e2e@main",

  "constants": {
    "fleet-virt.ts": {
      "<constantPath>": {
        "value": "<selector string>",
        "type": "data-test | data-testid | aria-label | css-class | id | role-text"
      }
    },
    "fg-rbac.ts": { "...": "..." },
    "selectors.ts": { "...": "..." },
    "app.ts": { "...": "..." }
  },

  "pageObjectLocators": [
    {
      "file": "<relative path>",
      "property": "<property or method name>",
      "strategy": "getByRole | getByLabel | getByText | getByTestId | locator",
      "value": "<locator argument string>",
      "line": 42,
      "referencesConstant": "<constant name or null>"
    }
  ],

  "componentLocators": [
    {
      "file": "<relative path>",
      "property": "<property or method name>",
      "strategy": "...",
      "value": "...",
      "line": 15,
      "referencesConstant": "<constant name or null>"
    }
  ],

  "inlineLocators": [
    {
      "file": "<relative path>",
      "line": 88,
      "strategy": "...",
      "value": "...",
      "flag": "INLINE_LOCATOR"
    }
  ],

  "absenceAssertions": [
    {
      "file": "<relative path>",
      "line": 42,
      "assertionType": "not.toBeVisible | toHaveCount(0) | not.toBeAttached",
      "selector": "<the selector being asserted on>",
      "flag": "ABSENCE_ASSERTION"
    }
  ],

  "routes": [
    {
      "constant": "FLEET_VIRT_ROUTES.vmList",
      "path": "/fleet-virtualization/kubevirt.io~v1~VirtualMachine/all-clusters/all-namespaces",
      "usedBy": ["FleetVirtPage.goto()"]
    }
  ],

  "pfVersion": "pf-v6-c",

  "dependencyGraph": {
    "specToPageObjects": {
      "src/tests/fleet-virt/advanced-search.spec.ts": ["FleetVirtPage", "AdvancedSearchModal", "SavedSearches"],
      "src/tests/fg-rbac/role-assignment-global-access.spec.ts": ["UserDetailsPage", "RoleAssignmentWizardPage", "RoleAssignmentsTable"]
    },
    "specToDirectConstants": {
      "src/tests/fg-rbac/roles-page-validation.spec.ts": ["RBAC_ROLES"]
    },
    "specToDirectConstantProperties": {
      "src/tests/fg-rbac/roles-page-validation.spec.ts": ["RBAC_ROLES.expected", "RBAC_ROLES.permissions"],
      "src/tests/fg-rbac/role-assignment-global-access.spec.ts": ["SCOPE_TYPES.global", "SCOPE_TYPES.clusterSets", "SCOPE_TYPES.clusters"]
    },
    "specToPolarionIds": {
      "src/tests/fleet-virt/advanced-search.spec.ts": ["RHACM4K-60558", "RHACM4K-60560"],
      "src/tests/fg-rbac/role-assignment-global-access.spec.ts": ["RHACM4K-61726"]
    },
    "pageObjectToConstants": {
      "src/pages/fleet-virt/FleetVirtPage.ts": ["FLEET_VIRT_ADVANCED_SEARCH.openButton", "FLEET_VIRT_SEARCH.searchInput"],
      "src/pages/fg-rbac/UserDetailsPage.ts": ["RBAC_USER_DETAIL.tabs.roleAssignments", "RBAC_USER_DETAIL.fields.generalInformation"]
    },
    "pageObjectToLibImports": {
      "src/pages/fg-rbac/RoleDetailsPage.ts": ["src/lib/fg-rbac/role-assignment-actions.ts"],
      "src/pages/fg-rbac/UserDetailsPage.ts": ["src/lib/fg-rbac/role-assignment-actions.ts"]
    },
    "libToConstants": {
      "src/lib/fg-rbac/role-assignment-actions.ts": ["RBAC_RA_TABLE.toolbar.createButtonLabel"]
    }
  },

  "orphans": {
    "unusedConstants": [
      { "scope": "full-object", "name": "WIZARD_STEP_IDS", "file": "fg-rbac.ts", "reason": "Exported but never imported outside constants" },
      { "scope": "property-group", "name": "RBAC_RA_TABLE.columns", "file": "fg-rbac.ts", "childCount": 8, "reason": "Top-level constant imported by 2 files but all 8 .columns properties are never accessed" },
      { "scope": "property", "name": "RBAC_RA_TABLE.toolbar.createButtonId", "file": "fg-rbac.ts", "reason": "Top-level constant imported but this specific property never accessed (only .toolbar.createButtonLabel is used)" },
      { "scope": "property", "name": "FLEET_VIRT_ADVANCED_SEARCH.detailsContainer", "file": "fleet-virt.ts", "reason": "Top-level constant imported but this property never accessed" }
    ],
    "unusedPageObjects": [
      { "file": "src/pages/fleet-virt/VmDetailsPage.ts", "reason": "Not instantiated in any fixture" }
    ]
  },

  "summary": {
    "totalConstants": 0,
    "totalPageObjectLocators": 0,
    "totalComponentLocators": 0,
    "totalInlineLocators": 0,
    "totalAbsenceAssertions": 0,
    "totalRoutes": 0,
    "totalOrphanConstants": 0,
    "orphanBreakdown": { "fullObject": 0, "propertyGroup": 0, "property": 0 },
    "totalOrphanPageObjects": 0
  }
}
```

## Output Persistence (MANDATORY)

After building the JSON structure, write it to a file **before** returning it:

```bash
cat > /tmp/drift-scan-testcode-output.json << 'ENDJSON'
<your complete JSON output here>
ENDJSON
```

Your **final message** must contain ONLY the JSON structure — no narrative text,
no explanation, no markdown formatting. The orchestrator parses your final message
as raw JSON.

## Important

- ALL file reads MUST come from the shallow clone (`$DRIFT_CLONE`). Do NOT use
  the Read tool on local checkout paths or GitHub MCP API calls.
- If a file or directory does not exist in the clone, note it in the output as
  `"fileNotFound": true`.
- Extract the EXACT selector/locator strings. Do not normalize or simplify.
- Count accurately. The summary counts must match the actual items listed.
- For dynamic selectors (functions like `item: (name: string) => ...`),
  capture the template pattern, not a specific instantiation.
- For array constants (e.g., `RBAC_ROLES.expected`), extract the full array
  contents as a JSON array — do NOT summarize as `"[8 role names]"`.
- Your final message MUST be valid JSON only. No narrative.

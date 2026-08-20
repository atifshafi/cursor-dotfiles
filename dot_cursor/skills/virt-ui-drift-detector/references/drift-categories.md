# Drift Categories -- Classification Rules

Six categories of UI drift, each with severity rules and detection methods.

---

## 1. Selector Drift

A `data-test`, `data-testid`, `data-test-id`, or `aria-label` attribute in
upstream source code changed value, was removed, or was added.

| Condition | Severity | Rationale |
|-----------|----------|-----------|
| Selector value changed AND test code uses the old value | BREAKING | `locator('[data-test="old"]')` will find nothing |
| Selector removed AND test code uses it | BREAKING | Locator returns empty set, test fails |
| Selector possibly renamed (co-occurrence: removed + new added in same source file) | WARNING | May be a rename — verify manually before updating |
| Attribute type mismatch (value matches but `data-test` vs `data-testid` differs) | WARNING | Works today but fragile if either side changes attribute naming |
| New selector added upstream, test code does not use it | INFO | Opportunity to adopt a stable test ID |
| Selector value changed but test code does NOT reference it | NONE | No impact on tests |

**Detection method:** kubevirt-plugin selectors: shallow clone + exhaustive
`grep -rn 'data-test'` (replaces MCP `search_code` which caps at 30 results).
ACM Console selectors: `acm-source` MCP (`search_code`, `find_test_ids`).
Compare against `constants/fleet-virt.ts` and `constants/fg-rbac.ts` values.

**Common causes:** Upstream refactored a component, renamed a `data-test`
attribute during a PR review, or adopted a new naming convention.

---

## 2. Translation Drift

UI label text in translation files changed (button names, tab labels, heading
text, placeholder strings, error messages, wizard step names).

| Condition | Severity | Rationale |
|-----------|----------|-----------|
| Text used in `getByRole('button', { name: 'X' })` changed | BREAKING | Locator will not match the new button text |
| Text used in `getByText('X')` changed | BREAKING | Text match fails |
| Text used in `getByLabel('X')` changed | BREAKING | Label match fails |
| Text stored in constants but only used in assertions (not locators) | WARNING | Assertion may fail but test reaches the element |
| Text changed for a label not referenced in test code | NONE | No impact |

**Detection method:** Compare `acm-source -> search_translations()` output
against hardcoded strings in constants files and page object locators.

**Key translations to watch:**
- `RBAC_RA_TABLE.toolbar.createButtonLabel` ("Create role assignment")
- `RBAC_WIZARD.title` ("Create role assignment")
- `FLEET_VIRT_SAVED_SEARCH.saveButton` ("Save search")
- `FLEET_VIRT_ADVANCED_SEARCH.footer.searchButton` ("Search")
- VM action button labels (Start, Stop, Pause, Restart)
- Wizard step names and scope type labels

---

## 3. Route Drift

Navigation URL paths changed for pages used by test automation.

| Condition | Severity | Rationale |
|-----------|----------|-----------|
| Route path changed AND page object `goto()` uses it | BREAKING | `page.goto()` navigates to wrong URL, gets 404 |
| Route removed entirely | BREAKING | Page no longer accessible at that path |
| New route added for an existing feature | WARNING | Tests may be navigating to a deprecated path |
| Route added for a new feature | INFO | Opportunity to add new test coverage |

**Detection method:** Compare `acm-source -> get_routes()` output against
`FLEET_VIRT_ROUTES` and `RBAC_ROUTES` constants.

**Routes most likely to drift:**
- `/fleet-virtualization/kubevirt.io~v1~VirtualMachine/...` (changed in CNV 4.22)
- `/multicloud/user-management/identities/users`
- `/multicloud/infrastructure/clusters/sets/details/...`

---

## 4. Test ID Drift

`data-testid` attributes specifically (as opposed to `data-test` which is
covered by Selector Drift). Some upstream repos use `data-testid` for React
Testing Library compatibility.

**Attribute normalization:** During matching, `data-test`, `data-testid`, and
`data-test-id` are treated as equivalent for VALUE comparison. If the value
matches but the attribute type differs (e.g., upstream uses `data-test` but
test code uses `getByTestId` targeting `data-testid`), it is classified as
WARNING, not BREAKING.

| Condition | Severity | Rationale |
|-----------|----------|-----------|
| `data-testid` value renamed AND test uses `getByTestId('old')` | BREAKING | Locator fails |
| `data-testid` removed from upstream component | BREAKING | Test locator finds nothing |
| Value matches but attribute type differs (`data-test` vs `data-testid`) | WARNING | Works today but fragile |
| New `data-testid` added | INFO | Could replace fragile CSS selectors |

**Detection method:** kubevirt-plugin: grep output (includes `attributeType`).
ACM Console: `acm-source -> find_test_ids()`. Compare against `getByTestId()`
calls and `[data-test="..."]` locators in page objects and components.

---

## 5. PatternFly Drift

The PatternFly CSS class prefix version changed (e.g., `pf-v5-c` to `pf-v6-c`,
or `pf-v6-c` to `pf-v7-c`).

| Condition | Severity | Rationale |
|-----------|----------|-----------|
| PF version prefix changed | BREAKING | Every CSS class selector breaks: `.pf-v6-c-spinner` becomes `.pf-v7-c-spinner` |
| PF component structure changed (new wrapper elements) | WARNING | `locator('.pf-v6-c-select')` may need hierarchy adjustment |

**Detection method:** Compare PF class prefix in upstream source against
`const PF = 'pf-v6-c'` in `src/constants/selectors.ts`.

**Scope of impact:** A PF version change affects ALL areas, not just virt.
The `PF` constant centralizes this, so updating it fixes all PF-based selectors.
But any hardcoded PF classes outside the constant system will break silently.

---

## 6. Live DOM Drift

Elements expected by test code are missing from, or different in, the actual
rendered DOM on a live cluster.

**Tab-aware detection:** The live validator now captures per-tab element
visibility. When a page has tabs, each tab's DOM is snapshotted separately.
An element found on a non-default tab is not "missing" — it requires tab
navigation before interaction.

| Condition | Severity | Rationale |
|-----------|----------|-----------|
| Element not found on ANY tab in live DOM | BREAKING | Test will timeout waiting for element |
| Element present but on non-default tab | WARNING | Test must navigate to the correct tab first |
| Element present but with different text/label | WARNING | Role-based locator may not match |
| Element present but in different DOM position | WARNING | CSS-based locators may not match |
| Wizard has different steps than expected | WARNING | Step-by-step test flow will break |
| Extra elements in DOM not in test code | INFO | Test coverage gaps |

**Detection method:** Compare `playwright -> browser_snapshot()` output
(with per-tab `tabStructure`) against test code expectations. When live
validation is skipped (no cluster), tab-aware classification is unavailable.

**When live validation is most valuable:**
- After ACM version upgrades
- After CNV version upgrades
- When feature gates change (FG-RBAC enabled/disabled)
- When OCP dynamic plugin loading behavior changes

---

## Cross-Category Rules

1. A single upstream change can produce multiple drift items across categories.
   Example: renaming a component creates selector drift + test ID drift.

2. When the same element is flagged by both source analysis (categories 1-5)
   and live validation (category 6), prefer the HIGHER severity.

3. Drift items with severity NONE are not reported. Only BREAKING, WARNING,
   and INFO items appear in the drift report.

4. When a selector value changes and a translation also changes for the same
   UI element, they are two separate drift items with independent fixes.

---

## Category 7: Vacuous Assertion Drift

A vacuous assertion is a negative check (`not.toBeVisible`, `toHaveCount(0)`)
on a selector that no longer exists upstream. It passes forever without testing
anything — the most dangerous form of test-side rot.

| Condition | Severity | Example |
|-----------|----------|---------|
| Negative assertion references a selector that was renamed/removed upstream | BREAKING | `expect(deleteButton).not.toBeVisible()` where `deleteButton` uses a `data-test` that no longer exists |
| Negative assertion references a selector still present upstream | NONE | Normal test — no drift |

**Detection method:**
1. `extract-local-selectors.sh` finds all negative assertions in spec files
2. Cross-reference each asserted selector against Phase 1A upstream results
3. If the selector is NOT present upstream, it is vacuous

**Why BREAKING:** A vacuous assertion means a security/permission guard or
feature-flag check is silently not testing anything. The test passes, but the
thing it was guarding goes untested. Unlike regular drift (which causes
failures), vacuous drift causes false passes.

---

## Category 8: Locator Fragility

Locators scored ≥60 by `fragility-score.py` are fragile and likely to break
even without upstream changes.

| Condition | Severity | Example |
|-----------|----------|---------|
| Locator score ≥ 80 (nth-positional, xpath, deep chain) | WARNING | `.locator('tr').nth(2)` — breaks on row insertion |
| Locator score 60–79 (PF class, CSS class, tag) | INFO | `.locator('.pf-v6-c-modal-box')` — breaks on PF upgrade |
| Locator score < 60 | NONE | Not reported |

**Detection method:** `scripts/fragility-score.py` scores every locator.
Include the summary in the drift report alongside upstream-vs-local drift.
Fragile locators are not "drift" (nothing changed) but are pre-drift — they
predict where the next breakage will come from.

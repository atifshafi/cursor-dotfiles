# Locator Count Methodology — Fragility Scorer vs Test Code Analyzer

Two tools count locators in the console-e2e test code. They use different
counting methods, producing different totals. This is expected behavior.

## fragility-score.py

Counts **per regex match** — every line containing a Playwright locator call
(`getByRole`, `getByText`, `getByLabel`, `getByTestId`, `getByPlaceholder`,
`.locator()`) is one entry. A chained call like
`this.page.getByRole('grid').getByRole('row')` produces **2** entries
(one per `.getByRole`).

**Scope:** `SCAN_DIRS` — page objects, components, and lib files.

## test-code-analyzer subagent

Counts **per named property** — each locator accessor on a page object
or component class (e.g., `get searchInput()`, `clickNext()`) is one entry.
A method body with 3 chained locator calls produces **1** entry (the method).

**Scope:** Same directories as fragility scorer, plus inline locators in
spec files (flagged separately as `INLINE_LOCATOR`).

## Expected Gap

The fragility scorer typically reports 20-40% more locators than the test
code analyzer because of chained calls. For example, in the 2026-08-10 run:
- Fragility scorer: 193
- Test code analyzer: 156 (125 page-object + 31 component)
- Gap: 37 (24%) — within expected range

This gap is not a data quality issue and does not need reconciliation.

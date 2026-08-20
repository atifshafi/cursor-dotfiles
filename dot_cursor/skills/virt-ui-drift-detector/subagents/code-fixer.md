# Code Fixer Subagent

Generate specific code edits to fix UI drift items detected by the diff analyzer.

## Context

The diff analyzer found BREAKING and/or WARNING drift items between upstream
ACM Console / kubevirt-plugin source code and the console-e2e test automation.
Your job is to generate the exact `StrReplace` edits to fix each item.

**Repo:** `stolostron/console-e2e` (edits are generated as relative paths for
the user to apply to their local checkout, whichever branch they're on)

## Drift Items to Fix

```
{DRIFT_ITEMS}
```

## Instructions

For each drift item, determine which file(s) need updating and generate edits.

### Fix Strategy by Category

**Selector drift (data-test / data-testid changed):**
1. Find the constant in `src/constants/fleet-virt.ts` or `src/constants/fg-rbac.ts`
2. Update the constant value to match the new upstream selector
3. If the selector is used directly in a page object (not via constant), update the page object too
4. Check if any spec files use the selector inline (these should also be updated, though they are anti-patterns)

**Translation drift (button/label text changed):**
1. Find every `getByRole('button', { name: 'OLD_TEXT' })` or `getByText('OLD_TEXT')` in page objects and components
2. Update the text to match the new translation
3. Also update any constant that stores the old text (e.g., `RBAC_RA_TABLE.toolbar.createButtonLabel`)
4. Check spec files for any inline text references

**Route drift (URL path changed):**
1. Update the route constant in `src/constants/fleet-virt.ts` or `src/constants/fg-rbac.ts`
2. Verify that page object `goto()` methods use the constant (they should -- if they hardcode the URL, fix that too)

**Test ID drift (data-testid renamed):**
1. Same as selector drift -- update the constant value

**PatternFly drift (PF class prefix changed):**
1. Update `const PF = 'pf-vN-c'` in `src/constants/selectors.ts`
2. Search for any hardcoded PF class references in page objects or components
   that do NOT use the `PF` constant, and update those too

**Live DOM drift (element missing or different):**
1. If an element was removed upstream and the test interacts with it:
   - DO NOT delete the test step. Flag it for the user with a comment.
   - Suggest wrapping the interaction in a conditional check.
2. If an element changed properties (different aria-label, different text):
   - Update the locator to match the new properties.

### Edit Generation Rules

1. **Read the target file first** before generating any edit. Verify the old
   value actually exists at the expected location.
2. **Use `StrReplace`** with the exact `old_string` and `new_string`. Include
   enough surrounding context (3+ lines) to ensure uniqueness.
3. **One edit per drift item.** If a single drift item affects multiple files,
   generate one edit per file.
4. **Preserve formatting.** Match the existing indentation and style of the file.
5. **Do NOT change unrelated code.** Only modify the specific selector, route,
   or text that drifted. Leave everything else untouched.

### Output Per Drift Item

For each drift item, produce:

```json
{
  "driftId": "drift-001",
  "edits": [
    {
      "file": "<absolute path>",
      "description": "<what this edit does>",
      "old_string": "<exact text to find in the file>",
      "new_string": "<replacement text>"
    }
  ],
  "manualReviewNeeded": false,
  "notes": "<any caveats or things the user should verify>"
}
```

## Output Format

Return ALL fixes as a single JSON structure:

```json
{
  "fixTimestamp": "<ISO 8601>",
  "totalDriftItems": 0,
  "totalEdits": 0,

  "fixes": [
    {
      "driftId": "drift-001",
      "severity": "BREAKING",
      "category": "selector",
      "description": "FLEET_VIRT_SEARCH.searchInput changed from [data-test=\"vm-search-input\"] to [data-test=\"vm-search-bar\"]",
      "edits": [
        {
          "file": "src/constants/fleet-virt.ts",
          "description": "Update search input data-test selector",
          "old_string": "searchInput: '[data-test=\"vm-search-input\"] input',",
          "new_string": "searchInput: '[data-test=\"vm-search-bar\"] input',"
        }
      ],
      "manualReviewNeeded": false,
      "notes": null
    }
  ],

  "unfixable": [
    {
      "driftId": "drift-005",
      "reason": "Element was removed upstream. Test step may need to be rewritten or removed. Cannot auto-fix.",
      "suggestedAction": "Review the upstream PR that removed this element and decide whether to delete the test step or add a conditional skip."
    }
  ],

  "summary": {
    "autoFixable": 0,
    "manualReviewNeeded": 0,
    "unfixable": 0
  }
}
```

## Important

- **Read before writing.** For every file you plan to edit, read it first to
  confirm the `old_string` exists exactly as expected. If it doesn't, the edit
  will fail.
- **Never delete test steps.** If an upstream element was removed, flag it for
  manual review. The user decides whether to remove test coverage.
- **Preserve the constant structure.** When updating a selector in a constants
  file, keep the same `as const` assertion, the same property name, and the
  same comment structure.
- **Present ALL edits for user approval.** The orchestrator will show the edits
  to the user and ask "Should I apply these fixes?" before executing any
  StrReplace calls. NEVER auto-apply.

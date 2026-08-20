# Playwright Framework Patterns

Supplemental patterns for `stolostron/console-e2e`. For the full architecture (layers, files, services, fixtures, config, anti-patterns, placement rules), see `references/architecture-summary.md`.

**Local clone:** `/Users/ashafi/Documents/work/automation/qe-automation-repos/console-e2e`

---

## Locator Strategy

| Priority | Locator |
|----------|---------|
| 1 | `getByRole` |
| 2 | `getByLabel` |
| 3 | `getByPlaceholder` |
| 4 | `getByText` |
| 5 | `getByTestId` |
| 6 | `locator('[data-ouia-component-id=...]')` |
| 7 | CSS (last resort) |

Never `page.waitForTimeout(N)`.

---

## AcmTable vs Standalone Tables

| Pattern | When | Example |
|---------|------|---------|
| Extend `AcmTable` | Console uses `<AcmTable>` with usable OUIA row IDs | `ApplicationsTable`, `GovernanceTable` |
| Compose standalone | Table DOM differs (data-label headers, no OUIA) | `ClusterTable`, `RoleAssignmentsTable` |
| Compose both | Page has AcmTable + supplementary column data | `ClusterListPage` uses `AcmTable` + `ClusterTable` |

Column resolution: `ClusterTable.getColumnHeader(name)` -- never `td.nth(N)`.
`verifyRowVisible` / `verifyRowNotVisible` / `verifyEmpty` on `AcmTable` are ESLint-whitelisted under `playwright/expect-expect`.

---

## Test Structure Examples

### Polarion-mapped

```typescript
import { test, expect } from '@fixtures/acm-test';
import { ObservabilityService } from '@services/ObservabilityService';
import { OcCliService } from '@services/OcCliService';

test.describe('GPU ...', { tag: ['@clusters'] }, () => {
  test.beforeAll(async () => {
    const svc = new ObservabilityService(new OcCliService());
  });

  test('RHACM4K-63953: ...', async ({ clusterListPage }) => {
    await test.step('Verify GPU count column is visible', async () => {
      await clusterListPage.goto();
    });
  });
});
```

### ALC sanity (multi-test, no Polarion mapping)

```typescript
import { test, expect } from '@fixtures/app-test';

test.describe('Applications list', { tag: ['@app', '@alc'] }, () => {
  test('displays Applications page...', async ({ applicationListPage }) => {
    await applicationListPage.goto();
    await expect(applicationListPage.getPageTitle()).toBeVisible();
  });
});
```

---

## Verify Before Assuming

Always `Glob`/`ls` before importing to confirm exact filenames. The following exist:

- `src/constants/fg-rbac.ts`, `fleet-virt.ts`, `governance.ts`, `search.ts`
- `src/pages/fg-rbac/*`, `fleet-virt/*`, `governance/*`, `search/*`, `infrastructure/*`, `overview/*`
- `src/fixtures/fg-rbac-test.ts`, `fleet-virt-test.ts`, `governance-test.ts`, `search-test.ts`
- `src/lib/fg-rbac/`, `src/lib/governance/`, `src/lib/placement/`
- `src/templates/fg-rbac/`, `src/templates/governance/`, `src/templates/app/`

---

## Dependencies

`@playwright/test` ^1.58.2, `typescript` ^5.9.3, `dotenv` ^17.2.3, Node >=20.

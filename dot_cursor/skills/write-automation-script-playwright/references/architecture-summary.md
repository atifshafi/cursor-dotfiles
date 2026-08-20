# Console-E2E Architecture Summary

Agent-optimized reference for `stolostron/console-e2e` (Domain-Driven Hybrid Playwright E2E).

**Verified against:** `main` branch, July 2026.
**Local clone:** `/Users/ashafi/Documents/work/automation/qe-automation-repos/console-e2e`
**Human-readable diagram:** `~/Documents/work/automation/documentation/architecture/Console-E2E-Architecture.html`

---

## Repo Stats

- **245** TypeScript files under `src/`
- **9** Playwright projects: `setup`, `rbac-setup`, `cluster`, `governance`, `search`, `alc`, `fg-rbac`, `fleet-virt`, `unit`
- **Tech:** `@playwright/test` ^1.58.2, TypeScript ^5.9.3, dotenv ^17.2.3, Node >=20

---

## Layer Architecture

| Layer | Directory | Purpose | Imports From | Imported By |
|-------|-----------|---------|--------------|-------------|
| Config | `src/config/` | Env vars, presets, typed getters, spec data loader | nothing (leaf) | fixtures, services, tests, lib |
| Constants | `src/constants/` | Routes, selectors, text labels, wizard config | nothing (leaf) | pages, components, tests, fixtures, lib |
| Services | `src/services/` | Backend CLI ops (no Playwright) | config, constants, utils | fixtures, lib, tests (hooks only) |
| Utils | `src/utils/` | Stateless leaf functions, no domain logic | nothing (leaf) | pages, components, lib |
| Components | `src/components/` | Reusable UI widgets (tables, modals, dialogs) | constants | pages, fixtures |
| Pages | `src/pages/` | Full views with URL routes, extend BasePage | constants, components, services | fixtures |
| Lib | `src/lib/` | Shared multi-step test logic (UI flows, backend polls, data builders) | config, services, pages, utils | fixtures, tests, lib (cross-area) |
| Fixtures | `src/fixtures/` | DI wiring, extends `test` | services, pages, components, config, lib | tests only |
| Tests | `src/tests/` | Specs, `test.step()`, assertions | fixtures only | nothing |
| Templates | `src/templates/` | Static YAML manifests for cluster resources | nothing | services (via path), lib |
| Global Setup | `src/global-setup/` | One-time cluster bootstrap (auth dir, MC data, Ansible, GitOps) | config, services | playwright.config.ts |

---

## File Inventory (As-Built, July 2026)

### Config (`src/config/`)

**Tier 1 — Environment/Auth:**

| File | Exports | Consumers |
|------|---------|-----------|
| `schema.ts` | `HubAuthConfig`, `RbacUser`, `RbacConfig`, `VirtConfig`, `TestConfig` interfaces | index.ts, fixtures |
| `presets.ts` | `hubAuthPresets`, `rbacPresets` (41 users across 3 tiers: rbac-ui, vm, full) | index.ts |
| `index.ts` | `getHubAuth()`, `getRbacConfig()`, `getRbacUsers(domain?)`, `getVirtConfig()`, `getTestConfig()`, `loadAlcLocalEnvFile()` + re-exports all spec-loader API | auth setup, fixtures, specs |

**Tier 2 — E2E Spec Data Loader:**

| Directory | Purpose |
|-----------|---------|
| `e2e-spec-data/applications/` | YAML scenarios for subscription + argo-push wizards |
| `e2e-spec-data/governance/` | YAML scenarios for policy/policy-set placement preview |
| `e2e-spec-data/cluster/` | YAML scenarios for placement create preview |
| `e2e-spec-loader/` | Engine: YAML parse → Zod validate → domain resolve → typed payloads |
| `e2e-spec-loader/domains/` | 6 domain resolvers: subscription, argo-push, application-expectations, policy, policySet, placement |

**Spec Data Loader API (re-exported from `@config`):**
- `resolveSubscriptionScenarioByTestId(polarionId)` → subscription wizard payload
- `resolveArgoPushScenarioByTestId(polarionId)` → argo-push wizard payload
- `resolvePolicyScenarioByTestId(polarionId)` → policy scenario payload
- `resolvePolicySetScenarioByTestId(polarionId)` → policy-set scenario payload
- `resolvePlacementScenarioByTestId(polarionId)` → placement scenario payload

**When to use spec data loader:** Static wizard inputs that repeat across tests (git repos, branch names, paths, placement configs, expected resources). NOT for dynamic runtime data (node counts, release images, credentials) — those stay as env vars.

---

### Constants (`src/constants/`)

| File | Size | Content | Key Consumers |
|------|------|---------|---------------|
| `selectors.ts` | Small (9 exports) | PF globals (`PF_MASTHEAD`, `PF_SPINNER`, `PF_SKELETON`, `PF_MODAL`) + `SELECTORS` stubs | BasePage, AcmTable, auth.setup |
| `app.ts` | Large (1200 lines) | ALC routes, 3 wizard configs, table columns, filter options, doc URLs, helper functions | app pages, lib/app/*, alc specs |
| `governance.ts` | Medium (366 lines) | GRC routes, wizard steps, table columns, test resource names | gov pages, lib/governance/*, gov specs |
| `fg-rbac.ts` | Medium (300 lines) | RBAC routes, wizard steps, RA table, MCRA resource definition | fg-rbac pages, specs |
| `fleet-virt.ts` | Small (101 lines) | Fleet Virt routes, search, tree view, saved searches | FleetVirtPage, SavedSearches |
| `cluster.ts` | Small (63 lines) | Cluster routes, GPU column, manage columns | ClusterListPage, ClusterTable, gpu specs |
| `search.ts` | Small (60 lines) | Search routes, page labels, details | SearchPage, SearchDetailsPage, search specs |
| `placement.ts` | Small (104 lines) | Placement page routes, details terms, create wizard steps | CreatePlacementWizardPage, PlacementDetailsPage |
| `placement-preview.ts` | Small (70 lines) | Shared preview modal UI (used by Policy, Argo, Placement wizards) | governance.ts, app lib, placement lib |
| `placement-tolerations.ts` | Small (53 lines) | Toleration primitives (keys, form labels, YAML regex) | placement.ts, app.ts, governance.ts |
| `overview.ts` | Small (38 lines) | Overview page routes, card titles | OverviewPage, overview spec |
| `welcome.ts` | Small (44 lines) | Welcome page routes, capability cards | WelcomePage, welcome spec |
| `sampleRepos.ts` | Small (3 lines) | Single git URL constant | — |

**Pattern:** `selectors.ts` owns PF globals only. Each area with 20+ selectors gets its own `{area}.ts` that owns EVERYTHING for that domain (routes + selectors + labels + config). No duplication between files.

---

### Services (`src/services/`)

| File | Methods | Consumers |
|------|---------|-----------|
| `OcCliService.ts` | 39 public methods (see below) | All fixtures, lib helpers, test hooks |
| `ObservabilityService.ts` | 5 methods: `isInstalled`, `getManagedClusters`, `getGrafanaAnnotation`, `removeGrafanaAnnotation`, `restoreGrafanaAnnotation` (composes OcCliService) | acm-test fixture, gpu specs |

**OcCliService method catalog:**

| Category | Methods |
|----------|---------|
| **Core (19)** | `run`, `execArgv`, `applyYaml`, `deleteYaml`, `getConsoleUrl`, `getCurrentUser`, `deleteUserPreference`, `hasResourcesInCluster`, `getNamespacedResourceList`, `deleteSecret`, `deleteNamespace`, `getCurrentContext`, `useContext`, `labelManagedCluster`, `listManagedClusterNamesInClusterSet`, `deleteNamespaceOnManagedClusters`, `ensureManagedClusterSetBinding`, `applyManifestFromStdin`, `deleteManifestFromStdin` |
| **MCRA (5)** | `mcraGetAll`, `mcraDeleteByName`, `mcraGetForUser`, `mcraGetRolesForUser`, `mcraDeleteAllForUser` |
| **Application (4)** | `applicationsAppK8sIoExists`, `applicationSetExists`, `deleteApplicationSet`, `deleteApplicationPlacementsInNamespace` |
| **Placement (4)** | `getPlacementClusterSets`, `getPlacementLabelSelectorValues`, `getPlacementDecisionClusterCount`, `getSubscriptionPlacementRefName` |
| **Policy (4)** | `policyExists`, `policyAddLabels`, `policyRemoveLabels`, `policyGetLabels` |
| **VM (3)** | `vmEnsureTestVM`, `vmIsRunning`, `vmDeleteTestVM` |

---

### Utils (`src/utils/`) — Stateless leaf functions

| File | Exports | Playwright? | Purpose |
|------|---------|-------------|---------|
| `kube-helper.ts` | `generateSafeName(prefix)` | No | Random K8s-safe name (`e2e-a3f8b`) |
| `acm-locators.ts` | `acmToolbarSearchLocator(page)` | Types only | Locator factory for ACM table search input |
| `console-navigation.ts` | `normalizeConsolePathname(path)`, `pageUrlPathnameEquals(page, expected)` | Types only | URL pathname comparison helpers |

**Boundary rule:** `utils/` = stateless, dependency-free, domain-agnostic. Never calls Playwright actions, never imports config or services. If it has domain knowledge or drives browser interactions → it belongs in `lib/`.

---

### Components (`src/components/`)

**Two tiers:**

| Tier | Directory | Pattern | Files |
|------|-----------|---------|-------|
| **PF primitives** | `patternfly/` | Generic PF wrappers, domain-agnostic, reused across 4+ areas | `AcmTable`, `AcmSearchInput`, `ManageColumnsDialog` |
| **Area-specific** | `{area}/` | Domain-aware. Extends AcmTable (when OUIA IDs available) or standalone | `ApplicationsTable`, `GovernanceTable`, `ClusterTable`, `RoleAssignmentsTable`, `AdvancedSearchModal`, `SavedSearches` |

**Key files:**

| File | Constructor | Pattern | Key Methods |
|------|-------------|---------|-------------|
| `patternfly/AcmTable.ts` | `(page)` | Base table | `search`, `getRow`, `verifyRowVisible`, `verifyRowNotVisible`, `verifyEmpty`, `clickRow`, `verifyColumnHeaderVisible` |
| `patternfly/ManageColumnsDialog.ts` | `(page)` | Standalone | `open`, `save`, `checkColumn`, `uncheckColumn`, `restoreDefaultsAndSave` |
| `app/ApplicationsTable.ts` | `(page)` | **extends AcmTable** | `clickCreateApplication`, `openFilter`, `selectFilterOption`, `getRowByName`, `openRowActions` |
| `governance/GovernanceTable.ts` | `(page)` | **extends AcmTable** | `openFilter`, `selectRowByName`, `clickBulkAction`, `openRowActions`, `confirmActionModal` |
| `cluster/ClusterTable.ts` | `(page)` | Standalone (data-label, no OUIA) | `getColumnHeader`, `getColumnValues`, `getPopoverBody` |
| `fg-rbac/RoleAssignmentsTable.ts` | `(page)` | Standalone | `getRowByRole` |
| `fleet-virt/AdvancedSearchModal.ts` | `(page)` | Standalone | `selectCluster`, `selectProject`, `clickSearch` |
| `fleet-virt/SavedSearches.ts` | `(page)` | Standalone | Saved search card interaction |

**Extension rule:** If the upstream table uses OUIA IDs for row identification → extend `AcmTable`. If not (data-label columns, composite IDs) → standalone component.

---

### Pages (`src/pages/`)

All extend `BasePage`. Constructor: `(page: Page, oc?: OcCliService)`.

| Area | Files | Key Pages |
|------|-------|-----------|
| (root) | `BasePage.ts` | Abstract. `waitForLoad()` checks PF_SPINNER + PF_SKELETON. No `goto()`. |
| `app/` | 5 files | `ApplicationListPage`, `ApplicationDetailsPage`, `ArgoPullApplicationCreateWizardPage`, `ArgoPushApplicationCreateWizardPage`, `SubscriptionApplicationCreateWizardPage` |
| `cluster/` | 6 files | `ClusterListPage`, `ClusterNodesPage`, `ClusterSetsPage`, `CreatePlacementWizardPage`, `PlacementDetailsPage`, `PlacementsListPage` |
| `fg-rbac/` | 4 files | `RoleAssignmentWizardPage`, `RoleDetailsPage`, `RolesListPage`, `UserDetailsPage` |
| `fleet-virt/` | 2 files | `FleetVirtPage`, `VmDetailsPage` |
| `governance/` | 10 files | `GovernancePage`, `CreatePolicyWizardPage`, `CreatePolicySetWizardPage`, `PoliciesListPage`, `PolicyDetailsPage`, `PolicySetsListPage`, `PolicySetDetailsPage`, `PolicyTemplateDetailsPage`, `DiscoveredPolicyDetailsPage`, `PlacementDetailsPage` |
| `infrastructure/` | 2 files | `ClusterDetailsPage`, `ClusterSetDetailsPage` (FG-RBAC entry points) |
| `overview/` | 2 files | `OverviewPage`, `WelcomePage` |
| `search/` | 2 files | `SearchPage`, `SearchDetailsPage` |

**Composition:** Pages compose components via `has-a` (e.g., `ClusterListPage` has `AcmTable` + `ClusterTable` + `ManageColumnsDialog`). Some pages don't compose directly — the fixture wires companion components alongside them.

---

### Lib (`src/lib/`) — Shared multi-step test logic

**71 files** organized by area. Three flavors:

| Flavor | Purpose | Example |
|--------|---------|---------|
| **Multi-page UI sequences** | Drives wizard flows, multi-step UI interactions reused across specs | `lib/governance/policy-lifecycle.ts` (wizard fill + submit) |
| **Backend poll/assert helpers** | Combines OcCliService + expect for resource readiness checks | `lib/governance/policy-labels-setup.ts` (ensure labels clean) |
| **Data builders** | Pure data loading, context resolution, ID generation | `lib/cluster/managedClusterContext.ts` (load MC JSON) |

**Directory structure:**

| Path | Files | Purpose |
|------|-------|---------|
| `lib/` (root) | `openshift-login.ts`, `navigation.ts`, `utils.ts`, `index.ts` | Login helper, navigation utils |
| `lib/assertions/` | `oc-resource-list.ts` | Shared assertion utilities |
| `lib/cluster/` | `managedClusterContext.ts`, placement helpers (5 files) | Cluster data loading, placement create/preview/verify |
| `lib/fg-rbac/` | `role-assignment-actions.ts` | RBAC wizard multi-step flows |
| `lib/governance/` | 10 files | Policy lifecycle, labels, preview, CSV, YAML templates, RBAC verification |
| `lib/placement/` | 7 files | Shared placement preview/tolerations logic (used by GRC, ALC, CLC) |
| `lib/app/` | 30+ files in subdirs | ALC-specific: argo, subscription, topology, verify, setup, auth |

**Placement rule:** If it wraps `oc` CLI → `services/`. If it models a single page → `pages/`. If it's a zero-domain pure function → `utils/`. Everything else shared across specs → `lib/{area}/`.

---

### Fixtures (`src/fixtures/`)

| File | Extends | Injects | Used By Project |
|------|---------|---------|-----------------|
| `acm-test.ts` | `@playwright/test` | `oc`, `uniqueName`, `clusterListPage`, `clusterNodesPage`, `placementsListPage`, `createPlacementWizardPage`, `policiesListPage`, `createPolicyWizardPage`, `policySetsListPage`, `createPolicySetWizardPage`, `welcomePage` | `cluster` |
| `app-test.ts` | `@playwright/test` | `oc`, `managedClusterContext`, `applicationListPage`, + wizard pages | `alc` |
| `governance-test.ts` | `@playwright/test` | `oc` (worker-scoped), `governancePage`, `governanceTable`, + 7 more page/component objects | `governance` |
| `search-test.ts` | `@playwright/test` | `oc`, `uniqueName`, `searchPage`, `searchDetailsPage`, `overviewPage` | `search` |
| `rbac-test.ts` | `@playwright/test` | `oc`, `asUser(role)` → `{ page }` from `.auth/{role}.json` | (base for fg-rbac-test) |
| `fg-rbac-test.ts` | **`rbac-test`** | `rbacConfig`, `userDetailsPage`, `roleAssignmentWizardPage`, `rolesListPage`, `roleDetailsPage`, `clusterDetailsPage`, `clusterSetDetailsPage` | `fg-rbac` |
| `fleet-virt-test.ts` | `@playwright/test` | `oc`, `virtConfig`, `fleetVirtPage`, `advancedSearchModal`, `savedSearches` | `fleet-virt` |

**DI pattern:** `base.extend<T>({...})` registers factory functions. Each factory receives dependencies, constructs value, passes to `await use(...)`. Tests destructure what they need.

---

### Templates (`src/templates/`)

| Area | Files | Purpose |
|------|-------|---------|
| `fg-rbac/` | `test-clusterset.yaml`, `empty-clusterset.yaml` | ManagedClusterSet resources for RBAC scope tests |
| `governance/` | 15 files | Policies, placements, bindings, credentials, namespaces for GRC tests |
| `app/` | 3 files | GitOps placement, subscription placement, argo-helm-appset setup |
| `cluster/` | 1 file | Placement preview test setup |

**Application:** `oc.applyYaml(filePath)` in `beforeAll`, `oc.deleteYaml(filePath)` in `afterAll`. For parameterized templates, `yaml-template-utils.ts` does token replacement + `oc.applyManifestFromStdin()`.

---

### Tests (`src/tests/`)

| Area Dir | Project | Fixture | Specs | Pattern |
|----------|---------|---------|-------|---------|
| `auth.setup.ts` | `setup` | `@playwright/test` | 1 | Admin login → `.auth/admin.json` |
| `rbac-auth.setup.ts` | `rbac-setup` | `@playwright/test` | 41 (filtered by RBAC_DOMAIN) | RBAC user login loop → `.auth/{role}.json` |
| `cluster/` | `cluster` | `acm-test` | 6 specs | GPU, placement, manage-columns |
| `app/` | `alc` | `app-test` | 13 specs | Subscription, Argo, filters, topology |
| `governance/` | `governance` | `governance-test` | 12 specs | Policy CRUD, filters, bulk actions, RBAC, Ansible |
| `search/` | `search` | `search-test` | 5 specs | Search page, details, overview, saved, welcome |
| `fg-rbac/` | `fg-rbac` | `fg-rbac-test` | 7 specs | Role assignment (global, cluster, clusterset, edge cases, entry points) |
| `fleet-virt/` | `fleet-virt` | `fleet-virt-test` | 1 spec | Advanced search |
| `unit/` | `unit` | `@playwright/test` | 9 specs | Pure TS utility tests (no browser, no auth) |

**Two spec patterns:**

| Pattern | Structure | When |
|---------|-----------|------|
| **Polarion-mapped** | 1 `test()` → N `test.step('N: ...')` | Test named `RHACM4K-XXXXX: ...`, steps map 1:1 to Polarion |
| **Sanity suite** | N independent `test()` blocks | No Polarion mapping, quick smoke tests |

---

### Global Setup (`src/global-setup/` + `src/global-setup.ts`)

Entry point: `src/global-setup.ts` (Playwright `globalSetup` config option).

**Execution flow:**
1. Clean and recreate `.auth/` directory
2. `clusterPrep.ts` — Run `generate-managed-cluster-data.py` → `.auth/managedClusters.json`, then kubeconfig merge → `.auth/MC_MERGED_kubeconfig`
3. `ansiblePrep.ts` — Bootstrap AAP template (checks operator pods first via `operatorPreflight.ts`)
4. `gitOpsPrep.ts` — Only if `E2E_GITOPS_PREP=1` AND `--project alc`

**Gating:** `projectArgv.ts` parses `--project` CLI args. If all projects are `unit` → skip all cluster/ansible/gitops prep.

**Env var gates:**

| Env Var | Effect |
|---------|--------|
| `E2E_SKIP_MANAGED_CLUSTER_PREP` | Skip MC data generation + kubeconfig merge |
| `E2E_SKIP_MANAGED_KUBECONFIG_MERGE` | Skip only kubeconfig merge step |
| `E2E_SKIP_ANSIBLE_PREP` | Skip Ansible template setup |
| `E2E_SKIP_OPERATOR_PREFLIGHT` | Skip pod-existence checks for AAP + GitOps |
| `E2E_GITOPS_PREP` | Enable GitOps prep (disabled by default) |

---

## Playwright Projects

| Project | testMatch | dependencies | storageState | Notes |
|---------|-----------|--------------|--------------|-------|
| `setup` | `auth.setup.ts` | — | — | Admin login |
| `rbac-setup` | `rbac-auth.setup.ts` | — | — | 41 RBAC user logins |
| `cluster` | `/cluster/` | `['setup']` | `.auth/admin.json` | GPU, placements, columns |
| `governance` | `/governance/` | `['setup']` | `.auth/admin.json` | Policies, policy-sets |
| `search` | `search/**/*.spec.ts` | `['setup']` | `.auth/admin.json` | Search page, saved search |
| `alc` | `app/**/*.spec.ts` | `['setup']` | `.auth/admin.json` | Application lifecycle |
| `fg-rbac` | `/fg-rbac/` | `['setup', 'rbac-setup']` | `.auth/admin.json` | Fine-grained RBAC |
| `fleet-virt` | `/fleet-virt/` | `['setup', 'rbac-setup']` | `.auth/admin.json` | Fleet Virtualization |
| `unit` | `unit/**/*.unit.spec.ts` | `[]` | — | No browser, no auth |

---

## Authentication Flow

1. `global-setup.ts` — wipes `.auth/` directory (fresh every run)
2. `auth.setup.ts` — `openshiftLogin(admin)` → saves `.auth/admin.json`
3. `rbac-auth.setup.ts` — loops `getRbacUsers(RBAC_DOMAIN)` → saves `.auth/{role}.json` per user (skips if `RBAC_TEST_PASSWORD` unset)
4. Test projects load `storageState` from saved JSON — tests start pre-authenticated
5. `rbac-test.ts` `asUser(role)` — creates `BrowserContext` from `.auth/{role}.json` (~50ms, no OAuth)

**Auth file is `admin.json`** (not `user.json`).

---

## Data Flow (test execution order)

1. `playwright.config.ts` selects project
2. `global-setup.ts` cleans `.auth/`, runs cluster prep
3. Setup project runs login → saves cookies
4. Test project loads `storageState` (pre-authenticated)
5. Test imports area fixture (`@fixtures/acm-test`, `@fixtures/governance-test`, etc.)
6. Fixture creates services + pages (lazy DI)
7. `test.beforeAll` creates prerequisites via OcCliService / lib helpers
8. Test destructures only needed fixtures
9. `test.step()` calls page object methods
10. Page object handles `page.goto()` + locators
11. Test asserts with `expect()`
12. `test.afterAll` cleans up resources (`--ignore-not-found`)

---

## File Placement Decision Tree

| Code Type | Destination | Pattern |
|-----------|-------------|---------|
| Navigation, page-level locators | `src/pages/{area}/` | Extend `BasePage`, `goto()` uses constants |
| CLI / backend operations | `src/services/OcCliService.ts` | Domain methods added directly, prefixed by resource type |
| Reusable UI widgets (tables, modals) | `src/components/{area}/` | May extend `AcmTable` (OUIA) or standalone |
| PF primitives (cross-area widgets) | `src/components/patternfly/` | Domain-agnostic, used by 4+ areas |
| Static strings (routes, selectors, labels) | `src/constants/{area}.ts` (20+) or `selectors.ts` (<20) | One authoritative location per selector |
| Shared multi-step test logic | `src/lib/{area}/{helper-name}.ts` | UI flows, backend polls, data builders |
| Stateless pure functions | `src/utils/` | No Playwright interactions, no domain knowledge |
| Configuration (env, auth) | `src/config/` | Interfaces in schema, getters in index |
| Test scenario data (static wizard inputs) | `src/config/e2e-spec-data/{area}/` | YAML fragments + profiles + scenarios |
| DI wiring | `src/fixtures/{area}-test.ts` | Extend `@playwright/test` (or chain on `rbac-test`) |
| Test specs | `src/tests/{area}/` | Import from area fixture |
| YAML templates (static resources) | `src/templates/{area}/` | Applied via `oc.applyYaml(path)` |
| One-time bootstrap modules | `src/global-setup/` | Composed into `global-setup.ts` entry point |
| Unit tests (no browser) | `src/tests/unit/` | Import `@playwright/test` directly, no custom fixture |

---

## Must-Do Rules

1. **Extend BasePage** — all page objects; `super(page)` only (oc on subclass)
2. **Navigation in PO methods** — `page.goto()` only inside page objects; tests call PO methods
3. **Constants in files** — no inline routes/selectors/labels in specs; use `@constants/{area}`
4. **Domain services for CLI** — extract when 2+ tests share same `oc.run()` pattern
5. **Column by header** — `getCellByColumnHeader(row, 'Name')`, never `td.nth(N)`
6. **Fixtures for DI** — import `test` from area fixture, not `@playwright/test`
7. **Cleanup in afterAll** — idempotent (`--ignore-not-found`); Playwright re-runs full test on retry
8. **Path aliases** — `@pages/`, `@services/`, `@fixtures/`, `@lib/`, never relative `../../`
9. **Locator hierarchy** — getByRole > getByLabel > getByPlaceholder > getByText > getByTestId > locator > CSS
10. **Table verify helpers** — `AcmTable.verifyRowVisible/NotVisible/Empty` allowed (ESLint whitelist)
11. **Lib for shared logic** — multi-step flows, poll helpers, data builders go in `src/lib/{area}/`
12. **Utils for leaf functions** — stateless, domain-agnostic, no browser interactions

---

## Anti-Patterns (Forbidden)

| Pattern | Why | Instead |
|---------|-----|---------|
| `page.goto()` in specs | URLs change; centralizing in POs = one update | PO `goto()` or `navigateTo*()` method |
| Raw `oc.run()` in spec body | Wrap in named OcCliService methods | `oc.mcra*()`, `oc.vm*()` etc. |
| Inline constants in specs | Fragile, duplicated | `constants/{area}.ts` |
| `td.nth(N)` | Columns reorder | Header-based resolution |
| `page.waitForTimeout(N)` | Forbidden; causes flakes | `expect().toPass()`, `waitFor()`, `toBeVisible()` |
| `page.reload()` in retry | Tab crash = hard failure | `page.goto(url).catch(() => {})` in PO |
| CSS class selectors for assertions | Internal PF/OCP classes break | Role-based locators |
| `not.toBeVisible()` | Use `toBeHidden()` (ESLint enforced) | `await expect(loc).toBeHidden()` |
| Duplicate PO methods | Extract to component or BasePage | Shared component |
| Selectors/locators in test files | Locators in POs as `private readonly` | Page object accessor methods |
| `test.only` | Breaks CI | Remove before commit |
| `new PageObject(page)` in tests | Use fixtures for DI | Destructure from fixture |
| Browser interaction in services | Services = backend only | Put browser code in `lib/` |
| Separate service class files | Add methods to OcCliService directly | Prefix by resource: `mcra*`, `vm*` |
| Duplicated selectors across files | One authoritative location | Large domain → own `{area}.ts` file |
| `process.env` in tests | Use config layer | `getHubAuth()`, `getRbacUsers()` |
| Relative imports | Breaks refactoring | Path aliases always |
| `.catch(() => false)` + `if` guard on assertions | Silent pass without verifying | `expect().toBeVisible()` or `test.skip()` |
| Inline YAML in specs (`oc apply -f - <<'EOF'`) | Untestable, unreviewable | `src/templates/{area}/` + `oc.applyYaml(path)` |

---

## Environment Variables

| Variable | Required | Purpose |
|----------|----------|---------|
| `HUB_URL` | Yes | Hub console URL (auto-derived from `oc get route`) |
| `HUB_PASSWORD` | Yes | Hub login password |
| `CONSOLE_USERNAME` | No | Override admin username (default: kubeadmin) |
| `CONSOLE_IDP` | No | Override IDP (default: kube:admin) |
| `RBAC_TEST_PASSWORD` | For RBAC | Password for clc-e2e-* test users |
| `RBAC_IDP` | No | Override RBAC IDP (default: clc-e2e-htpasswd) |
| `RBAC_DOMAIN` | No | Filter users by domain in getRbacUsers() |
| `VIRT_SPOKE_CLUSTER` | For Fleet Virt | Spoke cluster name for virtualization tests |

---

## Path Aliases (tsconfig.json)

| Alias | Maps To |
|-------|---------|
| `@config` / `@config/*` | `src/config/` |
| `@constants/*` | `src/constants/*` |
| `@services/*` | `src/services/*` |
| `@components/*` | `src/components/*` |
| `@pages/*` | `src/pages/*` |
| `@utils/*` | `src/utils/*` |
| `@fixtures/*` | `src/fixtures/*` |
| `@lib/*` | `src/lib/*` |
| `@tests/*` | `src/tests/*` |

---

## Playwright Config (key settings)

```
timeout: 60_000
expect.timeout: 15_000
fullyParallel: true
retries: CI ? 2 : 0
workers: CI ? 1 : undefined
globalSetup: src/global-setup.ts
reporter: html
trace: on-first-retry
```

---

## CI Integration (Jenkins)

- **Jenkins files:** `acmqe/auto-test` repo → `ci/component/console/`
- **Pipeline stages:** Clone repo → Run tests (`start.sh` router) → Post-actions (XML conversion + archive)
- **`start.sh`:** Router for component areas and test types (integration, post-publishing)
- **Polarion push:** Separate job converts Playwright XML → Cypress-compatible format → pushes to Polarion
- **Must branch from `main`** for Jenkins runs (forks not supported)
- **Common Groovy functions** in shared directory within auto-test repo

---

## Linting

Run `npm run lint:fix` then `npm run lint:check` before Phase 4. Covers Prettier (all file types) + ESLint + TypeScript.

ESLint `playwright/expect-expect` allows: `verifyRowVisible`, `verifyRowNotVisible`, `verifyEmpty`.
`toBeHidden()` preferred over `not.toBeVisible()`.

---

## Keeping This File Current

This file is the **agent-facing architecture reference** for the Playwright automation skill. Update it when the repo structure changes (new areas, new services, new patterns). Source of truth: the live repo (`Glob`/`ls` before assuming files exist).

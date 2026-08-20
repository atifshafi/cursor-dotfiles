# clc-ui-e2e Repo Conventions

Reference for `stolostron/clc-ui-e2e` structure, naming, and conventions.

---

## Directory Structure

```
clc-ui-e2e/
  cypress/
    tests/          # Spec files organized by feature area
    views/          # Page objects and selectors
    apis/           # API helper functions (cy.request wrappers)
    support/        # Commands, constants, e2e setup
    config/         # YAML config loaders (options.yaml, config-e2e.yaml)
    fixtures/       # Test data (JSON, YAML, JS)
    plugins/        # Cypress plugins (env injection, cy-grep, fail-fast)
    scripts/        # Transform utilities
  build/            # Setup scripts (RBAC users, LDAP, hypershift)
  resources/        # YAML templates
  cypress.config.js # Root Cypress config
  options-template.yaml  # Options template (copy to options.yaml)
  start-tests.sh    # Main test driver (stages: create, e2e, destroy)
```

---

## Test Organization (cypress/tests/)

Tests are grouped by area:

| Directory | Area | Examples |
|-----------|------|----------|
| `clusters/managedClusters/create/` | Cluster creation | `createClusters.spec.js`, `importClusters.spec.js` |
| `clusters/managedClusters/destroy/` | Cluster teardown | `destroyClusters.spec.js`, `detachClusters.spec.js` |
| `clusters/managedClusters/` | Cluster actions | `clusterAction.spec.js`, `clusterAddons.spec.js` |
| `clusterset/` | Cluster sets | `clusterSet_action.spec.js`, `clusterSet_rbac.spec.js` |
| `credentials/` | Credentials | `addCredentials.spec.js`, `editCredentials.spec.js` |
| `rbac/` | RBAC (non-virt) | `managedCluster_rbac.spec.js`, `credential_rbac.spec.js` |
| `rbac/virtualization/` | Fleet Virt RBAC | `virt_roleAssignment.spec.js`, `virt_treeView.spec.js` |
| `rbac/virtualization/helpers/` | Virt test helpers | `roleAssignment.js`, `fleetVirtualization.js` |
| `automation/` | Ansible automation | `automation_action.spec.js` |
| `advancedSearch/` | Advanced search | `advancedSearch.spec.js` |
| `hostedClusters/` | Hosted clusters | `awsHostedCluster.spec.js` |
| `ecosystem/centrallyManagedClusters/` | CIM/AI | `createClusterFromInfraEnv.spec.js` |
| `tech-preview/clusterpools/` | Cluster pools | `clusterpools_create.spec.js` |
| `console/feedbackMechanism/` | Console UI | `feedbackMechanism.spec.js` |

**For new areas** (ALC, GRC, Observability, etc.): create `cypress/tests/{area}/` following the same pattern.

---

## View Organization (cypress/views/)

| Directory | Type | Purpose | Files |
|-----------|------|---------|-------|
| `common/` | Shared | Reusable selectors and page methods used across all views | `commonSelectors.js`, `search.js`, `popup.js`, etc. |
| `actions/` | **Orchestration** | State setup via API calls -- "ensure resource exists" pattern | `clusterAction.js`, `rbac.js`, `credential.js` |
| `clusters/` | Page object | Cluster list/detail page selectors and interactions | `managedCluster.js`, `centrallyManagedClusters.js` |
| `clusterset/` | Page object | Cluster set page selectors and interactions | `clusterset.js`, `clusterset_usermanage.js` |
| `credentials/` | Page object | Credential page selectors and interactions | `credentials.js` |
| `virtualization/` | Page object | Fleet Virt page selectors and interactions | `roleAssignmentWizard.js`, `virtualization.js` |
| `automation/` | Page object | Ansible automation page selectors and interactions | `automation.js` |
| Root | Shared | Cross-cutting UI components | `header.js`, `yamlEditor.js` |

### View File Export Pattern

View files export **multiple named objects** grouped by concern -- not just one flat selector object. A complex page may have:

```javascript
// cypress/views/clusters/managedCluster.js

// 1. Selectors object -- all CSS/attribute selectors for the page
export const managedClustersSelectors = { /* ... */ }

// 2. List page methods -- interactions on the cluster list page
export const clustersMethods = {
  clusterShouldExist: (name, access) => { /* ... */ },
  clusterShouldNotExist: (name) => { /* ... */ },
}

// 3. Detail page methods -- interactions on the cluster detail page
export const managedClusterDetailMethods = { /* ... */ }

// 4. Create flow methods -- interactions for cluster creation wizard
export const managedClustersMethods = {
  clickCreate: () => { /* ... */ },
  fillClusterDetails: (cred, name, set) => { /* ... */ },
}

// 5. Validation helpers
export const managedClustersUIValidations = { /* ... */ }
```

**Rule:** Group methods by concern (list vs detail vs create). Export multiple small objects rather than one giant object.

---

## Actions Layer (cypress/views/actions/)

The actions layer is a **distinct orchestration tier** that sits between API wrappers and spec files. It does NOT map to a UI page -- instead, it provides **idempotent state setup** by calling APIs.

**When to use:**
- Test needs RBAC bindings, cluster sets, or resources created before UI interaction
- Setup must be idempotent (safe to run multiple times, e.g., on retry)
- Multiple spec files need the same setup logic

**When NOT to use:**
- Pure UI interaction -- that belongs in `views/{area}/`
- Single-use cleanup -- that can go in the view file's cleanup helpers

**Key pattern -- "Ensure State":**

```javascript
// cypress/views/actions/rbac.js
import * as rbac from '../../apis/rbac'

export const rbacActions = {
  // Check if resource exists, create only if missing (idempotent)
  shouldHaveClusterRolebindingForUser: (bindingName, clusterRole, user) => {
    rbac.getClusterRolebinding(bindingName).then((resp) => {
      if (!resp.isOkStatusCode) {
        const body = { /* ... role binding spec ... */ }
        rbac.createClusterRolebinding(body)
      }
    })
  },
  deleteClusterRolebinding: (bindingName) => {
    rbac.deleteClusterRolebinding(bindingName)
  },
}
```

**Import flow:**
```
Spec file
  └─ imports from views/actions/rbac.js   (orchestration)
       └─ imports from apis/rbac.js        (raw API calls)
```

**Rule:** Actions import from APIs. Specs import from actions. Specs should NOT import directly from APIs for state setup -- use the actions layer.

---

## commonSelectors.js Structure

```javascript
// cypress/views/common/commonSelectors.js
export const commonElementSelectors = {
  elements: {
    combobox: '[role="combobox"]',
    selectMenuItem: '.pf-v6-c-menu__item, .pf-v6-c-select__menu-item',
    dialog: 'div[role="dialog"]',
    tabClass: 'button.pf-v6-c-tabs__link',
    emptyTitle: '.pf-v6-c-empty-state__title-text',
    emptyBody: '.pf-v6-c-empty-state__body',
    xButton: 'button[aria-label="Close"]',
    // ... generic PF6 elements
  },
  elementsText: {
    next: 'Next',
    create: 'Create',
    cancel: 'Cancel',
    // ... shared text constants
  },
  alerts: {
    dangerAlert: '[aria-label="Danger Alert"]',
    alertTitle: '.pf-v6-c-alert__title',
    // ...
  },
}

export const commonPageMethods = {
  resourceTable: { /* rowShouldExist, searchTable, openRowMenu, ... */ },
  modal: { /* shouldBeOpen, clickDanger, confirmAction, ... */ },
  actionMenu: { /* ... */ },
  notification: { /* ... */ },
}
```

**Rule:** Use `commonElementSelectors` for generic PF6 elements. Define component-specific selectors in your view file.

---

## Selector Preference Hierarchy

When choosing selectors for elements, follow this order (highest priority first):

| Priority | Selector Type | Pattern | When to Use |
|----------|--------------|---------|-------------|
| 1 (best) | `data-ouia-component-id` | `tr[data-ouia-component-id="${name}"]` | Table rows, PF components with OUIA IDs. **Configured as testIdAttribute** in `e2e.js`. |
| 2 | `data-label` | `[data-label="Name"]`, `td[data-label="Status"]` | Table column cells. Stable across PF versions. |
| 3 | `data-testid` | `td[data-testid="cluster"]` | Elements with explicit test IDs. |
| 4 | `aria-label` | `input[aria-label="Search input"]` | Accessible form elements, buttons. |
| 5 | ID selectors | `#createCluster`, `#clusterName` | Form inputs, unique page elements. |
| 6 | PF6 classes | `.pf-v6-c-wizard__footer` | PatternFly structural elements (wizard, modal, empty state). |
| 7 (last) | Text-based | `cy.contains('button', 'Next')` | Buttons, menu items. Most resilient to DOM changes but brittle to text changes. |

**Testing Library integration:** `e2e.js` sets `configure({ testIdAttribute: 'data-ouia-component-id' })`, so `findByTestId('clusterName')` maps to `[data-ouia-component-id="clusterName"]`.

**Key custom command:** `cy.getClusterListRow(name)` finds table rows by `data-ouia-component-id` -- always use it for cluster/resource table rows instead of building selectors manually.

---

## Import Conventions

The repo follows consistent import patterns. **Match these exactly** when writing new files:

```javascript
// === In spec files ===

// Named imports for views (pick specific exports by name)
import { clustersMethods, managedClustersSelectors } from '../../views/clusters/managedCluster'
import { rbacActions } from '../../views/actions/rbac'
import { commonPageMethods } from '../../views/common/commonSelectors'

// Namespace imports for APIs (all exports under one name)
import * as cluster from '../../apis/cluster'
import * as rbac from '../../apis/rbac'

// require() for fixtures (JSON/YAML data files)
const clusterSetTestData = require('../../fixtures/clusters/clusterSetTestData')
```

```javascript
// === In view files (e.g., cypress/views/clusters/managedCluster.js) ===

// Named imports for common selectors/methods
import { commonElementSelectors, commonPageMethods } from '../common/commonSelectors'

// Namespace imports for constants (note: 2 levels up from views/{area}/)
import * as constants from '../../support/constants'
```

```javascript
// === In actions files ===

// Namespace imports for API modules
import * as rbac from '../../apis/rbac'
import * as cluster from '../../apis/cluster'

// API modules also export constants (API group, version) used to build request bodies
// Access them via the namespace: rbac.RBAC_API_GROUP, cluster.CLUSTER_API_VERSION
```

**Rules:**
- **Views**: Named imports -- you pick specific selectors/methods
- **APIs**: Namespace imports -- you call `cluster.getManagedCluster()` for functions and `cluster.CLUSTER_API_GROUP` for constants
- **Fixtures**: `require()` -- CommonJS for JSON/YAML data
- **Relative paths**: Depth depends on spec location (2-4 levels of `../`)

---

## Tag Conventions

Tags are used by `@bahmutov/cy-grep` for filtering in CI.

**Describe-level tags:**
```javascript
describe('Test Name', {
  tags: ['@CLC', '@e2e', '@rbac', '@virtualization'],
  retries: { runMode: 1, openMode: 0 },
}, () => { ... })
```

**It-level tags:**
```javascript
it('Test description', { tags: ['@RHACM4K-61736'] }, function () { ... })
```

| Tag | When to Use |
|-----|-------------|
| `@CLC` | Always (repo identifier) |
| `@e2e` | E2E tests (most tests) |
| `@create` | Cluster creation tests |
| `@destroy` | Cluster teardown tests |
| `@rbac` | RBAC-related tests |
| `@virtualization` | Fleet Virtualization tests |
| `@roleassignment` | Role assignment wizard tests |
| `@clusterset` | Cluster set tests |
| `@clusteractions` | Cluster action tests |
| `@RHACM4K-XXXXX` | Polarion test case ID (on `it()`) |

---

## Environment Variables

### Required Exports (consumed by Cypress runtime)

| Variable | Maps To | Used By | Required? |
|----------|---------|---------|-----------|
| `CYPRESS_BASE_URL` | `Cypress.config('baseUrl')` | `cy.visit()`, derives `authUrl` and `ocpUrl` in `constants.js` | Always |
| `CYPRESS_OPTIONS_HUB_USER` | `Cypress.env('OPTIONS_HUB_USER')` | `loginViaAPI()` OAuth fallback, `acquireToken()`, `cy.login()` fallback | Always |
| `CYPRESS_OPTIONS_HUB_PASSWORD` | `Cypress.env('OPTIONS_HUB_PASSWORD')` | `loginViaAPI()` OAuth fallback, `acquireToken()`, `cy.login()` fallback | Always |
| `CYPRESS_HUB_API_URL` | `Cypress.env('HUB_API_URL')` | API cleanup helpers: `deleteMCRAForUser()`, `cleanupOrphanedPlacements()`, `constants.apiUrl` | When test has API cleanup |
| `CYPRESS_CLC_OC_IDP` | `Cypress.env('CLC_OC_IDP')` | RBAC test user IDP selection during login | RBAC tests |
| `CYPRESS_CLC_RBAC_PASS` | `Cypress.env('CLC_RBAC_PASS')` | Password for all `clc-e2e-*` test users | RBAC tests |
| `CYPRESS_VIRT_SPOKE_CLUSTER` | `Cypress.env('VIRT_SPOKE_CLUSTER')` | Test guard via `this.skip()` + spoke cluster name in test data | Virt/Fleet tests |
| `CYPRESS_OC_IDP` | `Cypress.env('OC_IDP')` | `cy.login()` IDP selection (default: `kube:admin` in cypress.config.js) | Rarely needed |

### NOT Used by Cypress (build scripts only)

These variables are used by `build/gen-rbac.sh`, `build/gen-ldap.sh` etc., **NOT** by Cypress tests:

| Variable | Used By |
|----------|---------|
| `CYPRESS_OC_CLUSTER_URL` | `build/` shell scripts for `oc login` |
| `CYPRESS_OC_CLUSTER_USER` | `build/` shell scripts for `oc login` |
| `CYPRESS_OC_CLUSTER_PASS` | `build/` shell scripts for `oc login` |

### Runtime Variables (set programmatically)

| Variable | Set By | Usage |
|----------|--------|-------|
| `Cypress.env('token')` | `cy.setAPIToken()` via `acquireToken()` | Bearer token for `cy.request()` API calls |
| `Cypress.env('ENV_CONFIG')` | Plugin from `options.yaml` | Full test config as JSON string |

### Login Mechanism (`loginViaAPI`)

The `cy.loginViaAPI()` command follows this flow:
1. **First:** Runs `oc whoami -t` -- if the local shell has an active `oc login` session, uses that token directly
2. **Fallback:** If `oc whoami -t` fails, uses `OPTIONS_HUB_USER` + `OPTIONS_HUB_PASSWORD` for OAuth token
3. Sets cookies `acm-access-token-cookie` and `openshift-session-token`
4. Visits the console and verifies the User Menu is visible

**Critical:** You MUST `oc login` to the hub cluster BEFORE running Cypress for `oc whoami -t` to work.

---

## Custom Cypress Commands (cypress/support/commands.js)

| Command | Purpose |
|---------|---------|
| `cy.loginViaAPI()` | Login via OAuth, sets `Cypress.env('token')` |
| `cy.setAPIToken()` | Acquire token via OAuth flow |
| `cy.login(user, password, idp)` | UI login with session caching |
| `cy.clearOCMCookies()` | Clear auth cookies |
| `cy.runCmd(cmd)` | `cy.exec` wrapper |
| `cy.getClusterListRow(name)` | Find cluster/resource row by `data-ouia-component-id` |
| `cy.openActionsMenu()` | Click table actions dropdown |

**Key command -- `cy.getClusterListRow(name)`:**

This is the most-used custom command for table interactions. It:
1. Searches the table (types into search input if available)
2. Finds the row by `data-ouia-component-id="${name}"`
3. Returns the row element with configurable timeout

```javascript
// Use for ANY resource table row (clusters, cluster sets, credentials, etc.)
cy.getClusterListRow('my-cluster').should('exist').and('be.visible')
cy.getClusterListRow('my-cluster').find('[data-label="Status"]').should('contain', 'Ready')
```

**Rule:** Always use `cy.getClusterListRow()` for table row assertions instead of building `tr[data-ouia-component-id=...]` selectors manually.

---

## genericFunctions.js Utilities (cypress/support/genericFunctions.js)

Reusable utility functions. **Always check these before writing new helpers** -- many common patterns are already implemented:

| Function | Purpose | Usage |
|----------|---------|-------|
| `recurse(fn, predicate, maxIterations, interval)` | Polling helper -- calls `fn` repeatedly until `predicate` is true | API readiness checks, resource creation wait |
| `selectOrTypeInInputDropDown(divId, value, typeText)` | Select or type in a PF dropdown | Pass `typeText=true` to type instead of click-select |
| `checkIfElementExistsByText(text)` | Check if an element with given text exists in DOM | Returns `cy.wrap(boolean)` for conditional logic |
| `isEmptyPage(emptyText)` | Check if the page shows empty state | Useful for verifying "no resources" state |
| `clickNext()` | Click the "Next" button | Wizard navigation shorthand |

**Example -- polling with `recurse`:**
```javascript
import { genericFunctions } from '../../support/genericFunctions'

// Poll API until cluster is ready (max 30 attempts, 10s apart)
genericFunctions.recurse(
  () => cluster.getManagedCluster(clusterName),
  (resp) => resp.body?.status?.conditions?.some(c => c.type === 'ManagedClusterConditionAvailable'),
  30,
  10000
)
```

**Rule:** Use `recurse()` for API polling, `cy.waitUntil()` for UI conditions.

---

## constants.js API Paths (cypress/support/constants.js)

Centralized URL and path constants. **Never hardcode API paths** -- always reference `constants`:

| Constant | Value | Used For |
|----------|-------|----------|
| `apiUrl` | Derived from `HUB_API_URL` env var | Base URL for all `cy.request()` API calls |
| `ocm_cluster_api_v1_path` | `/apis/cluster.open-cluster-management.io/v1` | ManagedCluster operations |
| `rbac_api_path` | `/apis/rbac.authorization.k8s.io/v1` | ClusterRoleBindings, RoleBindings |
| `managedclustersPath` | `/multicloud/infrastructure/clusters/managed` | Cluster list page navigation |
| `authUrl` | Derived from `CYPRESS_BASE_URL` | OAuth login URL |
| `ocpUrl` | Derived from `CYPRESS_BASE_URL` | OpenShift console base URL |

**Usage in cleanup helpers:**
```javascript
import * as constants from '../support/constants'

// CORRECT: Use constants for API path
cy.request({
  url: constants.apiUrl + constants.rbac_api_path + '/clusterrolebindings/' + name,
  // ...
})

// WRONG: Hardcoded path
cy.request({
  url: `${api}/apis/rbac.authorization.k8s.io/v1/clusterrolebindings/${name}`,
  // ...
})
```

**Rule:** For new API paths, verify the correct path via `acm-source` MCP, then add them directly to `constants.js` (preferred) so all files can import them consistently. Only use local constants if the path is truly single-use. Always reference `constants.apiUrl` for the base URL.

---

## Support Setup (cypress/support/e2e.js)

Key configurations:
- **Testing Library:** `data-ouia-component-id` as custom test ID attribute
- **PF6 overrides:** Custom Chai assertions for `be.enabled`/`be.disabled` handling `pf-m-aria-disabled` and `aria-disabled`
- **cy-grep:** Tag-based test filtering via `@bahmutov/cy-grep`
- **Uncaught exceptions:** Swallowed (`return false`) to prevent flaky failures
- **fail-fast:** Optional, controlled by `FAIL_FAST` env var

---

## Test User Naming

Test users follow the `clc-e2e-*` prefix convention:

```
clc-e2e-admin-cluster    # Cluster admin
clc-e2e-admin-ns         # Namespace admin
clc-e2e-view             # View-only user
clc-e2e-edit-test        # Edit test user
clc-e2e-operator         # Operator (group-based)
clc-e2e-edgecase-*       # Edge case test users
```

Users are created by `build/gen-rbac.sh` with IDP `clc-e2e-htpasswd` and password `test-RBAC-4-e2e`.

**Important:** `build/` changes go on a separate branch. Never modify `build/` in a test script branch.

---

## Configuration Files

| File | Purpose | Gitignored? |
|------|---------|-------------|
| `options-template.yaml` | Template for test config | No |
| `options.yaml` | Active test config (from template) | Yes |
| `cypress/config/config-e2e-template.yaml` | Cluster connection template | No |
| `cypress/config/config-e2e.yaml` | Active cluster connection | Yes |
| `cypress.config.js` | Cypress settings (timeouts, viewport, reporters) | No |

---

## Key Cypress Config Settings

```javascript
// cypress.config.js
{
  chromeWebSecurity: false,
  defaultCommandTimeout: 30000,
  pageLoadTimeout: 90000,
  viewportWidth: 1680,
  viewportHeight: 1050,
  retries: 2,
  testIsolation: false,  // Tests share state within a spec
  specPattern: ['cypress/tests/**/*.{spec,cy}.js'],
}
```

---

## TEST_STAGE Filtering

`start-tests.sh` uses `TEST_STAGE` to filter which specs run:

| Stage | Runs |
|-------|------|
| `create` | Cluster creation specs |
| `e2e` | Main E2E specs |
| `e2e-virt` | Fleet Virtualization specs |
| `destroy` | Cluster teardown specs |
| `postUpgrade` | Post-upgrade validation |
| `postRestore` | Post-restore validation |

Tags and `grepTags` in CI config control filtering.

---

## Spec File Naming

| Pattern | Example |
|---------|---------|
| Feature spec | `virt_commonProjects.spec.js` |
| Action spec | `clusterAction.spec.js` |
| CRUD spec | `addCredentials.spec.js` |
| RBAC spec | `managedCluster_rbac.spec.js` |

Convention: `{area}_{feature}.spec.js` or `{feature}.spec.js` depending on the directory depth.

# Code Templates

Annotated templates for Cypress spec files and view (page object) files in the clc-ui-e2e repo.

---

## Spec File Template

```javascript
/** *****************************************************************************
 * Licensed Materials - Property of Red Hat, Inc.
 * Copyright (c) 2026 Red Hat, Inc.
 ****************************************************************************** */

/// <reference types="cypress" />

// --- Named imports for views (pick specific exports) ---
import {
  navigateToFeaturePage,
  performAction,
  verifyResult,
  cleanupResources,
  PAGE_SELECTORS,
} from '../../../views/{area}/{feature}'

// --- Named imports for actions (state setup/teardown) ---
// import { featureActions } from '../../../views/actions/{area}'

// --- Named imports for common selectors/methods ---
// import { commonElementSelectors, commonPageMethods } from '../../../views/common/commonSelectors'

// --- Namespace imports for APIs (all exports under one name) ---
// import * as cluster from '../../../apis/cluster'

// --- require() for fixtures (JSON/YAML data) ---
// const testData = require('../../../fixtures/{area}/{dataFile}')

/**
 * RHACM4K-XXXXX - [Area-X.XX] Feature - Test Name
 *
 * Brief description of what this test validates.
 *
 * Prerequisites:
 * - ACM X.XX with [feature] enabled
 * - [Any other prerequisites]
 */
describe(
  'Feature Area - Test Name',
  {
    // Tags: @CLC always, @e2e for E2E tests, plus area-specific tags
    tags: ['@CLC', '@e2e', '@{area}', '@{feature}'],
    retries: { runMode: 1, openMode: 0 },
  },
  () => {
    // Test-specific constants
    const testUser = 'clc-e2e-{user}'
    const spokeCluster = Cypress.env('VIRT_SPOKE_CLUSTER') // or other env var

    // Data used across steps
    const testData = {
      resourceName: 'test-resource',
      roleName: 'view',
    }

    // === Skip guard: skip entire suite if prerequisites not met ===
    before(function () {
      if (!spokeCluster) {
        this.skip('VIRT_SPOKE_CLUSTER environment variable is not set - skipping test')
      }
    })

    // === beforeEach: runs before EACH attempt (including retries) ===
    beforeEach(function () {
      if (!spokeCluster) {
        this.skip('VIRT_SPOKE_CLUSTER environment variable is not set')
      }

      // Fresh login for every attempt
      cy.loginViaAPI()
      cy.setAPIToken()

      // Clean up resources from prior failed runs
      cleanupResources(testUser)

      // Dismiss any stale wizard/modal from a crashed prior attempt
      // dismissWizardIfOpen()  // if applicable
    })

    // === after: final cleanup ===
    after(function () {
      if (!spokeCluster) return
      cy.loginViaAPI()
      cy.setAPIToken()
      cleanupResources(testUser)
    })

    // === Single it() per test case ===
    it(
      'RHACM4K-XXXXX: Description of what is validated',
      { tags: ['@RHACM4K-XXXXX'] },
      function () {
        // Step 1: Navigate
        cy.log('Step 1: Navigate to feature page')
        navigateToFeaturePage(testUser)

        // Step 2: Perform action
        cy.log('Step 2: Perform the main action')
        performAction(testData)

        // Step 3: Verify result
        cy.log('Step 3: Verify expected outcome')
        verifyResult(testData)

        cy.log('RHACM4K-XXXXX: All steps PASSED')
      }
    )
  }
)
```

**Key patterns:**
- Single `describe()` + single `it()` per Polarion test case
- Tags on both `describe` (area tags) and `it` (Polarion ID)
- `beforeEach` for retry safety (login + cleanup every attempt)
- `this.skip()` for missing prerequisites
- `cy.log('Step N: ...')` for structured test output
- All interaction logic in imported helpers, not inline

---

## View (Page Object) File Template

```javascript
/** *****************************************************************************
 * Licensed Materials - Property of Red Hat, Inc.
 * Copyright (c) 2026 Red Hat, Inc.
 ****************************************************************************** */

/// <reference types="cypress" />

import { commonElementSelectors, commonPageMethods } from '../common/commonSelectors'

// =============================================================
// Selectors (discovered via acm-source MCP, not assumed)
// =============================================================

export const PAGE_SELECTORS = {
  // Page structure
  pageContainer: '.pf-v6-c-page__main-section',

  // Wizard (if applicable)
  wizardContainer: '.pf-v6-c-wizard',
  wizardBody: '.pf-v6-c-wizard__main-body',
  wizardFooter: '.pf-v6-c-wizard__footer',
  primaryButton: 'button.pf-m-primary',

  // Loading
  spinner: '.pf-v6-c-spinner',

  // Feature-specific selectors (from acm-source MCP discovery)
  // featureSelect: '#feature-select',
  // featureTable: 'table[aria-label="Feature Table"]',
}

// =============================================================
// Navigation Helpers
// =============================================================

/**
 * Navigate to the feature page
 * @param {string} identifier - Resource name or user to navigate to
 */
export const navigateToFeaturePage = (identifier) => {
  cy.log(`Navigate to feature page for ${identifier}`)
  cy.visit('/multicloud/path/to/feature', { timeout: 30000 })
  // Wait for page content to load
  cy.get('table tbody tr', { timeout: 60000 }).should('have.length.at.least', 1)
}

// =============================================================
// Interaction Helpers
// =============================================================

/**
 * Perform the main feature action
 * @param {object} data - Test data for the action
 */
export const performAction = (data) => {
  cy.log(`Performing action with: ${JSON.stringify(data)}`)
  // Use text-based matching (more resilient than class selectors)
  cy.contains('button', 'Action Text').should('be.visible').should('be.enabled').click()
}

/**
 * Select an item from an AcmSelect dropdown
 * Use commonElementSelectors.elements.combobox for the toggle
 * Use commonElementSelectors.elements.selectMenuItem for options
 */
export const selectDropdownOption = (selectorId, optionText) => {
  cy.log(`Selecting: ${optionText}`)
  cy.get(`${selectorId}-label`)
    .find(commonElementSelectors.elements.combobox)
    .should('be.visible')
    .click()
  cy.get(commonElementSelectors.elements.selectMenuItem)
    .filter((_, el) => el.textContent.trim().startsWith(optionText))
    .first()
    .should('be.visible')
    .click()
}

// =============================================================
// Verification Helpers
// =============================================================

/**
 * Verify expected outcome
 * @param {object} expected - Expected values
 */
export const verifyResult = (expected) => {
  cy.log('Verifying result')
  // Use waitUntil for async conditions, NOT cy.wait(N)
  cy.waitUntil(
    () => cy.get('body').then(($body) => {
      return $body.find(`tr:contains('${expected.resourceName}')`).length > 0
    }),
    { timeout: 30000, interval: 500, errorMsg: 'Expected resource did not appear' }
  )
}

// =============================================================
// Cleanup Helpers
// =============================================================

/**
 * Clean up test resources via API
 * @param {string} identifier - User or resource name to clean up
 */
export const cleanupResources = (identifier) => {
  cy.log(`Cleaning up resources for: ${identifier}`)
  const token = Cypress.env('token')
  const api = Cypress.env('HUB_API_URL')

  // IMPORTANT: Always use correct API version (verify via acm-source MCP)
  // IMPORTANT: Always use failOnStatusCode: false with explicit status check
  cy.request({
    method: 'GET',
    url: `${api}/apis/{group}/{version}/namespaces/{ns}/{resources}`,
    headers: { Authorization: `Bearer ${token}` },
    failOnStatusCode: false,
  }).then((resp) => {
    if (resp.status !== 200) {
      cy.log(`WARNING: Resource list returned status ${resp.status} -- skipping cleanup`)
      return
    }
    const items = resp.body.items || []
    const matching = items.filter((item) => /* filter logic */ true)
    cy.log(`Found ${matching.length} resource(s) to clean up`)

    matching.forEach((item) => {
      cy.log(`Deleting: ${item.metadata.name}`)
      cy.request({
        method: 'DELETE',
        url: `${api}/apis/{group}/{version}/namespaces/{ns}/{resources}/${item.metadata.name}`,
        headers: { Authorization: `Bearer ${token}` },
        failOnStatusCode: false,
      })
    })
  })
}
```

**Key patterns:**
- Selectors centralized in a named object at the top
- Generic PF6 elements from `commonElementSelectors` (combobox, selectMenuItem, etc.)
- Component-specific selectors in `PAGE_SELECTORS`
- Every helper logs what it does with `cy.log()`
- Cleanup uses `failOnStatusCode: false` with explicit status checks
- `cy.waitUntil()` for async conditions, never `cy.wait(N)`
- JSDoc comments on all exported functions

---

## Actions Layer File Template

Use this when tests need **idempotent state setup** via API calls (RBAC bindings, cluster sets, resources).

```javascript
/** *****************************************************************************
 * Licensed Materials - Property of Red Hat, Inc.
 * Copyright (c) 2026 Red Hat, Inc.
 ****************************************************************************** */

/// <reference types="cypress" />

// Actions import from APIs (namespace import convention)
import * as rbac from '../../apis/rbac'
import * as constants from '../../support/constants'

// =============================================================
// Idempotent State Setup
// =============================================================

export const featureActions = {
  /**
   * Ensure a ClusterRoleBinding exists for the given user.
   * Creates the binding only if it doesn't already exist (idempotent).
   *
   * @param {string} bindingName - Name of the ClusterRoleBinding
   * @param {string} clusterRole - ClusterRole to bind
   * @param {string} userName - User to bind the role to
   */
  shouldHaveClusterRolebindingForUser: (bindingName, clusterRole, userName) => {
    cy.log(`Ensuring ClusterRoleBinding exists: ${bindingName}`)
    rbac.getClusterRolebinding(bindingName).then((resp) => {
      if (!resp.isOkStatusCode) {
        cy.log(`ClusterRoleBinding ${bindingName} not found -- creating`)
        const body = {
          apiVersion: 'rbac.authorization.k8s.io/v1',
          kind: 'ClusterRoleBinding',
          metadata: { name: bindingName },
          roleRef: {
            apiGroup: 'rbac.authorization.k8s.io',
            kind: 'ClusterRole',
            name: clusterRole,
          },
          subjects: [{ apiGroup: 'rbac.authorization.k8s.io', kind: 'User', name: userName }],
        }
        rbac.createClusterRolebinding(body)
      } else {
        cy.log(`ClusterRoleBinding ${bindingName} already exists -- skipping creation`)
      }
    })
  },

  /**
   * Delete a ClusterRoleBinding (cleanup).
   * @param {string} bindingName - Name of the binding to delete
   */
  deleteClusterRolebinding: (bindingName) => {
    cy.log(`Deleting ClusterRoleBinding: ${bindingName}`)
    rbac.deleteClusterRolebinding(bindingName)
  },
}
```

**Key patterns:**
- **Ensure-state pattern**: Check first (`GET`), create only if missing -- safe for retries
- **Namespace imports** for API modules: `import * as rbac from '../../apis/rbac'`
- **Methods object**: Export a single object grouping related setup/teardown
- **cy.log()** on every action for debuggability
- Actions do NOT contain UI interactions -- only API calls
- **Deferred token reads** via `cy.then()` (see below)

**Deferred token pattern (critical):**

Actions are called in `beforeEach` after `cy.setAPIToken()`. Because Cypress commands are asynchronous, `Cypress.env('token')` is `undefined` at definition time. Wrap API calls that need the token in `cy.then()` so the read happens after the token is set:

```javascript
// WRONG -- token is undefined when this line executes
createResourceViaAPI: (name) => {
  const token = Cypress.env('token')  // undefined!
  apiModule.createResource({ /* ... */ })
},

// CORRECT -- token is read after cy.setAPIToken() completes
createResourceViaAPI: (name) => {
  cy.then(() => {
    apiModule.createResource(body).then((resp) => {
      if (resp.status === 201) cy.log(`Resource '${name}' created`)
      else if (resp.status === 409) cy.log(`Resource '${name}' already exists`)
      else cy.log(`WARNING: Create returned status ${resp.status}`)
    })
  })
},
```

This applies to any action that calls an API function which internally reads `Cypress.env('token')`. If the API module reads the token inside `cy.request()` (at execution time), then `cy.then()` is not needed in the action -- but if the action constructs headers or bodies using the token directly, it must defer.

**How specs use actions:**
```javascript
// In spec file
import { featureActions } from '../../views/actions/{area}'

beforeEach(function () {
  cy.loginViaAPI()
  cy.setAPIToken()
  // Idempotent -- safe on retries
  featureActions.shouldHaveClusterRolebindingForUser(bindingName, role, user)
})

after(function () {
  cy.loginViaAPI()
  cy.setAPIToken()
  featureActions.deleteClusterRolebinding(bindingName)
})
```

---

## API File Template

API files live in `cypress/apis/` and provide **pure `cy.request()` wrappers** -- no UI logic, no orchestration. They export CRUD functions and optionally resource constants (API group, version) that the actions layer uses to construct request bodies.

```javascript
/** *****************************************************************************
 * Licensed Materials - Property of Red Hat, Inc.
 * Copyright (c) 2026 Red Hat, Inc.
 ****************************************************************************** */

/// <reference types="cypress" />

import * as constants from '../support/constants'

// Shared headers for all requests
var headers = {
  'Content-Type': 'application/json',
  Accept: 'application/json',
}

// Exported constants -- used by the actions layer to build request bodies
export const RESOURCE_API_GROUP = 'example.open-cluster-management.io'
export const RESOURCE_API_VERSION = 'v1beta1'

/**
 * Build the resource API base URL (private -- not exported).
 * Uses constants from support/constants.js for the base URL and API path.
 * @returns {string} Full URL for the resource in its namespace
 */
const resourceBaseUrl = () => {
  return `${constants.apiUrl}${constants.resource_api_path}/namespaces/${constants.resource_namespace}/resources`
}

// =============================================================
// CRUD Functions
// =============================================================

/**
 * List all resources.
 * @returns {Cypress.Chainable} Response with items array
 */
export const listResources = () => {
  return cy.request({
    method: 'GET',
    url: resourceBaseUrl(),
    headers: { ...headers, Authorization: `Bearer ${Cypress.env('token')}` },
    failOnStatusCode: false,
  })
}

/**
 * Get a specific resource by name.
 * @param {string} name - Resource name
 * @returns {Cypress.Chainable} Response (200 if found, 404 if not)
 */
export const getResource = (name) => {
  return cy.request({
    method: 'GET',
    url: `${resourceBaseUrl()}/${name}`,
    headers: { ...headers, Authorization: `Bearer ${Cypress.env('token')}` },
    failOnStatusCode: false,
  })
}

/**
 * Create a resource from a full body object.
 * The caller (actions layer) constructs the body using exported constants.
 * @param {object} body - Full K8s resource body
 * @returns {Cypress.Chainable} Response (201 created, 409 conflict)
 */
export const createResource = (body) => {
  return cy.request({
    method: 'POST',
    url: resourceBaseUrl(),
    headers: { ...headers, Authorization: `Bearer ${Cypress.env('token')}` },
    body,
    failOnStatusCode: false,
  })
}

/**
 * Delete a resource by name.
 * @param {string} name - Resource name
 * @returns {Cypress.Chainable} Response (200/204 deleted, 404 not found)
 */
export const deleteResource = (name) => {
  return cy.request({
    method: 'DELETE',
    url: `${resourceBaseUrl()}/${name}`,
    headers: { ...headers, Authorization: `Bearer ${Cypress.env('token')}` },
    failOnStatusCode: false,
  })
}

/**
 * Patch a resource by name (strategic merge patch).
 * @param {string} name - Resource name
 * @param {object} patchBody - Partial body to merge
 * @returns {Cypress.Chainable} Response
 */
export const patchResource = (name, patchBody) => {
  return cy.request({
    method: 'PATCH',
    url: `${resourceBaseUrl()}/${name}`,
    headers: {
      ...headers,
      Authorization: `Bearer ${Cypress.env('token')}`,
      'Content-Type': 'application/strategic-merge-patch+json',
    },
    body: patchBody,
    failOnStatusCode: false,
  })
}
```

**Key patterns:**
- **Exported constants** (`RESOURCE_API_GROUP`, `RESOURCE_API_VERSION`) -- actions layer uses these to build full K8s resource bodies without hardcoding API versions
- **Private URL builder** (`resourceBaseUrl()`) -- derives URLs from `constants.apiUrl` + `constants.*_api_path`; not exported since only this module needs it
- **`failOnStatusCode: false`** on every request -- callers handle status codes
- **Token read at execution time** -- `Cypress.env('token')` inside `cy.request()` is fine because `cy.request()` runs asynchronously in the Cypress command queue
- **No orchestration** -- functions are pure wrappers; multi-step logic belongs in the actions layer

**How actions use API files:**
```javascript
// In cypress/views/actions/{area}.js
import * as resourceApi from '../../apis/resource'

export const featureActions = {
  createResourceIfMissing: (name) => {
    resourceApi.getResource(name).then((resp) => {
      if (resp.status === 404) {
        const body = {
          apiVersion: `${resourceApi.RESOURCE_API_GROUP}/${resourceApi.RESOURCE_API_VERSION}`,
          kind: 'Resource',
          metadata: { name },
          // ...spec fields
        }
        resourceApi.createResource(body)
      }
    })
  },
}
```

---

## Multi-Export View File Template

For complex pages, export **multiple method objects** grouped by concern:

```javascript
/** *****************************************************************************
 * Licensed Materials - Property of Red Hat, Inc.
 * Copyright (c) 2026 Red Hat, Inc.
 ****************************************************************************** */

/// <reference types="cypress" />

import { commonElementSelectors, commonPageMethods } from '../common/commonSelectors'
import * as constants from '../../support/constants'

// =============================================================
// Selectors -- organized by page section
// =============================================================

export const featureSelectors = {
  // List page
  listTable: 'table[aria-label="Feature table"]',
  tableColumnFields: {
    name: '[data-label="Name"]',
    status: '[data-label="Status"]',
    type: '[data-label="Type"]',
  },

  // Create/edit form (nested by section for complex forms)
  createForm: {
    basicInfo: {
      nameInput: '#feature-name',
      descriptionInput: '#feature-description',
    },
    advancedOptions: {
      enableToggle: '#enable-advanced',
      configSelect: '#config-select',
    },
  },

  // Detail page
  detailPage: {
    breadcrumb: '.pf-v6-c-breadcrumb',
    tabBar: '.pf-v6-c-tabs',
  },
}

// =============================================================
// List Page Methods (concern: resource table interactions)
// =============================================================

export const featureListMethods = {
  featureShouldExist: (name, accessLevel) => {
    cy.log(`Verifying feature "${name}" exists with access: ${accessLevel}`)
    cy.getClusterListRow(name).should('exist').and('be.visible')
  },

  featureShouldNotExist: (name) => {
    cy.log(`Verifying feature "${name}" does NOT exist`)
    commonPageMethods.resourceTable.searchTable(name)
    cy.get('body').should('not.contain', name)
  },

  openFeatureActions: (name) => {
    cy.log(`Opening actions menu for: ${name}`)
    commonPageMethods.resourceTable.openRowMenu(name)
  },
}

// =============================================================
// Detail Page Methods (concern: detail view interactions)
// =============================================================

export const featureDetailMethods = {
  navigateToDetail: (name) => {
    cy.log(`Navigating to detail page for: ${name}`)
    cy.getClusterListRow(name).find('a').first().click()
    cy.get(featureSelectors.detailPage.breadcrumb, { timeout: 30000 }).should('be.visible')
  },

  selectTab: (tabName) => {
    cy.log(`Selecting tab: ${tabName}`)
    cy.get(featureSelectors.detailPage.tabBar).contains('button', tabName).click()
  },
}

// =============================================================
// Create Flow Methods (concern: creation wizard/form)
// =============================================================

export const featureCreateMethods = {
  fillBasicInfo: (name, description) => {
    cy.log(`Filling basic info: name=${name}`)
    cy.get(featureSelectors.createForm.basicInfo.nameInput).clear().type(name)
    if (description) {
      cy.get(featureSelectors.createForm.basicInfo.descriptionInput).clear().type(description)
    }
  },
}
```

**Key patterns:**
- **Nested selectors** organized by page section (`createForm.basicInfo.nameInput`)
- **Multiple method objects** for different concerns (list, detail, create)
- **Named exports** so specs import only what they need
- **`cy.getClusterListRow()`** for table row interactions (uses OUIA ID internally)
- **`commonPageMethods`** for generic table/modal interactions (don't reinvent)

**When to use flat vs nested selectors:**

| Selector Structure | When to Use | Example |
|--------------------|-------------|---------|
| **Flat** | Simple page with few elements | `{ spinner: '.pf-v6-c-spinner', table: 'table' }` |
| **Nested by section** | Complex page with distinct sections (form, table, detail) | `{ createForm: { basicInfo: { nameInput: '#name' } } }` |
| **Nested by column** | Table column selectors | `{ tableColumnFields: { name: '[data-label="Name"]', status: '[data-label="Status"]' } }` |

---

## Common Patterns

### AcmSelect Dropdown Pattern

Most ACM dropdowns use AcmSelect which renders a FormGroup + MenuToggle:

```javascript
// The select has an ID like #my-select
// The label wrapper has id="${id}-label"
// Inside is a combobox role toggle button
cy.get('#my-select-label')
  .find(commonElementSelectors.elements.combobox)  // [role="combobox"]
  .should('be.visible')
  .click()

// Menu items use PF6 menu item classes
cy.get(commonElementSelectors.elements.selectMenuItem)  // .pf-v6-c-menu__item
  .filter((_, el) => el.textContent.trim().startsWith('Option Text'))
  .first()
  .click()
```

### Table Row Selection Pattern

```javascript
// Use data-ouia-component-id for row identification
cy.get(`tr[data-ouia-component-id='${rowName}']`, { timeout: 10000 })
  .find('input[type="checkbox"]')
  .check({ force: true })
```

### Wizard Navigation Pattern

```javascript
// Click Next -- use text-based matching
cy.contains('button', 'Next').should('be.visible').should('be.enabled').click()

// Wait for step transition
cy.waitUntil(
  () => cy.get(PAGE_SELECTORS.wizardBody, { timeout: 5000 })
    .then(($body) => $body.is(':visible')),
  { timeout: 10000, interval: 300, errorMsg: 'Wizard step transition did not complete' }
)
```

### Wizard Submit Pattern

```javascript
// Use the selectors object -- never hardcode inline
cy.get(PAGE_SELECTORS.wizardFooter)
  .find(PAGE_SELECTORS.primaryButton)
  .scrollIntoView()
  .should('be.visible')
  .should('be.enabled')
  .click()

// Wait for wizard to close (submission completed)
cy.get(PAGE_SELECTORS.wizardContainer, { timeout: 60000 }).should('not.exist')
```

### Dismiss Stale Modal Pattern

```javascript
export const dismissModalIfOpen = () => {
  cy.get('body').then(($body) => {
    if ($body.find(PAGE_SELECTORS.wizardContainer).length > 0) {
      const cancelBtn = $body.find("button:contains('Cancel')")
      if (cancelBtn.length > 0) cy.wrap(cancelBtn.first()).click({ force: true })
    } else if ($body.find(commonElementSelectors.elements.dialog).length > 0) {
      const closeBtn = $body.find(commonElementSelectors.elements.xButton)
      if (closeBtn.length > 0) cy.wrap(closeBtn.first()).click({ force: true })
    }
  })
}
```

### API Cleanup with Status Logging

```javascript
cy.request({
  method: 'GET',
  url: `${api}/apis/{group}/{version}/namespaces/{ns}/{resources}`,
  headers: { Authorization: `Bearer ${token}` },
  failOnStatusCode: false,
}).then((resp) => {
  if (resp.status !== 200) {
    cy.log(`WARNING: List returned status ${resp.status} -- skipping cleanup`)
    return
  }
  const items = resp.body.items || []
  cy.log(`Found ${items.length} item(s)`)
  // ... filter and delete
})
```

**Note:** If this cleanup runs inside an actions helper called from `beforeEach`, ensure `token` is read inside `cy.then()` -- see the [deferred token pattern](#actions-layer-file-template) in the Actions template.

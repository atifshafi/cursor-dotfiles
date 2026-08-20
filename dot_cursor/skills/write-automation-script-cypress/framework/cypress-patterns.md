# Cypress Framework Patterns

Framework-specific patterns, conventions, and gotchas for writing Cypress tests in `stolostron/clc-ui-e2e`.

---

## Async Model

Cypress commands are **enqueued**, not awaited. They run in a deterministic serial order within the Cypress command queue.

```javascript
// These do NOT run top-to-bottom like async/await
cy.get('button').click()    // enqueued
cy.get('table').should(...) // enqueued after click
```

**Consequence:** You cannot use `const value = cy.get(...)` and expect `value` to hold the element. Use `.then()` to access yielded subjects.

```javascript
// WRONG
const text = cy.get('h1').text()

// CORRECT
cy.get('h1').then(($h1) => {
  const text = $h1.text()
})
```

---

## Command Chaining

Cypress chains yield subjects from one command to the next:

```javascript
cy.get('table')
  .find('tr')
  .first()
  .find('td[data-label="Name"]')
  .should('contain', 'my-resource')
```

`.within()` scopes all commands inside to the yielded element:
```javascript
cy.get(WIZARD_SELECTORS.wizardContainer).within(() => {
  cy.get('input').type('value')
  cy.contains('button', 'Submit').click()
})
```

---

## Wait Patterns

| Pattern | Use When |
|---------|----------|
| `cy.waitUntil(() => condition, { timeout, interval, errorMsg })` | Async state changes (API readiness, resource creation, UI transitions) |
| `.should('be.visible')` | Element visibility assertions (auto-retries) |
| `.should('have.length.at.least', N)` | Waiting for table rows to load |
| `cy.get(sel, { timeout: N })` | Increasing default command timeout for slow elements |

**NEVER use:** `cy.wait(N)` -- always replace with condition-based waits.

---

## Selector Strategy

Priority order (from repo conventions):

1. `data-ouia-component-id` -- `tr[data-ouia-component-id="${name}"]` or `cy.getClusterListRow(name)`
2. `data-label` -- `td[data-label="Status"]`
3. `data-testid` -- `td[data-testid="cluster"]`
4. `aria-label` -- `input[aria-label="Search input"]`
5. ID -- `#createCluster`
6. PF6 classes -- `.pf-v6-c-wizard__footer` (structural only)
7. Text-based -- `cy.contains('button', 'Next')` (most resilient to DOM changes)

**Custom command:** `cy.getClusterListRow(name)` -- always use for resource table rows.

---

## Login Patterns

```javascript
// Admin login (uses oc whoami -t internally)
cy.loginViaAPI()
cy.setAPIToken()  // sets Cypress.env('token') for cy.request() calls

// RBAC user login (IDP-based)
cy.login(userName, Cypress.env('CLC_RBAC_PASS'), Cypress.env('CLC_OC_IDP'))
```

---

## Cleanup Patterns

```javascript
// API cleanup with status logging
cy.request({
  method: 'DELETE',
  url: `${constants.apiUrl}${constants.mcra_api_path}/namespaces/${constants.mcra_namespace}/resource/${name}`,
  headers: { Authorization: `Bearer ${Cypress.env('token')}` },
  failOnStatusCode: false,
}).then((resp) => {
  if (resp.status === 200 || resp.status === 204) {
    cy.log(`Deleted: ${name}`)
  } else if (resp.status === 404) {
    cy.log(`Already deleted: ${name}`)
  } else {
    cy.log(`WARNING: Delete returned status ${resp.status}`)
  }
})
```

---

## Deferred Token Pattern

In actions files, token may not be set at definition time. Wrap in `cy.then()`:

```javascript
// WRONG -- token undefined at enqueue time
createResource: (name) => {
  const token = Cypress.env('token')  // undefined!
  api.createResource({ headers: { Authorization: `Bearer ${token}` } })
}

// CORRECT -- token read at execution time
createResource: (name) => {
  cy.then(() => {
    api.createResource(body).then((resp) => { ... })
  })
}
```

---

## PF6 Dropdown Pattern

```javascript
// Open dropdown
cy.get('#select-id-label')
  .find(commonElementSelectors.elements.combobox)
  .should('be.visible')
  .click()

// Select option
cy.get(commonElementSelectors.elements.selectMenuItem)
  .filter((_, el) => el.textContent.trim().startsWith('Option Text'))
  .first()
  .should('be.visible')
  .click()
```

---

## Wizard Navigation

```javascript
cy.contains('button', 'Next').should('be.visible').should('be.enabled').click()

// Wait for step transition
cy.waitUntil(
  () => cy.get(SELECTORS.wizardBody, { timeout: 5000 }).then(($body) => $body.is(':visible')),
  { timeout: 10000, interval: 300, errorMsg: 'Wizard step transition did not complete' }
)
```

---

## Dismiss Stale UI

```javascript
cy.get('body').then(($body) => {
  if ($body.find('.pf-v6-c-wizard').length > 0) {
    const cancelBtn = $body.find("button:contains('Cancel')")
    if (cancelBtn.length > 0) cy.wrap(cancelBtn.first()).click({ force: true })
  }
})
```

# Bug Verification Patterns (ACM)

Decision trees for classifying bugs and choosing verification evidence. Use after JIRA content is parsed and bug type is assigned.

## Bug type taxonomy

| Type | Signals in JIRA | Primary evidence |
|------|-----------------|------------------|
| UI layout | spacing, overlap, zoom, responsive, misaligned | Playwright screenshots at multiple viewports |
| UI functional | button does nothing, wrong navigation, stale data | Repro steps + UI assertions |
| Backend / API | 500, wrong payload, proxy error | `browser_evaluate` fetch + optional `oc exec` code grep |
| RBAC / auth | wrong visibility, forbidden, wrong role | Login as specific user; `oc auth can-i` |
| Data / query | wrong count, missing row, search | CLI/API + UI cross-check |

---

## UI layout bugs

1. Confirm fix is in build (Phase 2) before screenshots.
2. Navigate to exact URL from repro or component map.
3. Capture **three** viewport widths (e.g. 1280, 1440, 1920) or add mobile if repro mentions it.
4. If repro mentions **zoom**, use browser zoom (evaluate or devtools) at 67%, 100%, 125%, 150%.
5. Compare against **expected** from JIRA; note any secondary visual issues separately (do not conflate with primary verdict).
6. Evidence: attach snapshots + short description of each.

**Pass**: layout matches expected; **Fail**: original defect visible; **Blocked**: cannot reach page (prereq).

---

## UI functional bugs

1. Execute steps verbatim; do not skip "obvious" steps.
2. Use **Playwright MCP** only for browser (not cursor-ide-browser).
3. After each step, `browser_snapshot` if wait/click is ambiguous.
4. Assert on accessible name / role / `data-test` when available (prefer stable selectors).
5. If multi-cluster: confirm which cluster context the UI is showing.

**Pass**: expected behavior; **Fail**: actual matches old bug; **Blocked**: missing data or permission.

---

## Backend / API bugs

1. Identify service: console pod proxy, search API, managed cluster proxy, etc.
2. Prefer **in-browser** `fetch` via Playwright `browser_evaluate` so cookies and CSRF apply.
3. Extract CSRF: read `document.cookie` for `csrf-token`, send header `X-CSRFToken`.
4. If repro is about **error body** vs status line: capture full response text/JSON in evidence.
5. **Code-level confirmation**: `oc exec` into relevant pod, `grep` for distinctive string from fix PR (compiled JS is acceptable evidence when UI trigger is hard).

**Pass**: response shape/message matches fix; **Fail**: old behavior; **Blocked**: cannot authenticate to API.

---

## RBAC / FG-RBAC bugs

1. List required identities: cluster-admin vs namespace-scoped vs MCRA-bound user.
2. Confirm IDP exists (`oc get oauth`, identity providers).
3. Log in through Playwright with the **affected** user, not only admin.
4. Use `oc auth can-i --as=system:serviceaccount:...` only when repro is API-focused; UI bugs need UI session.

**Pass**: visibility/access matches expected; **Fail**: old wrong access; **Blocked**: no test user / MCRA (Phase 2.5 gap).

---

## Data / query bugs

1. Reproduce with same filters/labels/namespace as JIRA.
2. `oc get` / Search DB / UI table — triangulate; mismatches are evidence.
3. For multi-cluster, confirm hub vs spoke and which informer backs the UI.

---

## Verdict rules (strict)

- **FIXED**: fix in build **and** verification passes with evidence.
- **NOT FIXED**: fix in build **and** defect still reproducible (include evidence).
- **BLOCKED**: fix **not** in build (wrong branch, no cherry-pick), or environment cannot satisfy prereqs, or external dependency (cloud creds) missing — do **not** call this "not fixed"; separate blocker section.

Never upgrade verdict from BLOCKED to FIXED without re-running Phase 2 and Phase 3.

---

## Test resources (when creation is unavoidable)

- Policies: `remediationAction: Inform` only unless repro requires enforce.
- Cluster pools: `size: 0` when only UI layout needs a pool object.
- Names: prefix `bug-verify-` + ticket key suffix; namespace from user or default policy namespace.
- Always get **explicit user approval** before `oc apply` / `oc create` / `oc patch` / `oc delete`.

---

## Cleanup checklist

After verification, if resources were created with approval:

- [ ] Delete test policies / placements / bindings
- [ ] Delete test cluster pools / claims (if any)
- [ ] Remove temporary files (`/tmp/*auth.json`, kubeconfig copies if created)

Document what was cleaned in JIRA draft comment if relevant.

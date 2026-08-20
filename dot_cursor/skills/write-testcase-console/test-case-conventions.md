# Test Case Conventions

Conventions extracted from 85 existing test cases in `documentation/acm-components/virt/test-cases/`.

---

## File Location and Naming

**Base path:** `/Users/ashafi/Documents/work/automation/documentation/acm-components/virt/test-cases/{version}/`

**Naming:** `RHACM4K-{ID}-{Feature-Description}.md`

Examples:
- `RHACM4K-61726-RBAC-UI-GlobalAccess.md`
- `RHACM4K-59217-SINGLE-VM-LIVE-MIGRATION.md`
- `RHACM4K-60558-Fleet-Virt-TreeView-Toggle-Button.md`

**Organization:** Flat within version directories (no subdirectories). Versions: `2.15/`, `2.16/`, `2.17/` etc.

---

## Document Structure

Every test case follows this section order:

### 1. Title (H1)

```markdown
# RHACM4K-XXXXX - [Tag-Version] Area - Test Name
```

Title patterns by area:

| Area | Pattern |
|------|---------|
| RBAC | `[FG-RBAC-X.XX] RBAC UI - Feature` |
| Fleet Virt | `[FG-RBAC-X.XX] Fleet Virtualization UI - Feature` |
| CCLM | `[FG-RBAC-X.XX] CCLM - Feature` |
| MTV | `[MTV-X.XX] MTV - Feature` |
| Search | `[FG-RBAC-X.XX] Search - Feature` |
| Clusters | `[Clusters-X.XX] Feature` |
| Applications | `[Apps-X.XX] Feature` |
| Governance | `[GRC-X.XX] Feature` |
| Credentials | `[Credentials-X.XX] Feature` |

### Component Mapping (Polarion metadata)

| Area | Polarion Component | Polarion Subcomponent |
|------|-------------------|---------------------|
| RBAC | Virtualization | RBAC |
| Fleet Virtualization | Virtualization | Fleet Virtualization |
| CCLM | Virtualization | CCLM |
| MTV | Virtualization | MTV |
| Search | Search | Search |
| Clusters | Cluster Lifecycle | Clusters |
| Applications | Application Lifecycle | Applications |
| Credentials | Cluster Lifecycle | Credentials |
| Governance | Governance | Discovered Policies |

Replace `X.XX` with ACM version from JIRA `fix_versions`.

### 2. Metadata Block

```markdown
**Polarion ID:** RHACM4K-XXXXX
**Status:** Draft | proposed
**Created:** YYYY-MM-DD
**Updated:** YYYY-MM-DD
```

### 3. Polarion Fields (H2 lines)

```markdown
## Type: Test Case
## Level: System
## Component: Virtualization | Cluster Lifecycle | ...
## Subcomponent: RBAC | Fleet Virtualization | CCLM | ...
## Test Type: Functional
## Pos/Neg: Positive | Negative
## Importance: High | Medium | Low
## Automation: Not Automated | Automated
## Tags: ui, rbac, mcra, ...
## Release: 2.16
```

### 4. Description

What the test validates. Include:
- Feature being tested (1-2 paragraphs)
- Numbered list of what is verified
- **Entry Point** (discovered via MCP, not assumed)
- **Dev JIRA Coverage** with primary and secondary tickets

### 5. Setup

- **Prerequisites** (ACM version, CNV, RBAC, cluster-admin, etc.)
- **Test Environment** -- describe requirements generically, NOT with specific cluster details
- **Setup Commands** (numbered bash steps with expected output)

**IMPORTANT -- No Specific Cluster Information in Test Cases:**
Do NOT include specific cluster names, console URLs, or environment-specific details in the Setup section. Test cases should be reusable across any environment. Instead:
- State requirements generically: "At least one managed cluster with CNV installed" (not "sno-2-xsr74")
- Use placeholders for URLs: `<hub-console-url>`, `<hub-api>`, `<spoke-kubeconfig>` (not actual URLs)
- Describe IDP needs: "An htpasswd IDP with test users" (not "acm33094-htpasswd on cluster X")
- Cluster-specific details belong ONLY in the local markdown Notes/Investigation Trail section (not in Polarion)

Setup command format:
```bash
# N. Description of what this verifies
oc get <resource> ...
# Expected: Description of expected output
```

### 6. Test Steps (H3 per step)

Each step:
```markdown
### Step N: Step Title

**Actions:** (or just numbered list)
1. Action one
2. Action two

**Expected Result:**
- Expected outcome one
- Expected outcome two
```

Rules:
- Steps are UI-focused (user interactions in the console)
- CLI is allowed mid-test ONLY for backend validation (verify YAML/resource state, check config changes) when using Search UI would be unnecessary -- unless the test specifically tests Search UI
- Each step has a clear title and numbered actions
- Expected results use bullet points
- Steps are separated by `---`

### 7. Teardown

```markdown
## Teardown

\`\`\`bash
# Cleanup commands
oc delete <resource> ...
\`\`\`
```

### 8. Notes (optional)

Implementation details, known issues, code references, test scope limitations.

### 9. Known Issues and Code References (optional)

References to source code components and implementation tickets.

---

## CLI-in-Test-Steps Rule

| Section | CLI Commands |
|---------|-------------|
| Setup | Allowed (bash scripts with `oc` commands) |
| Test Steps | UI-only by default. Exception: CLI allowed ONLY for backend validation in a DEDICATED step |
| Teardown | Allowed (cleanup commands) |

### When CLI Is Allowed in Test Steps

CLI is allowed ONLY for **backend validation**, placed in a **dedicated step** titled "Verify [what] via CLI (Backend Validation)":

1. Verify resource YAML state after a UI action created/modified a resource
2. Check config changes not visible in the UI
3. Verify API responses for backend-only behavior
4. Confirm no resource was created (negative test for in-memory operations)

Place backend validation steps AFTER all UI steps. Never embed CLI within a UI-focused step.

### When CLI Backend Validation Is NOT Needed

Do NOT add CLI steps when:
- The UI displays data derived from a backend source and UI steps already verify correctness
- The test is purely about UI rendering, column behavior, or display logic
- The CLI step would only repeat what the UI already shows (redundant)

**Rule of thumb:** If the UI shows the data and your steps verify it, a CLI step repeating the same check is redundant complexity.

### When CLI Is NOT Allowed

- As a substitute for navigating the UI
- To create resources that should be created via UI (use Setup)
- To delete resources mid-test (use Teardown)
- To search for resources when the test is NOT about Search UI

### Example of Allowed Mid-Test CLI

```markdown
### Step 6: Verify Backend Resource State (Backend Validation)

1. Verify the MCRA was created correctly:
\`\`\`bash
oc get multiclusterroleassignment -n open-cluster-management-global-set -o yaml | grep "subject-name"
\`\`\`

**Expected Result:**
- MCRA exists with correct `spec.subject.name`
- Status shows `Applied: True`
```

---

## Coverage Statistics

| Area | Test Cases | Primary Focus |
|------|-----------|---------------|
| RBAC | 44 | Role assignments, scope types, user management |
| Fleet Virtualization | 14 | Tree view, VM creation, saved searches, status |
| CCLM/Migration | 8 | Live migration, bulk migration, RBAC controls |
| MTV | 6 | Provider auto-creation, token rotation, addon |
| Search | 2 | RBAC-scoped search, resource visibility |
| Policy | 1 | Policy validation |
| **Total** | **85** | |

---

## Test Case Complexity Levels

| Complexity | Steps | Lines | Example |
|-----------|-------|-------|---------|
| Simple | 2-4 | ~100 | Tree view toggle, status check |
| Medium | 5-8 | ~200 | Role assignment creation, VM actions |
| Complex | 9-15+ | 500+ | End-to-end migration, multi-step RBAC validation |

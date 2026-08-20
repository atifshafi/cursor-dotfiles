---
name: write-automation-script-playwright
description: Write or update Playwright E2E automation scripts for ACM Console in stolostron/console-e2e. Covers any ACM Console area (RBAC, Clusters, Fleet Virt, Search, ALC, GRC, Credentials, etc.) for any ACM version. Uses subagents for parallel context gathering, MCP servers (acm-source, jira, polarion, playwright) for UI discovery, enforces repo conventions via code quality review, and self-corrects failures via failure debugger. Trigger on Playwright, spec file, console-e2e, e2e test.
---

# Write Automation Script -- Playwright (console-e2e)

Write or update Playwright E2E automation scripts for any ACM Console UI feature using a subagent-orchestrated pipeline.

| Framework | Repo | Local Clone | Status |
|-----------|------|-------------|--------|
| **Playwright** | `stolostron/console-e2e` | `console-e2e` | New, active development |

---

## Core Philosophy

1. **Discover, don't assume** -- use `acm-source` MCP for source code selectors, browser MCP for live page validation. ACM Console spans many areas (Clusters, Applications, Governance, Search, Credentials, Fleet Virt, RBAC, Observability, etc.) -- each has different UI patterns, resources, and behaviors. Always investigate the specific area.
2. **Assertions are sacred -- never compromise them.** Every `test.step()` that says "Verify X" MUST assert X or fail trying. Never use defensive patterns (`.catch(() => false)`, `try/catch` swallowing errors, `if (visible)` guards) that allow a verification step to pass without actually verifying anything. If a step is named "Verify tree view loads" and the tree doesn't load, the step MUST FAIL -- not silently pass. If the entire test cannot run in the environment, use `test.skip(condition, 'reason')` at the TOP of the test body. If a single optional step cannot run (e.g., "skip if only 1 cluster"), use `if (!condition) { return; }` inside the step -- NOT `test.skip()`, which would mark the entire test as skipped even after prior steps passed. A test that passes without asserting is worse than a test that fails -- it creates false confidence.
3. **Tests are self-contained** -- every test creates its own prerequisites (`beforeAll`) and cleans up (`afterAll`). Never assume the cluster has VMs, namespaces, policies, applications, or any resource. Analyze Polarion steps to identify what must exist, then create it via `OcCliService`. Each test case is different.
4. **Reuse before creating** -- before creating ANY new function, interface, config getter, service method, or fixture property, answer: "Does something that already exists return this data or perform this action?" If yes, use it. If it covers 50% or more of what you need, extend it or compose it with a small addition rather than creating a parallel abstraction. Only create entirely new code when nothing existing covers the need. This applies to every layer: config, services, page objects, fixtures, constants. Two functions with different names and return types can still be semantic duplicates if they draw from the same underlying data -- that is a defect, not a design choice.
5. **Follow existing patterns** -- subagent reads neighboring files before you write anything
6. **One test per scenario** -- one `test()` per Polarion ID (or split for retry granularity)
7. **Centralize selectors** -- constants files + page object locators, never inline in tests
8. **Only what the test needs** -- create new page objects, services, fixtures, and constants files when they don't exist. But inside each file, only add the methods, fields, and exports that the current test spec will call. Do not pre-build methods for future tests, even if they are correct and will be needed later. A wizard page object starts with the 3 methods this test uses; the next PR adds more when the next test needs them.
9. **Separate concerns by layer** -- Pages / Components / Services / Fixtures / Tests
10. **Fixtures provide, tests consume** -- tests request only the fixtures they need; Playwright instantiates lazily
11. **Backend via CLI, not UI** -- setup and teardown use `OcCliService`, not UI wizards
12. **Quality gate before testing** -- code quality reviewer catches issues before the test runs
13. **Self-correcting failures** -- failure debugger diagnoses and fixes automation bugs automatically
14. **Never commit/push** -- after tests pass, report to user and stop
15. **Branch from latest remote main** -- always create a fresh branch from `origin/main` before writing code (see Branch Management below)

---

## Branch Management (MANDATORY)

Before writing any code, ensure you are on a **clean branch created from the latest remote main**. Never add automation to an existing feature branch unless the user explicitly instructs otherwise.

```
# On skill start, BEFORE Phase 0:
cd <repo-root>
git fetch origin main
git checkout -b <descriptive-branch-name> origin/main
```

**Branch naming:** `<area>-<feature-or-polarion-id>` (e.g., `governance-policy-labels`, `fg-rbac-role-assignment-61726`, `fleet-virt-advanced-search`)

**Rules:**
- Always `git fetch origin main` first to get the latest remote state
- Create the branch from `origin/main`, NOT from the current HEAD or local main
- If the current working directory has uncommitted changes on another branch, stash or confirm with the user before switching
- If the user says "work on branch X" or "add to my current branch", follow their instruction instead

---

## ACM Hybrid Playwright Architecture

The console-e2e repo follows an **ACM Hybrid Architecture** that separates "Test Intent" (what to verify) from "Implementation Details" (how to interact with UI/CLI).

```
┌──────────────────────────────────────────────────────────┐
│  TESTS (src/tests/)                                      │
│  - Polarion: one test() per ID + test.step() per step    │
│  - ALC sanity: multi test() in one describe (app/)       │
│  - Destructure fixtures: { clusterListPage, oc }       │
│  - No selectors, page.goto, or oc.run in specs           │
└────────────────┬────────────────────┬────────────────────┘
                 │                    │
    ┌────────────▼────────────┐  ┌───▼──────────────────────┐
    │  FIXTURES               │  │  PAGES + COMPONENTS      │
    │  acm-test (cluster)     │  │  BasePage(page) only     │
    │  app-test (ALC)         │  │  Domain pages (page, oc) │
    │  rbac-test (asUser)     │  │  AcmTable, ClusterTable  │
    │  setup → @playwright/test│  │  goto() on each page     │
    └─────┬───────────────────┘  └───┬──────────────────────┘
          │
    ┌─────▼─────────────────┐  ┌─────▼──────────────────────┐
    │  LIB (by area)        │  │  SERVICES (no Playwright)  │
    │  openshift-login.ts   │  │  OcCliService              │
    │  app/ cluster/ gov/   │  │  ObservabilityService ✓  │
    │  fg-rbac/ placement/  │  │  OcCliService: mcra*, vm* │
    │  assertions/          │  │   policy*, application*   │
    └───────────────────────┘  └────────────────────────────┘
```

### Key Architectural Rules

- **Login runs once** in setup projects -- `auth.setup.ts` logs in admin (saves `.auth/admin.json`), `rbac-auth.setup.ts` logs in RBAC users (saves `.auth/{role}.json` per user). Single login implementation: `openshiftLogin()` in `src/lib/openshift-login.ts`. Tests do NOT log in -- they load pre-saved cookies via `storageState`. Playwright projects control which setup runs: admin-only projects depend on `['setup']`, RBAC projects depend on `['setup', 'rbac-setup']`.
- **Multi-user login via storageState** -- `openshiftLogin(page, LoginOptions)` in `src/lib/openshift-login.ts`. Admin: `auth.setup.ts` → `.auth/admin.json` (not `user.json`). RBAC: `rbac-auth.setup.ts` → `.auth/{role}.json` per user from `getRbacUsers(RBAC_DOMAIN)`; **41 users** in `presets.ts` across 3 tiers (rbac-ui, vm, full). `rbac-test.ts` provides `asUser(role)` → `{ page }` (~50ms). Area fixtures (e.g. `fg-rbac-test.ts`) extend `rbac-test` to wire **same-domain** page objects (UserDetailsPage, RoleAssignmentWizardPage, RoleAssignmentsTable) via fixture DI. **Cross-domain page objects MUST NOT be wired into fixtures** -- tests that need page objects from another domain construct them inline from `asUser(role).page`. This prevents compile-time coupling between unrelated areas.
- **Fixtures create pages and services.** Examples: `async ({ clusterListPage, observabilityService }) => {}` (cluster); `async ({ applicationListPage }) => {}` (app).
- **Cleanup in afterEach/afterAll** so retries start clean. Playwright re-runs the full test on retry.
- **No selectors in tests.** All locators live in page objects (as `private readonly` properties) or constants.
- **Services are backend-only.** `OcCliService` contains both generic CLI methods (`run`, `applyYaml`, `getConsoleUrl`) and domain-specific methods (prefixed by resource type: `mcra*`, `vm*`). When 2+ tests share the same `oc.run()` pattern, add a named method to `OcCliService` directly. Services MUST NOT import Playwright.
- **Browser interaction logic lives in `lib/`.** UI assertion helpers, browser context management. This is the line between `services/` (no browser) and `lib/` (browser OK). RBAC login is handled by storageState in the setup project, not `lib/`.
- **Backend setup via OcCliService** -- use `oc.run()` or named OcCliService methods instead of UI wizard for creating resources.
- **Tests own their prerequisites.** Every test must be self-contained. When analyzing test steps, identify what must exist on the cluster (VMs, namespaces, ConfigMaps, Secrets, applications, policies, roles -- whatever the specific test case requires). Create those resources in `beforeAll` via OcCliService and clean up in `afterAll`. Never assume cluster state. Each ACM area has different prerequisites -- there is no default set.
- **Constants: one authoritative location.** Large domains (20+ selectors) have their own constants file that owns routes, selectors, AND text labels. Do NOT duplicate selectors between `selectors.ts` and domain files.

### Lib vs Utils vs Services Boundary

| Question | Answer → Directory |
|----------|-------------------|
| Does it wrap `oc` CLI commands? | `src/services/OcCliService.ts` (add a domain-prefixed method) |
| Is it a stateless pure function with no domain knowledge? | `src/utils/` |
| Is it shared multi-step logic (UI wizard flows, backend poll/assert helpers, data context builders)? | `src/lib/{area}/{helper-name}.ts` |

`lib/` is organized by area subdirectory (71 files): `lib/app/`, `lib/cluster/`, `lib/fg-rbac/`, `lib/governance/`, `lib/placement/`, `lib/assertions/`. It contains three flavors:
1. **Multi-page UI sequences** — drives wizard flows shared across specs (e.g., `lib/governance/policy-lifecycle.ts`)
2. **Backend poll/assert helpers** — combines OcCliService + expect for readiness checks (e.g., `lib/governance/policy-labels-setup.ts`)
3. **Data builders** — pure data loading, context resolution (e.g., `lib/cluster/managedClusterContext.ts`)

**Lib classes must NOT extend BasePage.** `BasePage` is strictly for page objects that have a URL route and `goto()`. Lib action classes (e.g., `ReviewStepActions`, `SyncEditorYamlActions`) operate within a wizard step or panel -- they are not pages. Use **composition**: accept `page: Page` and `waitForLoad: () => Promise<void>` as constructor parameters instead of inheriting from `BasePage`. The parent page object (which does extend `BasePage`) passes its own `waitForLoad` when instantiating the lib class. Example: `new ReviewStepActions(page, () => this.waitForLoad())`.

### Components: Two Tiers

| Tier | Directory | Pattern | Example |
|------|-----------|---------|---------|
| **PF primitives** | `src/components/patternfly/` | Generic PF widget wrappers, domain-agnostic, reused across 4+ areas | `AcmTable`, `ManageColumnsDialog` |
| **Area-specific** | `src/components/{area}/` | Domain-aware. Extends AcmTable (when OUIA IDs available) OR standalone (when not) | `GovernanceTable extends AcmTable`, `ClusterTable` (standalone) |

**Extension rule:** If the upstream table widget uses OUIA IDs for row identification → extend `AcmTable`. If columns use `data-label` or composite IDs that don't map to OUIA → standalone component.

### E2E Spec Data Loader (Static Test Data)

For ALC and GRC tests, static wizard inputs (git repos, branch names, placement configs, expected resources) are defined in YAML scenarios under `src/config/e2e-spec-data/`. Tests consume them via resolvers:

```typescript
import { resolveSubscriptionScenarioByTestId } from '@config';
const scenario = resolveSubscriptionScenarioByTestId('RHACM4K-211053');
// → { gitRepo, branch, path, placement, timeWindow, expectedResources, ... }
```

**When to use:** Data that is the same every time the test runs regardless of environment (wizard field values, expected resource names, topology assertions). **NOT for:** Dynamic runtime data (node counts, release images, credentials, cluster names) — those stay as env vars or config getters.

**Core concepts:**
- **Fragments** — reusable building blocks (e.g., `git-hello-world`: URL + branch + path + expected resources)
- **Profiles** — wizard-driven defaults (e.g., "fill wizard but don't submit", "submit with defaults")
- **Scenarios** — test definitions that compose fragments + profiles + overrides, keyed by Polarion ID

### Reference Documentation (read in this order)

1. **Interactive architecture diagram (AUTHORITATIVE):** `~/Documents/work/automation/documentation/architecture/Console-E2E-Architecture.html` — D3.js interactive diagram with 5 tabs (Layer Architecture, Data Flow, Rules & Anti-Patterns, Authentication Flow, File Placement). Every node has a clickable detail panel with code snippets, file paths, imports, and rules. The `DATA` object is structured JSON-in-HTML that agents can parse directly. Covers layers, file inventory, projects, auth flow, rules, anti-patterns, and placement decisions. Verified against the repo.
2. **Architecture summary (agent-optimized markdown):** `references/architecture-summary.md` — same content as the HTML but in flat markdown. Cross-reference with the HTML for discrepancies.
3. **Framework patterns:** `framework/playwright-patterns.md` — locator strategy, config, auth, test structure examples.
4. **Investigation report:** `~/Documents/work/automation/documentation/investigations/console-e2e-architecture-review-may2026.md`
5. **Target / migration (aspirational):** `docs/architecture-overview.md` in the repo — superset; verify with `Glob`/`ls`

---

## MANDATORY: Phase Gate Enforcement

**This section is NON-NEGOTIABLE. Every phase must be tracked and gated.**

### On skill start, IMMEDIATELY create a TodoWrite with ALL phases:

```
TodoWrite (merge=false):
  phase-0  | Phase 0: Determine area and read knowledge base     | pending
  phase-1  | Phase 1: Context gathering (3 parallel subagents)   | pending
  phase-2  | GATE: Phase 2 Synthesize + coverage map (user approval) | pending
  phase-3  | Phase 3: Code generation (Page → Service → Test)    | pending
  phase-35 | GATE: Phase 3.5 Code quality + lint check (must pass) | pending
  phase-4  | GATE: Phase 4 Local test execution (must pass)      | pending
  phase-45 | Phase 4.5: Failure debugging (if test failed)       | pending
  phase-5  | GATE: Phase 5 Polarion coverage verification        | pending
```

### Gate rules:

1. **A phase CANNOT be marked `completed` without executing it.** Skipping a phase and marking it done is a violation. **Phase 1 specifically requires ALL THREE subagents to return results** -- launching 2 of 3 and marking Phase 1 complete is a violation. If a subagent fails or is unavailable, report the gap to the user and ask how to proceed.
2. **GATE phases (2, 3.5, 4, 5) are HARD STOPS.** You MUST execute them before proceeding. If you find yourself about to commit, push, or report success without Phase 4 completing, STOP and run the test first.
3. **Phase 4 MUST complete before ANY git commit, git push, or Jenkins trigger.** No exceptions. If the user says "push it," respond: "The skill requires local test execution first. Let me run the test before pushing."
4. **Phase 2:** Present the coverage map. If no gaps, missing steps, or critical issues are found, proceed automatically to Phase 3. Only pause for user approval if there are ambiguities, missing prerequisites, or steps that cannot be automated.
5. **Phase 3.5 MUST run `npm run lint:fix`** (auto-fixes formatting issues in YAML/JSON/TS files) **then `npm run lint:check`** to verify zero errors remain. Both commands are required -- `lint:fix` handles formatting that CI enforces, `lint:check` catches logic errors. Then run the full anti-pattern + dead code checklist. Every item must be checked individually -- do not batch-skip. Fix and re-run the entire checklist until every item passes. This phase catches the majority of reviewer feedback; skipping items here wastes review cycles.
6. **Phase 5 MUST re-fetch Polarion steps** and verify 100% coverage before reporting success.
7. **On failure in Phase 4**, mark phase-4 as `pending` (not completed), create phase-45 as `in_progress`, and launch the failure-debugger. After fix, re-run Phase 4.
8. **Never mark phase-5 complete until phase-4 shows a passing test.**

### STOP checkpoints (pause and verify before proceeding):

- **STOP after Phase 2 (only if gaps found):** "Coverage map has gaps/ambiguities. Awaiting your input before code generation." If no issues, proceed automatically.
- **STOP after Phase 3:** "Code generation complete. Starting quality review and lint check."
- **STOP after Phase 3.5:** "Quality review passed. Running local test now."
- **STOP after Phase 4 pass:** "Test passed locally. Verifying Polarion coverage."
- **STOP after Phase 4 fail:** "Test failed. Launching failure debugger to diagnose."

---

## Engram Knowledge Base

Before starting work, check the persistent knowledge base for relevant context:
- `engram_recall("<feature area> architecture dependencies")` -- component dependencies, data flows
- `engram_recall("Playwright test conventions console-e2e")` -- repo patterns, POM, locators
- `engram_recall("<feature area> failure patterns")` -- known failure signatures
- After completing work, store new patterns or discoveries: `engram_remember("...")`

## ASK QUESTIONS FIRST

| Category | Question |
|----------|----------|
| **ACM Version** | "Which ACM version? (e.g., 2.18 / ACM 5.0)" — if unspecified, default to the MCP's `(main)` version for latest development code |
| **Input Source** | "Polarion ID, JIRA ID, or feature description?" |
| **New or Update** | "New script, or updating an existing one?" |
| **Area** | "Which area? (cluster, app/ALC, fg-rbac, fleet-virt, search, GRC, credentials, etc.)" |
| **Environment** | "Hub URL, password, spoke cluster name?" |
| **CNV Version** | (Fleet Virt only) "CNV version?" — if unspecified, default to the MCP's `(main)` version (development branch). Call `list_versions()` and use the version tagged `(main)` so selectors come from the latest dev code, not stale GA. Only use a release branch version if the user explicitly targets GA. |
| **Test User** | "Existing test user, or need a new one?" |

---

## Phase 0: Determine Area

Map user input to area, test directory, fixture, and Playwright project:

| User area | `src/tests/` dir | Fixture | Playwright `--project` |
|-----------|------------------|---------|-------------------------|
| cluster / clusters | `cluster/` | `acm-test` | `cluster` |
| app / alc / applications | `app/` | `app-test` | `alc` |
| governance / grc / policies | `governance/` | `governance-test` | `governance` |
| search | `search/` | `search-test` | `search` |
| fg-rbac | `fg-rbac/` | `fg-rbac-test` (extends `rbac-test`) | `fg-rbac` |
| fleet-virt / virtualization | `fleet-virt/` | `fleet-virt-test` | `fleet-virt` |
| unit (pure TS tests, no browser) | `unit/` | `@playwright/test` (no custom fixture) | `unit` |

- **Architecture (interactive HTML)**: `~/Documents/work/automation/documentation/architecture/Console-E2E-Architecture.html` — parse the `DATA` object for layer details, rules, auth flow, file placement. This is the primary architecture reference.
- **Architecture (markdown)**: `references/architecture-summary.md` (layer table, file inventory, rules, placement)
- **Framework guide**: `framework/playwright-patterns.md` (locator patterns, test structure)
- **Knowledge base**: `/Users/ashafi/Documents/work/notes/knowledge/automation/playwright/{area}.md` — use `app.md` for ALC; `cluster` → `clusters.md`. Also cross-reference `ui/{area}.md` for domain context.
- **Repo root**: `/Users/ashafi/Documents/work/automation/qe-automation-repos/console-e2e`

Before creating files, `Glob`/`ls` the repo — do not assume fg-rbac, fleet-virt, or specific OcCliService methods exist because `docs/architecture-overview.md` lists them.

Read the knowledge base file for the identified area. It contains test users, env vars, API resources, existing helpers, selectors, and gotchas.

---

## Phase 1: Context Gathering (3 Parallel Subagents)

**ALL THREE SUBAGENTS ARE MANDATORY. Skipping any subagent is a skill violation.**

Launch **three subagents in parallel**. These are registered as Cursor Subagents in `~/.cursor/agents/` and can be invoked by name. Detailed reference prompts are also in `subagents/`.

**Cost routing:** Use the `model` parameter on the Task tool to route cheaper models for extraction-heavy subagents:
- Subagent A (Requirements Extractor): `model: "composer-2.5"` -- search/extraction, not reasoning
- Subagent B (UI Discovery): `model: "composer-2.5"` -- MCP queries and selector extraction
- Subagent C (Pattern Analyzer): `model: "composer-2.5"` -- file reading and pattern matching

If extraction quality is inadequate with cheaper models (missing steps, wrong selectors), fall back to `model: "inherit"` for that specific subagent.

**Phase 1 completion checklist (ALL must be true before marking phase-1 complete):**
- [ ] Subagent A (Requirements Extractor) returned Polarion steps
- [ ] Subagent B (UI Discovery) returned selectors, DOM structure, and component paths from `acm-source` MCP
- [ ] Subagent C (Pattern Analyzer) returned existing code patterns and reuse opportunities

**Why UI Discovery cannot be skipped:** Without verifying the actual DOM structure and selectors from source code, specs will use guessed selectors that fail at runtime. Every role locator (`getByRole`, `getByText`, `getByTestId`) must be validated against the real component source, not assumed from Cypress code or Polarion descriptions. Cypress selectors DO NOT translate 1:1 to Playwright -- the DOM roles, accessible names, and component hierarchy differ.

**CRITICAL -- Polarion Test Steps:** If a Polarion ID is provided, fetch full steps via `get_polarion_test_steps` BEFORE writing code. Map each Polarion step to a `test.step()` in the spec (pattern: `gpu-count-column.spec.ts`, `gpu-count-nodes.spec.ts`). For **non-Polarion sanity suites** (e.g. `applications-list.spec.ts`), multiple `test()` blocks without per-step mapping is valid. No Polarion steps may be skipped without explicit user approval.

### Subagent A: Requirements Extractor

**Cursor Subagent:** `requirements-extractor`
**Reference:** `subagents/requirements-extractor.md`

Fill placeholders:
- `POLARION_ID`: from user input
- `JIRA_ID`: from user input
- `PR_LINK`: from user input (if provided)
- `FEATURE_DESCRIPTION`: from user input (if no ticket IDs)

**When Polarion ID is provided:** The requirements extractor MUST call `get_polarion_test_steps(project_id='RHACM4K', work_item_id=POLARION_ID)` to fetch every test step. Return the complete step list with step titles, actions, and expected results. **Also identify prerequisites** -- what resources or environment state each step assumes (e.g., "step 3 verifies policy compliance" implies a Policy + PlacementBinding must exist; "step 2 checks application topology" implies an Application must be deployed).

### Subagent B: UI Discovery Agent

**Cursor Subagent:** `ui-discovery`
**Reference:** `subagents/ui-discovery.md`

Fill placeholders:
- `ACM_VERSION`: from user input
- `CNV_VERSION`: from user input (Fleet Virt only)
- `FEATURE_NAME`: component or feature to discover
- `AREA`: determined in Phase 0
- `UI_PAGES`: from user input or inferred from area

### Subagent C: Pattern Analyzer

**Cursor Subagent:** `pattern-analyzer`
**Reference:** `subagents/pattern-analyzer.md`

Fill placeholders:
- `AREA`: determined in Phase 0
- `KNOWLEDGE_BASE_PATH`: `/Users/ashafi/Documents/work/notes/knowledge/automation/playwright/{area}.md`
- `SPEC_DIR`: `src/tests/{area}/`
- `VIEW_DIR`: `src/pages/`
- `ACTIONS_DIR`: `src/services/`

**Important:** Include the full content of the knowledge base file in the subagent prompt so it has area-specific context without needing to find the file.

---

## Phase 2: Synthesize Results

Merge outputs from all three subagents:

1. **From Requirements Extractor:** Test name, steps, prerequisites, API resources, UI pages
2. **From UI Discovery:** Selectors map, routes, translations, wizard structure, component paths
3. **From Pattern Analyzer:** Patterns to follow, utilities to reuse, existing selectors, cleanup conventions

**Before using the placement table below:** For each file you plan to create or modify, first check if existing code already provides what you need. The table tells you WHERE to put new code -- but only AFTER you've confirmed the code is actually needed. If existing functions, services, or page objects already cover 50%+ of the requirement, compose or extend them instead of creating new files. Use the Pattern Analyzer's sufficiency matrix to verify.

| File Type | Location |
|-----------|----------|
| Test | `src/tests/{area}/{feature}.spec.ts` |
| Page object | `src/pages/{area}/{PageName}.ts` (area subdirectory) |
| Component (PF primitive, cross-area) | `src/components/patternfly/{ComponentName}.ts` |
| Component (area-specific) | `src/components/{area}/{ComponentName}.ts` |
| Constants (<20 selectors) | `src/constants/selectors.ts` (add to `SELECTORS.{area}` section) -- add ONLY properties the spec will reference |
| Constants (20+ selectors) | `src/constants/{area}.ts` (routes + selectors + text -- single authoritative file) -- add ONLY properties the spec will reference |
| CLI methods | Add domain-specific methods directly to `src/services/OcCliService.ts` (prefix by resource: `mcra*`, `vm*`) |
| Shared test logic (multi-step flows, polls, data builders) | `src/lib/{area}/{helper-name}.ts` (organized by area, NOT flat) |
| Stateless pure functions (no domain, no browser) | `src/utils/{helper}.ts` |
| Template (static YAML) | `src/templates/{area}/{resource}.yaml` |
| Fixture | `src/fixtures/{area}-test.ts` |
| Config (env/auth) | Check existing getters in `config/index.ts` first. Only add a new interface + getter if existing ones genuinely don't cover the need. |
| Config (static test data) | `src/config/e2e-spec-data/{area}/` (YAML fragments + profiles + scenarios) |
| Unit test (no browser) | `src/tests/unit/{feature}.unit.spec.ts` |

Decide: update existing files or create new ones. Always prefer updating.
Follow architecture doc: `selectors.ts` for PF globals + small domains, `{area}.ts` for large domains (routes + selectors + text in one file).

### Polarion Coverage Map (MANDATORY when Polarion ID provided)

Before proceeding to code generation, create a coverage map that maps EVERY Polarion test step to a planned `test.step()` in the spec. **Critically, identify prerequisites for each step -- what must exist on the cluster for the step to succeed:**

| Polarion Step | Step Title | Planned test.step() | Page Objects Needed | New PO Required? | Prerequisites |
|---|---|---|---|---|---|
| 1 | (from Polarion) | Step 1: ... | (list pages/components) | Yes/No | (what must exist: VM, namespace, role, etc.) |
| 2 | (from Polarion) | Step 2: ... | ... | ... | ... |
| ... | ... | ... | ... | ... | ... |

**Rules:**
- Every Polarion step MUST have a corresponding `test.step()` in the spec
- Every Polarion **expected result** within a step MUST have a corresponding assertion. Mapping a step but weakening or omitting expected-result assertions is a violation. If the Polarion says "X is visible," the spec must `expect(X).toBeVisible()`. If it says "Y shows text Z," the spec must assert that text.
- **PARTIAL coverage is NOT acceptable.** The only valid statuses are YES (fully covered) or BLOCKED (with explicit user approval to skip). If an expected result cannot be verified, do NOT weaken the assertion -- investigate the discrepancy first (see "Behavior Discrepancy Protocol" below).
- If a step requires page objects that don't exist, list them as "New PO Required"
- If a step cannot be automated (e.g., visual-only verification), document why and get user approval to skip
- If a step requires a sub-tab or page not yet built, BUILD IT -- do not skip the step
- **Identify prerequisites for every step.** Ask: "What cluster resources must exist for this step to work?" (VMs, namespaces, ConfigMaps, roles, applications, policies, etc.). Aggregate all prerequisites into a `test.beforeAll` block. Each test case is different -- the prerequisites depend entirely on what the test is verifying.
- Present this coverage map to the user for approval before writing code

### Behavior Discrepancy Protocol (MANDATORY)

When actual product behavior differs from the Polarion expected result, do NOT silently weaken or replace the assertion. Follow this protocol:

1. **Investigate first.** Before concluding "the product doesn't do X," verify:
   - Is the locator correct? (wrong selector, wrong scope, wrong text match)
   - Is it a timing issue? (element appears after async render, needs `toPass()` retry)
   - Is the test reaching the correct page state? (wrong wizard step, stale navigation)
   - Is the feature actually deployed on this build? (check PR merge status, build tag)

2. **If the product genuinely differs from Polarion:**
   - Report the discrepancy to the user with evidence (screenshot, DOM snapshot)
   - Ask the user: "Should I (a) file a product bug and assert the Polarion expectation anyway, (b) update the Polarion test case, or (c) skip this assertion with a TODO?"
   - Do NOT independently decide to weaken the assertion

3. **Never assume the product is right and Polarion is wrong.** The Polarion test case was written and reviewed by the QE engineer. If the product doesn't match, that's a signal worth investigating, not a reason to change the test.

---

## Phase 3: Code Generation

Write code following the framework guide (`framework/playwright-patterns.md`).

**Order:** Prerequisites -> Service (if needed) -> Page Object / Component -> Fixture wiring -> Test spec

**Scope rule:** At every step, add ONLY what the current test spec requires. If the test needs 3 methods on a page object, add 3 methods -- not 30 to "cover the full page." If the test uses 2 fixture properties, wire 2 -- not 8 for future tests. Every line of code you write must have a caller in the spec you are writing. No exceptions.

**Scope rule does NOT override the no-selectors rule.** If a test step interacts with a UI element on a page that has a page object, that interaction MUST go through a PO method -- even if it's a one-off assertion used by only one spec. The scope rule means "don't add methods the test won't call," NOT "bypass the page object for simple interactions." A one-line PO method wrapping a single `getByRole()` is not over-engineering -- it's the architecture. If you find yourself writing `page.getByRole(...)` in a spec file, STOP and add a method to the relevant page object instead.

### Test Prerequisites Analysis (MANDATORY)

**Core Principle:** Every test must be self-contained. Never assume the cluster has the resources the test needs. When analyzing a test case (from Polarion steps, JIRA story, or feature description), ALWAYS identify what prerequisites exist and handle them programmatically.

**When to analyze:** During Phase 2 (Synthesize Results), as part of the Polarion Coverage Map. For each test step, ask: "What must already exist on the cluster for this step to succeed?"

**Common prerequisite types (not exhaustive -- each test case is different):**

| Prerequisite | Example | How to Handle |
|-------------|---------|---------------|
| VirtualMachine exists and is running | Fleet Virt tests | `oc.vmEnsureTestVM(name, ns, labels)` in `beforeAll` -- creates a lightweight cirros VM (no PVC, starts in seconds). Poll with `oc.vmIsRunning()` |
| Namespace exists | Test needs resources in a specific namespace | `oc.run('oc create ns ... --dry-run=client -o yaml \| oc apply -f -')` |
| ConfigMap / Secret exists | Test verifies environment tab or credential binding | `oc.run('oc apply -f ...')` with inline YAML |
| RBAC user exists with IDP | FG-RBAC tests that login as a non-admin user | Managed externally (htpasswd), guarded by `test.skip(!config.user)` |
| ManagedCluster is available | Tests that need a spoke cluster | Guarded by `test.skip(!spoke)`, cluster managed externally |
| Role / ClusterRole exists | Tests that assign custom roles | `oc.run('oc apply -f ...')` or verified via `oc get clusterrole` |
| Application / Policy deployed | ALC or GRC tests | `oc.run('oc apply ...')` with YAML templates |
| Snapshot / PVC exists | Storage-related VM tests | `oc.run('oc apply ...')` |

**Pattern:** `test.beforeAll` creates resources via `OcCliService`, `test.afterAll` cleans up.

**Dependency injection (DI) is required for lib helpers.** Lib helpers MUST accept `oc: OcCliService` as a parameter -- never create a module-scope `const oc = new OcCliService()` inside the helper. The caller owns the instance and passes it in. This is called dependency injection: the helper declares what it needs, the caller provides it. The opposite (creating `new OcCliService()` inside the helper) is tight coupling -- it hides the dependency, makes testing harder, and creates redundant instances. The `oc` fixture from `acm-test.ts` is test-scoped (created per-test, not available in `beforeAll`/`afterAll`), so `beforeAll`/`afterAll` hooks create their own instance and pass it to helpers.

```typescript
// src/lib/governance/policy-labels-setup.ts (lib helper -- accepts oc via DI)
import { OcCliService } from '@services/OcCliService';

export async function ensurePolicyLabelsClean(oc: OcCliService, policyName: string, ns: string, keys: string[]): Promise<boolean> {
  const exists = await oc.policyExists(policyName, ns);
  if (exists) await oc.policyRemoveLabels(policyName, ns, keys);
  return exists;
}
```

```typescript
// spec file -- OcCliService only for beforeAll/afterAll hooks (test body uses fixture-injected oc)
import { test, expect } from '@fixtures/governance-test';
import { OcCliService } from '@services/OcCliService';
import { ensurePolicyLabelsClean, cleanupPolicyLabels } from '@lib/governance/policy-labels-setup';

test.describe('Feature', { tag: ['@governance'] }, () => {
  let hasResource = false;
  const oc = new OcCliService();

  test.beforeAll(async () => {
    hasResource = await ensurePolicyLabelsClean(oc, 'my-policy', 'local-cluster', ['env']);
  });

  test.afterAll(async () => {
    if (!hasResource) return;
    await cleanupPolicyLabels(oc, 'my-policy', 'local-cluster', ['env']);
  });

  test('RHACM4K-XXXXX: ...', async ({ oc }) => {
    // In-test operations use fixture-injected oc (test-scoped, separate instance)
    await oc.policyAddLabels('my-policy', 'local-cluster', { env: 'prod' });
  });
});
```

For one-off CLI operations, add a named method to `OcCliService` (prefixed by resource type), then call it from a lib helper:

```typescript
// src/lib/{area}/test-setup.ts — lib helper accepts oc via DI
import { OcCliService } from '@services/OcCliService';

export async function ensureTestConfigMap(oc: OcCliService, name: string, ns: string): Promise<void> {
  await oc.applyYaml(path.resolve(__dirname, '../../templates/{area}/test-configmap.yaml'));
}

export async function cleanupTestConfigMap(oc: OcCliService, name: string, ns: string): Promise<void> {
  await oc.deleteYaml(path.resolve(__dirname, '../../templates/{area}/test-configmap.yaml'));
}
```

```typescript
// spec file — OcCliService for hooks only; test body uses fixture-injected oc
import { OcCliService } from '@services/OcCliService';
import { ensureTestConfigMap, cleanupTestConfigMap } from '@lib/{area}/test-setup';

const oc = new OcCliService();
test.beforeAll(async () => { await ensureTestConfigMap(oc, 'e2e-test', 'default'); });
test.afterAll(async () => { await cleanupTestConfigMap(oc, 'e2e-test', 'default'); });
```

**Specific examples across different ACM areas:**

| Area | What the test verifies | What beforeAll creates | What afterAll deletes |
|------|----------------------|----------------------|---------------------|
| Fleet Virt | VM details tabs, search results | `oc.vmEnsureTestVM()` (cirros, no PVC) | `oc.vmDeleteTestVM()` |
| Clusters | Cluster import flow | ManagedCluster YAML via `oc apply` | `oc delete managedcluster` |
| ALC | Application topology, sync status | Application + Channel + Subscription YAMLs | Delete all 3 resources |
| GRC | Policy compliance, violations | Policy + PlacementRule + PlacementBinding | Delete all 3 resources |
| Credentials | Credential list, cloud provider binding | Secret in target namespace | `oc delete secret` |
| Search | Search result accuracy | Any searchable resource (Deployment, ConfigMap) | Delete the resource |
| FG-RBAC | Role assignment wizard, permission checks | RBAC user exists (external), roles assigned in test steps | MCRAs deleted in afterEach |

**Rules:**
- **Analyze first, code second.** Read every Polarion step and ask "what must exist for this to work?" before writing any code. Every test case across every ACM area will have different prerequisites -- there is no one-size-fits-all.
- Resource names use the `uniqueName` fixture (calls `generateSafeName()` from `@utils/kube-helper`) to avoid collisions between parallel runs -- see "Test Data Lifecycle Strategies" below for when to use unique names vs idempotent patterns
- Label all created resources with `e2e-test: "true"` and `test-case: "rhacm4k-xxxxx"` for traceability and emergency cleanup
- Make creation idempotent (check-then-create, or `--dry-run=client -o yaml | oc apply -f -`) so reruns don't fail
- Always poll for readiness after creation -- every resource type has different readiness signals (VM: Running status, Pod: Ready condition, ManagedCluster: Available condition, Application: Synced status)
- Guard `beforeAll`/`afterAll` with config checks when test may be skipped (e.g., `if (!spokeCluster) return`)
- If a prerequisite cannot be created programmatically (e.g., a physical spoke cluster, an IDP, a cloud provider account), guard with `test.skip(condition, 'reason')` and document what the environment must provide
- For complex prerequisites, add named methods to `OcCliService` (e.g., `vmEnsureTestVM`, `mcraDeleteAllForUser`) rather than inlining raw `oc.run()` calls.
- When a test creates resources as PART of its test steps (e.g., creating a role assignment via the wizard IS the test), the prerequisite is the environment needed for that creation (user exists, cluster available) -- not the resource itself

### Test Data Lifecycle Strategies

The repo uses three strategies to prevent test data collisions and ensure reruns work cleanly. Choose the right strategy based on the scenario -- do not mix them arbitrarily.

**Strategy A: Unique names via `uniqueName` fixture (primary approach)**

The `uniqueName` fixture (wired in `acm-test.ts` and `search-test.ts`) calls `generateSafeName(prefix)` from `@utils/kube-helper`, which produces names like `ci-abc12` using a random suffix. Every test run gets a different name, so collisions are impossible and no pre-existence check is needed.

```typescript
// fixture provides uniqueName automatically
async ({ uniqueName, oc, credentialsListPage }) => {
  const credName = `e2e-aws-${uniqueName}`;     // e.g. 'e2e-aws-ci-k7f2x'
  const credNamespace = `e2e-cred-${uniqueName}`;
  // No existence check needed -- name is guaranteed fresh
  // ...
  // Cleanup at end of test
  await oc.run(`oc delete namespace ${credNamespace} --ignore-not-found`);
}
```

Crash recovery is automatic: leftover resources from a crashed previous run have a different random suffix and do not interfere with the next run.

Use when: the test creates its own resource (via UI wizard or CLI), the resource name is not shared with other specs, and each run should start fresh.

**Strategy B: Check-then-skip (idempotent, for shared or fixed-name resources)**

When a resource has a fixed name (shared across specs, or determined by environment rather than test), check whether it exists before creating. Skip creation if present.

```typescript
// src/lib/cluster/credential-setup.ts pattern
async function credentialExists(oc, credential): Promise<boolean> {
  try {
    const result = await oc.run(
      `oc get secret ${credential.name} -n ${credential.namespace} -o name`,
    );
    return result.trim().length > 0;
  } catch {
    return false;
  }
}

export async function setupCredential(oc, provider, credential, config): Promise<void> {
  if (await credentialExists(oc, credential)) {
    console.log(`Credential ${credential.namespace}/${credential.name} already exists, skipping.`);
    return;
  }
  // ... create the resource
}
```

Existing examples in the repo: `setupCredential()` in `src/lib/cluster/credential-setup.ts`, `vmEnsureTestVM()` in `OcCliService`, governance `credExists` checks in `policyautomation-ansiblejob-ui.spec.ts`.

Use when: the resource has a fixed or environment-derived name, multiple specs may share it, or the creation is expensive (VMs, cluster imports).

**Strategy C: Idempotent apply (for infrastructure like namespaces)**

When you need a resource to exist but don't care whether it was already there, use `--dry-run=client -o yaml | oc apply -f -` for creation and `--ignore-not-found` for cleanup.

```typescript
// Idempotent namespace creation
await oc.run(`oc create namespace ${ns} --dry-run=client -o yaml | oc apply -f -`);

// Idempotent cleanup (safe even if resource is already gone)
await oc.run(`oc delete namespace ${ns} --ignore-not-found`);
```

Use when: the resource is infrastructure (namespace, ConfigMap, label) rather than the object under test, and you don't need to know whether it existed before.

**Decision table:**

| Scenario | Strategy | Why |
|----------|----------|-----|
| Test creates its own resource via UI wizard | A (`uniqueName`) | Each run creates a fresh resource; no collision possible |
| Test needs a prerequisite resource via CLI | A or B | A if name can be unique; B if name is fixed or shared |
| Test needs a namespace to exist | C (idempotent apply) | Don't care if it was already there |
| Shared resource used across multiple specs | B (check-then-skip) | Avoid re-creating what another spec already set up |
| Cleanup in `afterAll` | Always `--ignore-not-found` | Safe even if previous steps failed or resource was never created |
| Resource under test vs prerequisite | A for the resource under test; B or C for prerequisites | The thing being tested gets a unique name; supporting infrastructure uses idempotent patterns |

**CLI Operation Reuse Protocol (MANDATORY before writing any `oc.run()`):**

Before writing ANY raw `oc.run()` call in a spec or lib helper, follow this checklist:

1. **Search OcCliService first.** Run `rg "async <keyword>" src/services/OcCliService.ts` for the operation you need (e.g., `label`, `managedcluster`, `namespace`, `get`). If a named method exists (`labelManagedCluster`, `mcraCreate`, `vmEnsureTestVM`, `listManagedClusterNamesInClusterSet`), use it.
2. **Search lib/ and config/ for existing helpers.** Data like managed cluster names, spoke cluster, hub URL, and IDP config is already computed by global setup or the config layer. Examples: `managedClusterNamesForPreview()` in `src/lib/cluster/managedClusterContext.ts` returns all cluster names from the pre-generated `.auth/managedClusters.json`. `getRbacConfig().spokeCluster` returns the spoke cluster name. Never re-query the API for data the framework already provides.
3. **If the operation is used by 2+ specs**, add a named method to `OcCliService` (prefixed by resource type). One spec = inline is acceptable; two specs = extract.
4. **Raw `oc.run()` is acceptable ONLY when** the operation is a true one-off (single spec, single call) with no existing method AND no existing lib/config helper that provides the same data.

**YAML Template Protocol (MANDATORY for resource creation):**

Never inline YAML manifests in spec files via `oc apply -f - <<'EOF' ... EOF`. Instead:

1. **Static resources** (all field values are constants): Create a YAML file in `src/templates/{area}/` and apply via `oc.applyYaml(path)` / `oc.deleteYaml(path)`. Follow the pattern established by `src/templates/fg-rbac/test-clusterset.yaml`, `src/templates/governance/discovered-policy-resources.yaml`, etc.
2. **Dynamic resources** (fields contain runtime values like `Date.now()`, usernames, namespace names): Use a named `OcCliService` method (e.g., `mcraCreate()`, `vmEnsureTestVM()`) which constructs the YAML internally. If no method exists and the pattern will repeat, add one.
3. **Spec files reference templates via `path.join(__dirname, '../../templates/{area}/', 'filename.yaml')`**, matching the established pattern in `role-assignment-clusterset.spec.ts`, `role-assignment-edge-cases.spec.ts`, and governance specs.

**OcCliService (generic + domain methods, all areas):**
- Generic: `run(cmd)`, `applyYaml(path)`, `deleteYaml(path)`, `getConsoleUrl()`, `hasResourcesInCluster(resource)`
- MCRA: `mcraGetForUser()`, `mcraGetRolesForUser()`, `mcraDeleteAllForUser()`
- VM: `vmEnsureTestVM(name, ns, labels)`, `vmIsRunning(name, ns)`, `vmDeleteTestVM(name, ns)`
- Policy: `policyExists()`, `policyAddLabels()`, `policyRemoveLabels()`, `policyGetLabels()`

**Domain services (compose OcCliService):**
- **Implemented:** `ObservabilityService` — `isInstalled()`, `getManagedClusters()`, `getGrafanaAnnotation()`, `restoreGrafanaAnnotation()` (GPU specs use it in `beforeAll`/`afterAll`)
- In hooks: `new ObservabilityService(new OcCliService())`. In tests: prefer fixture-injected service when available.
- Add new domain-specific methods directly to `OcCliService` (prefixed by resource type). Separate service classes only when the domain needs constructor-injected state (like `ObservabilityService`).

### Layer-by-Layer Guide

**1. OcCliService methods (if needed):**
- Add domain-specific methods directly to `src/services/OcCliService.ts`
- Prefix methods by resource type: `mcra*`, `vm*`, `policy*` etc.
- No Playwright imports -- pure CLI
- No separate `services/domains/` directory -- everything goes in `OcCliService`
- Injected via `oc` fixture (already wired in all area fixtures)

**2. Page Object / Component:**

**Page vs Component decision -- use the first matching rule:**

| Question | If yes | Put in |
|---|---|---|
| Does it represent a full view with its own URL route? | Page | `src/pages/{area}/` |
| Is it a multi-step wizard (even if rendered as a modal)? | Page | `src/pages/{area}/` |
| Is it a modal, dialog, or overlay with a simple form? | Component | `src/components/{area}/` |
| Is it a table, filter, sidebar, or widget? | Component | `src/components/{area}/` |
| Can it appear on multiple pages? | Component | `src/components/{area}/` |

**Page contract:** extends `BasePage`, inherits `waitForLoad()`, typically has `goto()` for URL navigation. Constructor takes `(page, oc?)`.

**Component contract:** does NOT extend `BasePage`, no `goto()`, no `waitForLoad()`. Constructor takes `(page)` only. The parent page handles loading state.

- `private readonly` locators in constructor -- only declare locators that are used by a method the test calls
- Public methods for actions -- only add methods the current test spec will call. A wizard page object for a test that exercises 3 of 7 steps gets methods for those 3 steps, not all 7. Add the rest when a future test needs them.
- Accessibility-first locators: `getByRole` > `getByLabel` > `getByText` > `getByTestId` > `locator`
- **Table component decision:** Check UI Discovery results for the table type. ACM Console pages use `AcmTable` (check `keyFn` for OUIA ID usability); kubevirt-plugin pages use OCP SDK `VirtualizedTable` (different DOM). This informs whether to extend `AcmTable` or build standalone. See `framework/playwright-patterns.md` "AcmTable Component" section.
- **Constants file:** Prefer hierarchical structure grouped by UI location (page, table, wizard) over flat label bags. See `framework/playwright-patterns.md` "Constants Design Pattern" section.

```typescript
import { Page, Locator } from '@playwright/test';
import { BasePage } from '@pages/BasePage';
import { OcCliService } from '@services/OcCliService';
import { CLUSTER_ROUTES } from '@constants/cluster';

export class ClusterListPage extends BasePage {
  constructor(
    page: Page,
    private readonly oc: OcCliService,
  ) {
    super(page);
    // private readonly locators...
  }

  async goto(): Promise<void> {
    const consoleUrl = await this.oc.getConsoleUrl();
    await this.page.goto(`${consoleUrl}${CLUSTER_ROUTES.managed}`);
    await this.waitForLoad();
  }
}
```

**3. Fixture wiring:**
- Import the new page object in the fixture file
- Add to the generic type and wire

```typescript
clusterListPage: async ({ page, oc }, use) => {
  await use(new ClusterListPage(page, oc));
},
```

**4. Test spec:**
- Import from `@fixtures/acm-test` (or area fixture)
- Single `test.describe()` with tag
- One `test()` per Polarion ID
- Destructure only needed fixtures
- Use `test.step()` for logical grouping
- Cleanup in `test.afterEach` / `test.afterAll`

```typescript
import { test, expect } from '@fixtures/acm-test';

test.describe('Cluster List Page', { tag: ['@clusters'] }, () => {
  test('should display the local-cluster in the list', async ({ clusterListPage }) => {
    await clusterListPage.goto();
    await clusterListPage.table.search('local-cluster');
    await clusterListPage.table.verifyRowVisible('local-cluster');
  });
});

// Polarion-mapped example (GPU specs):
test('RHACM4K-63953: ...', async ({ clusterListPage }) => {
  await test.step('Verify GPU count column is visible', async () => {
    await clusterListPage.goto();
    // expect on locators from page / constants
  });
});
```

### Key Rules

- Reuse utilities identified by Pattern Analyzer (do NOT reinvent)
- UI Discovery returns all elements on a page -- use only the selectors the current test needs. Do not create locators, constants, or page object methods for discovered elements that the test does not interact with. Discovery is input for decision-making, not a checklist to implement.
- Follow the structure patterns found by Pattern Analyzer
- Apply the knowledge base gotchas
- Always use path aliases (`@pages/`, `@services/`, `@fixtures/`)

---

## Phase 3.5: Code Quality Review

Launch the code quality reviewer subagent.

**Cursor Subagent:** `code-quality-reviewer`
**Reference:** `subagents/code-quality-reviewer.md`
**Cost routing:** `model: "inherit"` -- judgment-critical, needs frontier reasoning

Fill placeholders:
- `GENERATED_FILES`: list of files created/modified
- `AREA`: from Phase 0
- `KNOWLEDGE_BASE_PATH`: from Phase 0

The reviewer checks:
- Architecture compliance (page objects extend BasePage, fixtures for DI, services for backend)
- Prerequisite completeness (test creates its own resources in beforeAll, cleans up in afterAll, never assumes cluster state)
- Reuse opportunities (existing utils, services, page objects)
- **Comment consistency check (MANDATORY):** Before adding any comment (JSDoc, banner separator, inline), check the same file type on `main` for conventions. If existing classes in the same layer have single-line JSDoc, match that. If existing specs have no `// -------` separators, don't add them. If existing constants files don't have `// =====` section banners between exports, don't add them. Never add Polarion IDs, story references, or explanatory prose to comments unless existing files in the same directory already follow that pattern. The spec file header comment is the ONE place where Polarion/Story metadata belongs (matching the existing spec pattern).
- **Anti-pattern scan (MANDATORY -- check EVERY item, do NOT skip):**
  - **Defensive assertion bypass** -- `.isVisible().catch(() => false)` or `.isVisible().catch(() => {})` followed by `if (visible)` guards that skip assertions. Grep: `rg "\.catch\(\(\)" src/tests/ src/pages/ src/components/` and review EVERY match. If a `.catch` is used on a locator check and the result gates an assertion, it is a violation. The assertion must either run unconditionally (use `expect().toBeVisible()`) or the entire step must be skipped with `test.skip()`. There is no middle ground -- a step that conditionally asserts is a step that sometimes tests nothing.
  - `page.waitForTimeout()` in any file
  - `test.only` in any file
  - **ANY `page.*` locator call in spec files** -- `page.getByRole()`, `page.getByText()`, `page.getByLabel()`, `page.getByTestId()`, `page.locator()` (ALL must go through page object methods, zero exceptions). Grep: `rg "page\.(getByRole|getByText|getByLabel|getByTestId|locator)\(" src/tests/`. The ONLY acceptable `page.*` calls in specs are `page.waitForURL()` and `page.keyboard.*`. If a PO exists for the page, every interaction with that page goes through the PO -- even one-off assertions.
  - `page.goto()` in spec files (all navigation must be in page object methods)
  - `page.reload()` in retry loops (use `page.goto(url).catch(() => {})` via PO method)
  - CSS class selectors for assertions (use role-based locators)
  - `not.toBeVisible()` (use `toBeHidden()`)
  - Raw `oc.run()` in spec **files** (hooks should use named OcCliService methods; one-off `oc.run` in hooks only until a named method is added)
  - Separate service class files under `services/domains/` (add methods to OcCliService directly)
  - Inline domain constants in spec files (API groups, resource names, cluster names must be in `constants/{area}.ts`)
  - String literal `'local-cluster'` in spec files (must come from constants or config)
  - Raw `oc.run()` for operations that have named OcCliService methods (grep OcCliService.ts for the verb/resource before writing raw calls)
  - Inline YAML (`oc apply -f - <<'EOF'`) instead of `oc.applyYaml()` with a template file in `src/templates/{area}/`
  - `oc get managedclusters` or similar API queries for data already available via `managedClusterNamesForPreview()`, `getRbacConfig().spokeCluster`, or other lib/config helpers
  - Hardcoded column indices `td.nth(N)` (use header-based column resolution)
  - Duplicated methods across multiple page objects (extract to shared component in `components/`)
  - CSS class selectors inline in page objects (move to `SELECTORS` or area constants file)
- **Dead code sweep (MANDATORY -- check EVERY export with grep evidence):**
  - Page object methods with zero callers (check every method -- if no test or fixture calls it, remove it)
  - Unused imports (constants, types, services that were added speculatively but never referenced)
  - Constants exports that are not imported by ANY other file in the PR (remove them)
  - Hardcoded strings that duplicate a constant (use the constant instead)
  - Fixture properties that no test destructures
  - Convenience/shortcut methods that compose other public methods (e.g. `createGlobalAccess()` that calls `selectScopeGlobal()` + `clickNext()` + `selectRole()` + `submitCreate()`) -- if no test calls them, they are dead code even if they "look useful"
  - Every method in a page object must have at least one caller in a test or fixture written in THIS PR. Methods "for future tests" are dead code even if they are correct, well-implemented, and will definitely be needed later. The next PR adds them when the next test needs them. This is non-negotiable -- a page object with 30 methods but only 10 callers in the current specs has 20 methods that must be deleted.
  - **Verification method (NON-NEGOTIABLE):** For EVERY public method in new/modified page objects, run `rg "methodName" src/` and include the grep output in the review. If zero callers outside the defining file, delete the method. Do NOT self-certify -- show the evidence. Same for every exported constant: `rg "CONSTANT_NAME" src/` must show at least one importer.
  - **Per-property verification for `as const` objects (NON-NEGOTIABLE):** An exported object being imported does NOT mean all its properties are consumed. For each property in a new or modified `as const` export, grep the PROPERTY name: `rg "\.propertyName" src/`. If a property has zero references outside its defining file, delete it. Example: `CLUSTER_DESCRIPTION` being imported does not prove `CLUSTER_DESCRIPTION.modalTitle` is used -- grep for `\.modalTitle` specifically. The object import is necessary but not sufficient evidence; every individual property must have a caller.
  - **PO bypass check (NON-NEGOTIABLE):** After writing specs, run `rg "page\.(getByRole|getByText|getByLabel|getByTestId|locator)\(" src/tests/` on ALL spec files in this PR. ANY match means the spec is bypassing a page object. For each match: (1) identify which page the spec is on, (2) check if a PO exists for that page, (3) if yes, move the locator into a PO method and call it from the spec. This is the most common reviewer feedback -- a PO that exists but is only used for `goto()` while the rest of the page interactions are inline. A PO is not just a navigation tool.
- **Lint gate:** Run `npm run lint:check` (Prettier + ESLint + TypeScript) on the repo. Fix any errors introduced by generated code before proceeding. **Prettier checks ALL file types** (`.ts`, `.json`, `.md`, `.yml`, `.yaml`) -- if you created or modified any non-TypeScript file (JSON configs, YAML templates, scripts), run `npm run lint:fix` to format them. CI will fail on unformatted files of any type.

**If ANY blocking issue is found:** Fix it, then RE-RUN the Phase 3.5 checklist. Do NOT proceed to Phase 4 until every item passes. **Circuit breaker:** Maximum **2 re-runs** of Phase 3.5. If issues persist after 2 fix-and-recheck cycles, proceed to Phase 4 with remaining issues documented (they are likely false positives or require user judgment). Do not loop indefinitely -- each re-run costs significant tokens.

---

## Phase 4: Test Execution

Launch the test runner subagent.

**Cursor Subagent:** `test-runner`
**Reference:** `subagents/test-runner.md`
**Cost routing:** `model: "composer-2.5"` -- primarily shell command execution

Fill placeholders:
- `SPEC_PATH`: path to the spec file
- `WORKING_DIR`: repo root directory
- `PROJECT`: `cluster` | `alc` | `governance` | `search` | `fg-rbac` | `fleet-virt` | `unit` (from spec path — never `chromium`)

**If test passes:** Proceed to Phase 5.

---

## Phase 4.5: Failure Debugging (if test failed)

Launch the failure debugger subagent.

**Cursor Subagent:** `failure-debugger`
**Reference:** `subagents/failure-debugger.md`
**Cost routing:** `model: "inherit"` -- judgment-critical, needs frontier reasoning for diagnosis

Fill placeholders:
- `FAILURE_OUTPUT`: raw test runner output
- `SPEC_PATH`: path to failing spec
- `VIEW_FILES`: paths to page object and component files
- `AREA`: from Phase 0
- `ACM_VERSION`: from user input
- `CLUSTER_URL`: hub API URL

The debugger will return a diagnosis:
- **automation_bug:** Apply the suggested fix, go back to Phase 4
- **environment_issue:** Report to user with evidence
- **product_bug:** Report to user, offer to file JIRA

**Circuit breaker (MANDATORY):** Maximum **2 failure-debug cycles** (Phase 4 → 4.5 → fix → Phase 4 → 4.5). If the test still fails after 2 debug cycles, STOP and report to the user with all collected evidence. Do NOT enter a third cycle -- the issue likely requires human judgment or environment changes. Each cycle costs significant tokens; runaway loops are the primary source of budget overruns.

---

## Phase 5: Report Results

- **All passed:** Report files created/modified, test duration. Ask user about commit.
- **Environment issue:** Report what's wrong, what the user needs to fix.
- **Product bug:** Report the issue, offer to file JIRA via `jira-operations` skill.
- **NEVER** commit, push, or modify `build/` directory.
- **ALWAYS** provide a "Local headed run" command so the user can watch the test in a visible browser. Use the test-runner subagent's headed command template with the actual KUBECONFIG, spec path, and project name filled in. This is non-optional -- the user expects to see a ready-to-paste command to run the test with UI visible and 2-second slowMo after every successful execution.

### Coverage Verification (MANDATORY)

After all tests pass, re-fetch the Polarion test steps and verify 100% coverage:

1. Call `get_polarion_test_steps` for each Polarion ID
2. Map each Polarion step to the corresponding `test.step()` in the spec
3. For each step, verify that EVERY expected result has a corresponding assertion in the spec (not just the actions)
4. Report coverage as a table:

| Polarion Step | Spec Step | Actions Covered? | Expected Results Covered? | Status |
|---|---|---|---|---|
| Step 1: ... | Step 1: ... | All / Missing X | All / Missing Y | YES / NO |

5. **The ONLY acceptable status is YES.** PARTIAL is NOT a valid status -- it means the step needs more work before reporting.
6. If any step is NOT fully covered (actions AND expected results), fix it immediately before reporting completion. Do NOT report success with partial steps.
7. Only report "complete" when every Polarion step has a corresponding `test.step()` that exercises ALL described actions and asserts ALL expected results (N/A for multi-scenario ALC sanity files without Polarion IDs)
8. **If a step was weakened during debugging** (e.g., an assertion was removed because it failed), flag it and restore the full assertion. Investigate the failure per the Behavior Discrepancy Protocol instead of removing the assertion.

### Skip Detection (MANDATORY)

After test execution passes, check the output for ANY skipped steps or conditional early returns. Report ALL skips to the user with this format:

```
SKIPPED STEPS (require attention):
- Step N: [step name] -- SKIPPED because: [reason from console.log or test.skip message]
  Action needed: [fix the skip condition / environment limitation / etc.]
```

**Rules:**
- The goal is ALWAYS to execute ALL Polarion steps via automation. A skip is NOT a pass.
- If a step is skipped due to environment limitations (e.g., only 1 cluster when 2 needed), report it clearly and suggest what the user can do (add a cluster, use a different env, etc.)
- If a step is skipped due to a code bug (shell escaping, wrong command, etc.), FIX IT before reporting success.
- NEVER report "all tests pass" if any Polarion step was skipped without explicitly calling it out.
- Conditional skips (`if (condition) return`) are acceptable ONLY when the environment genuinely cannot support the step -- but they MUST be reported.
- **Check the test status in the runner output.** If the test shows `-` (skipped) instead of `✓` (passed), a `test.skip()` was called mid-execution. This is a bug -- `test.skip()` inside a test step marks the entire test as skipped, hiding the fact that prior steps succeeded. Fix by replacing the mid-test `test.skip()` with `if (!condition) { return; }` inside the step, then re-run.

---

## Migration Mode (Cypress to Playwright)

When user asks to migrate a Cypress test to Playwright:

1. Read the migration assistant template: `subagents/migration-assistant.md`
2. Launch a generalPurpose subagent with the Cypress file paths
3. The subagent produces Playwright equivalents using the pattern mapping table
4. Run through Phase 3.5 (quality review) and Phase 4 (test execution) as normal

---

## Area-Specific Reference

**Read ONLY the subsection for the area you are working on.** Each area has unique conventions, wait patterns, and gotchas that differ from other areas. These sections are equal in weight -- no area is primary.

### Known (All Areas): ACM Console Plugin 404 on First Navigation

ACM routes (`/multicloud/*`) may return 404 on the first browser navigation because the ACM console plugin loads after the OCP shell. The `toPass()` retry loops in specs handle this automatically by navigating fresh on each retry. This is expected OCP dynamic plugin behavior, not a bug.

---

### Governance (GRC)

**Fixture:** `governance-test.ts` — unique for using **worker-scoped `oc`** (shared across all tests in a worker, reduces KUBECONFIG overhead for heavy resource creation).

**YAML Template Substitution:** All resource setup uses `applyYamlTemplate(oc, path, subs)` from `@lib/governance/yaml-template-utils.ts`. Placeholders are `[KEY_UPPERCASE]` in YAML, replaced at runtime. 19 templates in `src/templates/governance/`. Security: `assertSafeTemplatePath` prevents path traversal; `assertSafeOcSingleArg` validates all CLI params.

**Policy Compliance Waits:** Governance has 8+ unique poll functions in `@lib/governance/policy-lifecycle.ts`:
- `waitForPolicyPropagation(oc, name, ns)` — waits for `.status.compliant` to be non-empty (120s)
- `waitForPolicyStatus(oc, name, ns, expected)` — waits for specific compliance value (180s)
- `waitForAnyClusterCompliant(oc, name, ns)` — at least one cluster Compliant (180s)

**Timeouts:** Governance tests use `test.setTimeout(360_000)` to `600_000` — the slowest area due to policy propagation. Never use default 60s.

**UI retry pattern:** Uses `expect().toPass()` with escalating intervals `[5_000, 10_000, 15_000]` for UI assertions that depend on backend propagation.

**RBAC in governance:** Uses `browser.newContext()` + `openshiftLogin()` with `GRC_IDP` + `GRC_RBAC_PASS` env var. Different from fg-rbac which uses pre-authenticated storageState.

**Key gotcha:** Template substitution is UPPERCASE — rule `{ foo: 'bar' }` replaces `[FOO]` not `[foo]`. Cleanup uses `deleteYamlTemplate` with the SAME substitution rules — different rules = leaked resources.

---

### ALC (Application Lifecycle)

**Fixture:** `app-test.ts` — 5 wizard page objects + `managedClusterContext` from `.auth/managedClusters.json`.

**Spec Data Loader:** ALC is the primary consumer of the YAML scenario system:
```typescript
const { subscription: options, applicationExpectations: expectations } =
  resolveSubscriptionScenarioByTestId('RHACM4K-7484');
```
Fragments (`_shared.yaml`) define reusable blocks (git repos, placements). Profiles define wizard behavior modes. Scenarios compose both.

**Serial mode + cache clearing:** ALC suites use `test.describe.configure({ mode: 'serial' })` for dependent flows (create → edit → delete). Call `clearE2eSpecDataCache()` in `beforeEach` to prevent stale state.

**Topology drawer polling:** Unique async pattern — re-clicks graph nodes + polls until drawer field matches:
```typescript
await pollTopologyDrawerLabeledFieldUntil({ page, detailsPage, nodeDataId, fieldLabel, expected, timeout: 90_000 });
```

**Wizard multi-block fills:** Subscription wizards iterate `repositories[]`, clicking "Add Channels" for each block > 0. Composable helpers: `fillRepositoryBlockBySpec()`, `applyPerBlockOptions()`.

**Timeouts:** `test.setTimeout(180_000)` to `480_000` — propagation delays for application sync.

**Key gotchas:**
- GitOps prep required: Argo tests need `E2E_GITOPS_PREP=1` + `applyGitopsPlacementPreviewSetup(oc)` in `beforeAll`
- App deletion timing: `deleteApplicationFromOverviewViaSearch` waits for modal but NOT namespace cleanup — follow-up assertions need manual `oc` waits
- `removeRelatedResources: false` keeps subscriptions/channels alive for orphan tests — must manually `oc.deleteNamespace` in `finally`

---

### FG-RBAC (Fine-Grained RBAC)

**Permission Reference (MUST READ for any role/permission work):** `~/Documents/work/automation/documentation/acm-components/virt/guides/COMPLETE-RBAC-MATRIX.md` — single reference for all 8 KubeVirt + ACM-extended roles (2.15 and 2.16/5.0), VNC permission matrix and UI state machine, MCRA deployment architecture, user impersonation flow, tree visibility behavior, Search/cluster-proxy integration, role label policy for UI visibility, `oc auth can-i` API group gotcha, and Playwright assertion examples.

**Fixture:** `fg-rbac-test.ts` extends `rbac-test.ts` — provides `rbacConfig`, `asUser(role)`, 6 page objects.

**User naming convention:**

| Field | Pattern | Example |
|-------|---------|---------|
| Role key (presets.ts) | `fg-rbac-<descriptor>-<polarionId>` | `fg-rbac-csfull-61727` |
| Username (cluster) | `clc-e2e-<descriptor>-<polarionId>` | `clc-e2e-csfull-61727` |
| Lookup in specs | `rbacConfig.users['<descriptor>-<polarionId>']` | `rbacConfig.users['csfull-61727']` |

**Adding a new user:** Add to `presets.ts` + `gen-rbac.sh`. The `rbacConfig.users` map auto-populates.

**MCRA Propagation Wait:** After wizard creates MCRAs, wait for `Applied: True` on ALL:
```typescript
await expect(async () => {
  const userMCRAs = await oc.mcraGetForUser(user);
  expect(userMCRAs.length).toBeGreaterThanOrEqual(1);
  for (const mcra of userMCRAs) {
    const applied = conditions?.find((c) => c.type === 'Applied');
    expect(applied?.status).toBe('True');
  }
}).toPass({ intervals: [5000, 10000, 15000], timeout: 120000 });
```

**Cleanup:** Always clean BEFORE and AFTER each test: `await oc.mcraDeleteAllForUser(user)`.

**Local setup:** Enable FG-RBAC → `gen-rbac.sh` (creates IDP + 41 users) → `setup-test-roles.sh` → re-login as admin → `npx playwright test --project=fg-rbac`.

---

### Fleet Virt (Virtualization)

**Permission Reference (MUST READ for VNC, role visibility, or RBAC-gated feature work):** `~/Documents/work/automation/documentation/acm-components/virt/guides/COMPLETE-RBAC-MATRIX.md` — see "VNC Console Access" section for which roles grant VNC (only `kubevirt.io:admin/edit`), VNC UI state machine (Disconnect button always rendered — use `toBeDisabled()` not `toBeHidden()`), "Fleet Virtualization Tree Visibility" for tree behavior (cluster-wide, not filtered by kubevirt roles), and "`oc auth can-i` API Group Gotcha" for SubjectAccessReview usage.

**Fixture:** `fleet-virt-test.ts` — `virtConfig` (spoke cluster), `fleetVirtPage`, `advancedSearchModal`, `savedSearches`.

**Version strategy:** Always default to the development branch (`main`) of `kubevirt-ui/kubevirt-plugin`. Call `list_versions()` on `acm-source` MCP and use the CNV version tagged `(main)` — this maps to `kubevirt-plugin@main` where new features land. The GA release branch (`release-4.XX`) receives only bug/security fixes and lags behind. Only use a GA version if the user explicitly requests it.

**Route structure (CNV 4.22+):**
| Route | Path |
|-------|------|
| VM list | `/fleet-virtualization/kubevirt.io~v1~VirtualMachine/all-clusters/all-namespaces` |
| VM details | `/fleet-virtualization/kubevirt.io~v1~VirtualMachine/cluster/:cluster/ns/:ns/:name` |

**Tab split (CNV 4.22+):** VM list has two tabs: **Overview** (default) and **Virtual machines**. Must call `fleetVirtPage.gotoVmTab()` to reach the VM table.

**VM lifecycle:** `oc.vmEnsureTestVM(name, ns, labels)` creates lightweight cirros VMs (no PVC, starts in seconds). Poll with `oc.vmIsRunning()`. Clean with `oc.vmDeleteTestVM()`.

**Table type:** Fleet Virt pages use OCP SDK `VirtualizedTable` (not `AcmTable`). The DOM is different — uses data-label columns, not OUIA IDs. Components are standalone, not extending `AcmTable`.

**Key gotcha:** Overview tab has cluster status skeletons that may never resolve for RBAC users with limited permissions — always navigate to VM tab explicitly.

---

### Search

**Fixture:** `search-test.ts` — dedicated fixture (does NOT use `acm-test.ts`). Provides `searchPage`, `searchDetailsPage`, `overviewPage`.

**URL-driven filter injection:** Tests apply search filters by navigating to `?filters=${encodeURIComponent(JSON.stringify({textsearch:...}))}` instead of typing into the search bar. This bypasses UI tokenizer timing issues.

**Saved search CRUD (serial):** Uses `test.describe.configure({ mode: 'serial' })` for dependent flow: save → edit → share → delete.

**Backend cleanup:** `afterAll` uses `oc.deleteUserPreference(username)` to remove server-side saved searches (UserPreference CR). Idempotent with `--ignore-not-found`.

**No resource creation:** Search tests operate against existing cluster state (the `search-api` Deployment must already exist). No `beforeAll` resource creation.

**Key gotchas:**
- Dependency on `search-api` Deployment — tests verify against this real resource. If absent, "no results" errors.
- PF6 CSS selector `button.pf-v6-c-menu-toggle` for kebab — breaks on PF version upgrade.
- Serial cascade: one failure in saved-search cascades to all subsequent tests.

---

### Cluster

**Fixture:** `acm-test.ts` — shared fixture (also bundles governance and overview page objects). Provides `clusterListPage`, `clusterNodesPage`, `placementsListPage`, `createPlacementWizardPage`.

**ObservabilityService gate:** GPU tests instantiate `new ObservabilityService(new OcCliService())` in `beforeAll`, check `svc.isInstalled()`, then `test.skip(!installed, 'Observability not available')`. NOT injected via fixture — manual instantiation.

**Managed cluster context:** `.auth/managedClusters.json` (from global-setup Python script) provides cluster names. Access via `managedClusterNamesForPreview()` (always includes `local-cluster`) or `getPrimaryManagedCluster()`.

**Placement preview:** Two-layer architecture — thin orchestrator in `@lib/cluster/` calls wizard methods, then delegates to `@lib/placement/` for generic placement logic (reused by governance and ALC).

**`forceNativeTableLayout()`:** Mandatory for value extraction — PF6 virtualizes tables by default, which breaks column value reads. Call before `getColumnValues()`.

**Spec Data Loader:** Placement tests use `resolvePlacementScenarioByTestId('RHACM4K-64220')` for scenario data.

**Key gotchas:**
- `acm-test.ts` bundles unrelated areas — don't assume there's a `cluster-test.ts`
- GPU test silently skips if Observability isn't installed — CI may report as skipped, not failed
- `local-cluster` assumption in placement preview — if local-cluster isn't joined, labeling fails

---

## Style Rules

### Must Do

| Rule | Convention |
|------|-----------|
| Single test per scenario | One `test()` per Polarion ID |
| Centralize selectors | Constants files + page object `private readonly` locators |
| Text-based buttons | `page.getByRole('button', { name: 'Next' })` |
| Logical grouping | `test.step('Step description', async () => { ... })` |
| Condition-based waits | `expect(locator).toBeVisible()`, `locator.waitFor()` |
| Environment guards (whole-test) | `test.skip(condition, 'reason')` at the TOP of the test body or `beforeAll` -- skips the entire test when the environment can't support it |
| Environment guards (optional step) | `if (!condition) { return; }` inside the `test.step()` -- the test still passes, the optional step is gracefully skipped. NEVER use `test.skip()` inside a mid-test step (see "Must NOT Do"). |
| Self-contained prerequisites | `test.beforeAll` creates resources via OcCliService methods; never assume cluster state |
| Setup/teardown in lib helpers (with DI) | Move `beforeAll`/`afterAll` setup logic into helper functions in `src/lib/{area}/`. Helpers MUST accept `oc: OcCliService` as a parameter (dependency injection) -- never create `new OcCliService()` inside the helper. The spec's `beforeAll` creates `const oc = new OcCliService()` at describe scope and passes it to helpers. This keeps the dependency explicit and the helper testable. |
| Cleanup on retry | Clean BEFORE each test (ensures retry starts clean) AND AFTER each test (leaves cluster clean). Use `--retries 0` for failure debugging. |
| Path aliases | `@pages/`, `@services/`, `@fixtures/`, `@utils/` |
| Locator hierarchy | getByRole > getByLabel > getByText > getByTestId > locator |
| TypeScript | All files `.ts`, strict mode, no `any` |
| Page objects extend BasePage (pages only) | Only classes in `src/pages/` that represent a full URL route extend `BasePage`. Lib action classes in `src/lib/` must NOT extend `BasePage` -- use composition (accept `page` + `waitForLoad` callback). Components in `src/components/` also do NOT extend `BasePage` -- they take `(page)` only; the parent page handles loading. |
| Backend ops via OcCliService | Add domain-specific methods directly to `OcCliService` (prefix by resource: `mcra*`, `vm*`). Tests call named methods (e.g., `oc.mcraGetForUser()`), not raw CLI strings. `beforeAll`/`afterAll` hooks create `const oc = new OcCliService()` at describe scope (since the `oc` fixture is test-scoped and not available in hooks). |

### Must NOT Do

| Anti-Pattern | Why |
|-------------|-----|
| Raw `oc.run()` or `OcCliService` import in specs | Specs must NOT import `OcCliService` for test body operations -- use the fixture-injected `oc`. Move setup/teardown logic into lib helpers (`src/lib/{area}/`). The only place specs may reference `OcCliService` is at describe scope to create an instance for `beforeAll`/`afterAll` hooks (since the `oc` fixture is test-scoped and unavailable in hooks). |
| Module-scope `new OcCliService()` in lib helpers | Lib helpers must accept `oc: OcCliService` as a parameter (dependency injection). Never create `const oc = new OcCliService()` at module scope inside a lib helper -- this is tight coupling. The caller owns the instance and passes it in. |
| Raw `oc.run()` when a named method exists | Before writing `oc.run('oc label managedcluster ...')`, check if `oc.labelManagedCluster()` exists. Before writing `oc.run('oc get managedclusters ...')`, check if `managedClusterNamesForPreview()` in `src/lib/cluster/managedClusterContext.ts` provides the data. Always search OcCliService and lib/ first. See "CLI Operation Reuse Protocol" in the Prerequisites section. |
| Inline YAML in spec files (`oc apply -f - <<'EOF'`) | YAML manifests must live in `src/templates/{area}/` as `.yaml` files, applied via `oc.applyYaml(path)` / `oc.deleteYaml(path)`. For dynamic resources, use named OcCliService methods (e.g., `mcraCreate()`). Inline YAML is untestable, unreviewable, and inconsistent with the template convention. See "YAML Template Protocol" in the Prerequisites section. |
| Re-querying API for pre-computed data | Global setup writes `.auth/managedClusters.json` with all managed cluster names. Use `managedClusterNamesForPreview()` or `loadManagedClusterContext()` from `src/lib/cluster/managedClusterContext.ts` instead of `oc get managedclusters`. Use `getRbacConfig().spokeCluster` instead of querying env vars or the API for the spoke cluster name. |
| Defensive `.catch(() => false)` + `if` guard on assertions | **ABSOLUTE PROHIBITION.** Never write `locator.isVisible().catch(() => false)` followed by `if (visible) { expect(...) }`. This makes the assertion conditional -- if the element isn't found, the step passes without verifying anything. The test becomes a liar: it reports green but tested nothing. If a step says "Verify X," use `expect(X).toBeVisible()` directly and let it fail. If the environment truly can't support the step, use `test.skip(condition, 'reason')` -- never a silent catch-and-skip. This applies to ALL assertion-adjacent locator checks, not just `isVisible`. |
| `.catch(() => {})` on single CLI commands | `--ignore-not-found` already handles the expected case. Adding `.catch(() => {})` silently hides real errors (permission denied, API down). Use `.catch` only for multi-step cleanup where partial completion is acceptable. Never double up both on the same call. |
| Legacy env var fallbacks (`OPTIONS_*`, etc.) | The console-e2e repo uses `HUB_PASSWORD`, `CONSOLE_USERNAME`, `CONSOLE_IDP`. Do NOT add fallbacks for env vars from other repos (e.g. `OPTIONS_HUB_PASSWORD` from clc-ui-e2e). Use only the vars documented in architecture-summary.md. |
| New abstraction for already-available data | Before creating any new getter, service method, or interface, verify each field or capability isn't already provided by existing code. Creating a new function that returns data already reachable through existing functions produces two sources of truth. When the underlying data changes, both must be updated -- but only one will be. Compose existing code instead. |
| Domain-specific CLI logic in page objects | Page objects are for UI interaction. Domain CLI operations (label CRUD, resource lifecycle, multi-step backend flows) belong in `OcCliService` as named methods. Page objects may only wrap one-liner OcCliService calls (e.g., `oc.hasResourcesInCluster()`). |
| `extends BasePage` on lib action classes | Lib action classes (`src/lib/`) must NOT extend `BasePage`. `BasePage` is for page objects with a URL route and `goto()`. Action helpers that operate within a wizard step, panel, or section use composition: accept `page` and `waitForLoad` as constructor parameters. The parent page object passes its `waitForLoad` when creating the action helper. |
| Direct `page.goto()` in test files | All navigation belongs in page object methods. For retry loops (`toPass()`), add a `navigateTo*()` variant on the PO that skips `waitForLoad()` and includes `.catch(() => {})`. Tests must never construct URLs. |
| Inline domain constants in spec files | Move API groups, resource names, policy names, cluster names to `constants/{area}.ts`. Only truly ephemeral test data (random values, test-specific label values) may stay in the spec. |
| Hardcoded column indices (`td.nth(N)`) | Fragile if columns reorder. Use `getCellByColumnHeader(row, 'Labels')` which resolves the column index from header text at runtime. |
| Selectors in test files | Fragile, duplicated -- use page object |
| Multiple unrelated tests per describe | Breaks Polarion mapping |
| `page.waitForTimeout(N)` | Forbidden by architecture doc. Use `expect(locator).toBeVisible()`, `expect().toPass()` with retry, `page.waitForURL()`, or `page.waitForLoadState()` |
| `page.reload()` in retry loops | Crashes if Chromium tab is dead. Use `page.goto(url).catch(() => {})` -- recreates navigation from scratch |
| CSS class selectors for assertions | Internal OCP/PF classes break across versions. Use role-based locators: `getByRole('heading')`, `getByRole('button')` |
| `not.toBeVisible()` for hidden checks | Use `toBeHidden()` instead -- more explicit and matches repo ESLint/convention |
| Clicking combobox `<input>` for PF6 dropdowns | Unreliable after other form interactions. Click the adjacent PF6 toggle button instead |
| Using `textContent()` for multi-element cells | Concatenates child text without spaces. Parse with regex or use `innerText()` |
| Assuming menu items without live verification | Actions menu items differ by RBAC role -- view users don't see Start/Stop/Restart |
| Assume UI text without MCP discovery | Text changes between versions |
| Leave `.only` in code | Breaks CI |
| Commit or push | User decides |
| Cross-domain page objects in fixtures | Area fixtures wire same-domain POs only. For cross-domain: `const s = await asUser(role); const po = new OtherDomainPage(s.page);` inline in the test. Coupling FG-RBAC fixture to Fleet Virt POs means a compile error in Fleet Virt breaks all RBAC tests. |
| Browser interaction in `services/` | Services are backend-only (no Playwright). RBAC login uses storageState from the setup project, not runtime browser context creation |
| Separate service files for CLI ops | Do NOT create `services/domains/` or separate service classes. Add domain-specific methods directly to `OcCliService`, prefixed by resource type (`mcra*`, `vm*`). |
| Duplicate selectors across files | Each selector lives in exactly ONE location. Large domains own their own constants file -- do NOT also add to `selectors.ts` |
| UI-based setup (wizard for test data) | Use OcCliService methods for backend setup |
| Raw `process.env` in tests | Use config layer or fixture |
| Relative imports (`../../`) | Use path aliases (`@pages/`, `@lib/`, `@services/`, etc.) |
| Complex assertions in page objects | Page objects expose locators; tests assert. Exceptions: `waitForLoad()`; `AcmTable.verifyRow*` (ESLint-whitelisted) |
| Methods or code for future tests | Every method, getter, fixture property, and constant must have a caller in the test being written NOW. Do not pre-build page object methods for wizard steps, tabs, or actions that the current test does not exercise. Even if the method is correct and will be needed by the next Polarion test case, it does not belong in this PR. Add it in the PR that adds the test that needs it. |
| Modifying existing code you are not working on | NEVER change existing functions, comments, or code that is not part of your implementation. Only add new code or modify code you are explicitly working on. Leave everything else untouched -- do not "improve" comments, rename variables, or refactor code that is not directly related to the task. |
| `locator.isVisible({ timeout: N })` | **Playwright API misuse.** `isVisible()` does NOT accept a timeout parameter -- it returns instantly (current DOM state). The timeout is silently ignored. For a timed visibility check, use `expect(locator).toBeVisible({ timeout: N })` or `expect(locator).toBeHidden({ timeout: N })`. This is NOT the same as passing timeout to `isVisible`. |
| Inline component interaction logic in specs | If a spec duplicates logic that already exists in a component method (e.g., kebab menu dismiss → open → click), call the component method instead. When the pattern doesn't exist yet, add it to the component and call it. Spec files should never contain Escape-key press + waitForTimeout + open-menu + click-item sequences inline -- that belongs in the component layer (e.g., `clickDeleteAction()`, `clickEditAction()`). |
| Self-contradictory assertion logic | Never write `if (visible) { expect(count).toBe(0) }`. If rows ARE visible, their count is > 0 -- so the assertion is dead code that can never execute AND pass. This pattern reveals confused logic. Decide: either you expect the element to be hidden (use `toBeHidden()`), or you expect it to be visible with specific content (use `toBeVisible()` + content assertion). |
| `page.waitForTimeout(N)` in component methods | Even inside components, use explicit state assertions to confirm the UI has settled: `await expect(menuLocator).toBeHidden()` instead of `await page.waitForTimeout(500)`. Arbitrary sleeps are fragile and slow. |
| `test.skip()` inside a mid-test `test.step()` | **Playwright behavior trap.** `test.skip()` marks the ENTIRE test as "skipped" regardless of where it's called -- even if 8 prior steps already passed. The test report shows "skipped" (implying nothing ran), hiding all the work that succeeded. For optional Polarion steps (e.g., "skip if only 1 cluster"), use `if (!condition) { return; }` inside the step body so the test reports as "passed" with the optional step gracefully skipped. Reserve `test.skip()` exclusively for the TOP of a test body or `beforeAll`/`beforeEach` where the entire test genuinely should not run. |

---

## MCP Quick Reference

| Need | MCP / Tool |
|------|-----------|
| Test case steps | `polarion` -> `get_polarion_work_item`, `get_polarion_test_steps` |
| Story requirements | `jira` -> `get_issue` |
| UI components, source code | `acm-source` -> `search_code`, `get_component_source` |
| Wizard step structure | `acm-source` -> `get_wizard_steps` |
| UI text / labels | `acm-source` -> `search_translations` |
| Existing QE selectors | `acm-source` -> `get_acm_selectors('catalog', component)` |
| PF6 CSS selectors | `acm-source` -> `get_patternfly_selectors(component)` |
| Navigation routes | `acm-source` -> `get_routes` |
| Fleet Virt selectors | `acm-source` -> `get_fleet_virt_selectors` |
| Live page snapshot | `playwright` MCP -> `browser_navigate`, `browser_snapshot` |
| Architecture dependencies | `neo4j-rhacm` -> `read_neo4j_cypher` |
| Live cluster resources (pods, policies, namespaces) | `acm-search` -> `find_resources` (auto-connects to cluster from `notes/notes.md`; if errored, toggle MCP off/on in Cursor Settings; fall back to `oc` CLI) |
| Managed cluster list and kubectl on spoke | `acm-kubectl` -> `clusters`, `kubectl`, `connect_cluster` |
| PR analysis | `github` MCP -> `get_pull_request`, `get_pull_request_diff`; fallback: `gh` CLI |
| Pipeline failures | `jenkins` -> `analyze_pipeline`, `get_test_results` |
| Sprint context | `active-sprint-tasks` skill |
| JIRA write ops | `jira-operations` skill |
| Polarion test case writing | `write-testcase-console` skill |

**Version management (always do first):**
```
list_versions()            # Check available versions -- use the one tagged (main) for dev
set_acm_version('2.19')    # ACM Console: use (main) version for latest dev code
set_cnv_version('4.23')    # Fleet Virt only: use (main) version for latest dev code
list_repos()               # Verify active versions point to 'main' branch
```
**Default to development branches.** When the user doesn't specify a version,
call `list_versions()` and pick the versions tagged `(main)`. This ensures
selectors, routes, and translations come from the latest development code —
not the GA release branch which may be behind. Only use GA release versions
(tagged `(latest)`) if the user explicitly says they're targeting a shipped version.

---

## Skill File Structure

```
~/.cursor/skills/write-automation-script-playwright/
  SKILL.md                    # This file (orchestrator)
  references/                 # Detailed docs (progressive disclosure — Level 3)
    architecture-summary.md       # Agent-optimized architecture (layers, files, rules, placement)
  # Knowledge base lives centrally in:
  # /Users/ashafi/Documents/work/notes/knowledge/automation/playwright/
  #   app.md, rbac.md, clusters.md, fleet-virt.md, credentials.md,
  #   cluster-sets.md, search.md, automation-ansible.md, ecosystem-cim.md, hosted-clusters.md
  # Also cross-reference: .claude/knowledge/ui/{area}.md for domain context
  framework/                  # Framework-specific patterns
    playwright-patterns.md    # Locators, fixtures, async/await, repo structure
  subagents/                  # Subagent prompt templates (Playwright-specific)
    requirements-extractor.md # Polarion, JIRA, PR context
    ui-discovery.md           # acm-source MCP, browser MCP
    pattern-analyzer.md       # Existing code analysis (Playwright paths)
    code-quality-reviewer.md  # Post-generation review (Playwright checks)
    test-runner.md            # Playwright test execution
    failure-debugger.md       # Failure diagnosis (Playwright context)
    migration-assistant.md    # Cypress-to-Playwright migration

~/.cursor/agents/             # Cursor Subagents (persistent, shared with Cypress skill)
  requirements-extractor.md   # Phase 1: Polarion/JIRA/PR extraction
  ui-discovery.md             # Phase 1: selectors, routes, translations
  pattern-analyzer.md         # Phase 1: existing code patterns
  code-quality-reviewer.md    # Phase 3.5: code review
  test-runner.md              # Phase 4: test execution
  failure-debugger.md         # Phase 4.5: failure diagnosis
```

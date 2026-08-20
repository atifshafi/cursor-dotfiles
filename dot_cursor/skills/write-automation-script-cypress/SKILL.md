---
name: write-automation-script-cypress
description: Write or update Cypress E2E automation scripts for ACM Console in stolostron/clc-ui-e2e (local clone clc-ui). Covers any ACM Console area (RBAC, Clusters, Fleet Virt, Search, ALC, GRC, Credentials, etc.) for any ACM version. Uses subagents for parallel context gathering, MCP servers (acm-source, jira, polarion, acm-search, acm-kubectl) for UI discovery, enforces repo conventions via code quality review, and self-corrects failures via failure debugger. Trigger on Cypress, spec file, clc-ui, clc-ui-e2e.
---

# Write Automation Script -- Cypress (clc-ui-e2e)

Write or update Cypress E2E automation scripts for any ACM Console UI feature using a subagent-orchestrated pipeline.

| Framework | Repo | Local Clone | Status |
|-----------|------|-------------|--------|
| **Cypress** | `stolostron/clc-ui-e2e` | `clc-ui` | Active, existing tests |

## Core Philosophy

1. **Discover, don't assume** -- use `acm-source` MCP for source code selectors, browser MCP for live page validation
2. **Follow existing patterns** -- subagent reads neighboring files before you write anything
3. **One test per test case** -- one `describe()` + one `it()` per Polarion ID
4. **Centralize selectors** -- named objects in view files, never inline in specs
5. **View file first, spec second** -- create/update the view (page object) before the spec
6. **Separate concerns by layer** -- views / actions / APIs
7. **Quality gate before testing** -- code quality reviewer catches issues before the test runs
8. **Self-correcting failures** -- failure debugger diagnoses and fixes automation bugs automatically
9. **Never commit/push** -- after tests pass, report to user and stop
10. **Branch from latest remote main** -- always create a fresh branch from `origin/main` before writing code (see Branch Management below)

---

## Branch Management (MANDATORY)

Before writing any code, ensure you are on a **clean branch created from the latest remote main**. Never add automation to an existing feature branch unless the user explicitly instructs otherwise.

```
# On skill start, BEFORE Phase 0:
cd <repo-root>
git fetch origin main
git checkout -b <descriptive-branch-name> origin/main
```

**Branch naming:** `<area>-<feature-or-polarion-id>` (e.g., `governance-policy-labels`, `fg-rbac-role-assignment-61726`, `fleet-virt-vm-bulk-migration`)

**Rules:**
- Always `git fetch origin main` first to get the latest remote state
- Create the branch from `origin/main`, NOT from the current HEAD or local main
- If the current working directory has uncommitted changes on another branch, stash or confirm with the user before switching
- If the user says "work on branch X" or "add to my current branch", follow their instruction instead

---

## MANDATORY: Phase Gate Enforcement

**This section is NON-NEGOTIABLE. Every phase must be tracked and gated.**

### On skill start, IMMEDIATELY create a TodoWrite with ALL phases:

```
TodoWrite (merge=false):
  phase-0  | Phase 0: Determine area and read knowledge base     | pending
  phase-1  | Phase 1: Context gathering (3 parallel subagents)   | pending
  phase-2  | Phase 2: Synthesize results and plan files           | pending
  phase-3  | Phase 3: Code generation (API → View → Spec)        | pending
  phase-35 | GATE: Phase 3.5 Code quality review (must pass)     | pending
  phase-4  | GATE: Phase 4 Local test execution (must pass)      | pending
  phase-45 | Phase 4.5: Failure debugging (if test failed)       | pending
  phase-5  | Phase 5: Report results to user                     | pending
```

### Gate rules:

1. **A phase CANNOT be marked `completed` without executing it.** Skipping a phase and marking it done is a violation.
2. **GATE phases (3.5 and 4) are HARD STOPS.** You MUST execute them before proceeding. If you find yourself about to commit, push, or report success without Phase 4 completing, STOP and run the test first.
3. **Phase 4 MUST complete before ANY git commit, git push, or Jenkins trigger.** No exceptions. If the user says "push it," respond: "The skill requires local test execution first. Let me run the test before pushing."
4. **Phase 3.5 MUST complete before Phase 4.** Launch the code-quality-reviewer subagent. If blocking issues are found, fix and re-run until clean.
5. **On failure in Phase 4**, mark phase-4 as `pending` (not completed), create phase-45 as `in_progress`, and launch the failure-debugger. After fix, re-run Phase 4.
6. **Never mark phase-5 complete until phase-4 shows a passing test.**

### STOP checkpoints (pause and verify before proceeding):

- **STOP after Phase 3:** "Code generation complete. Starting code quality review before test execution."
- **STOP after Phase 3.5:** "Code quality review passed. Running local test now."
- **STOP after Phase 4 pass:** "Test passed locally. Reporting results -- NO commit/push without user request."
- **STOP after Phase 4 fail:** "Test failed. Launching failure debugger to diagnose."

---

## Engram Knowledge Base

Before starting work, check the persistent knowledge base for relevant context about the target feature area, known patterns, and conventions:
- `engram_recall("<feature area> architecture dependencies")` -- component dependencies, data flows
- `engram_recall("Cypress test conventions clc-ui-e2e")` -- repo patterns, POM structure
- `engram_recall("<feature area> failure patterns")` -- known failure signatures
- After completing work, store any new patterns or discoveries: `engram_remember("...")`

## ASK QUESTIONS FIRST

| Category | Question |
|----------|----------|
| **ACM Version** | "Which ACM version? (e.g., 2.18 / ACM 5.0)" — if unspecified, default to the MCP's `(main)` version for latest development code |
| **Input Source** | "Polarion ID, JIRA ID, or feature description?" |
| **New or Update** | "New script, or updating an existing one?" |
| **Area** | "Which area? (RBAC, Clusters, Fleet Virt, Search, ALC, GRC, Credentials, etc.)" |
| **Environment** | "Hub URL, password, spoke cluster name?" |
| **CNV Version** | (Fleet Virt only) "CNV version?" — if unspecified, default to the MCP's `(main)` version (development branch). Call `list_versions()` and use the version tagged `(main)` so selectors come from the latest dev code. Only use a release branch version if the user explicitly targets GA. |
| **Test User** | "Existing test user, or need a new one?" |

---

## Phase 0: Determine Area

Map user input to:
- **Area**: rbac | clusters | fleet-virt | credentials | cluster-sets | search | automation | ecosystem | hosted-clusters
- **Knowledge base**: `/Users/ashafi/Documents/work/notes/knowledge/automation/cypress/{area}.md`. Also cross-reference `ui/{area}.md` for domain context.
- **Framework guide**: `framework/cypress-patterns.md`
- **Repo root**: `/Users/ashafi/Documents/work/automation/qe-automation-repos/clc-ui`

Read the knowledge base file for the identified area. It contains test users, env vars, API resources, existing helpers, selectors, and gotchas.

Read the framework guide for Cypress-specific patterns, chaining conventions, and the actual repo structure.

---

## Phase 1: Context Gathering (3 Parallel Subagents)

Launch **three subagents in parallel**. These are registered as Cursor Subagents in `~/.cursor/agents/` and can be invoked by name. Detailed reference prompts are also in `subagents/`.

### Subagent A: Requirements Extractor

**Cursor Subagent:** `requirements-extractor`
**Reference:** `subagents/requirements-extractor.md`

Fill placeholders:
- `POLARION_ID`: from user input
- `JIRA_ID`: from user input
- `PR_LINK`: from user input (if provided)
- `FEATURE_DESCRIPTION`: from user input (if no ticket IDs)

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
- `KNOWLEDGE_BASE_PATH`: `/Users/ashafi/Documents/work/notes/knowledge/automation/cypress/{area}.md`
- `SPEC_DIR`: `cypress/tests/{area}/`
- `VIEW_DIR`: `cypress/views/{area}/`
- `ACTIONS_DIR`: `cypress/views/actions/`

**Important:** Include the full content of the knowledge base file in the subagent prompt so it has area-specific context without needing to find the file.

---

## Phase 2: Synthesize Results

Merge outputs from all three subagents:

1. **From Requirements Extractor:** Test name, steps, prerequisites, API resources, UI pages
2. **From UI Discovery:** Selectors map, routes, translations, wizard structure, component paths
3. **From Pattern Analyzer:** Patterns to follow, utilities to reuse, existing selectors, cleanup conventions

Determine file locations:

| File Type | Location |
|-----------|----------|
| Spec | `cypress/tests/{area}/{feature}.spec.js` |
| View (page object) | `cypress/views/{area}/{feature}.js` |
| Actions | `cypress/views/actions/{area}.js` |
| API | `cypress/apis/{resource}.js` |
| Helpers | `cypress/tests/{area}/helpers/{feature}.js` |

Decide: update existing files or create new ones. Always prefer updating.

---

## Phase 3: Code Generation

Write code following the framework guide (`framework/cypress-patterns.md`).

**Order:** API (if needed) -> View (page object) -> Actions -> Spec

Key rules:
- Reuse utilities identified by Pattern Analyzer (do NOT reinvent)
- Use selectors discovered by UI Discovery (do NOT assume)
- Follow the structure patterns found by Pattern Analyzer
- Apply the knowledge base gotchas (deferred token, PF6 dropdowns, etc.)

See existing reference files for templates:
- [repo-conventions.md](repo-conventions.md)
- [code-templates.md](code-templates.md)

---

## Phase 3.5: Code Quality Review

Launch the code quality reviewer subagent.

**Cursor Subagent:** `code-quality-reviewer`
**Reference:** `subagents/code-quality-reviewer.md`

Fill placeholders:
- `GENERATED_FILES`: list of files created/modified
- `AREA`: from Phase 0
- `KNOWLEDGE_BASE_PATH`: from Phase 0

The reviewer checks:
- POM compliance (selectors in view files, not in specs)
- Reuse opportunities (existing utilities vs new code)
- Anti-patterns (cy.wait, missing failOnStatusCode, it.only, raw `cy.exec()` in specs)
- **Dead code sweep (MANDATORY):** After code generation, scan ALL generated files for:
  - View/action functions with zero callers (if no spec calls it, remove it)
  - Unused imports (selectors, helpers that were added speculatively but never referenced)
  - Hardcoded strings that duplicate a named selector or constant (use the constant instead)
  - Duplicate selectors across view files (each selector lives in exactly one location)
  - Every exported function or selector must have at least one caller. Functions "for future use" are dead code -- add them when a test needs them, not before.

**If blocking issues found:** Fix them and re-run the reviewer. Loop until all blocking issues are resolved.

---

## Phase 4: Test Execution

Launch the test runner subagent.

**Cursor Subagent:** `test-runner`
**Reference:** `subagents/test-runner.md`

Fill placeholders:
- `SPEC_PATH`: path to the spec file
- `WORKING_DIR`: repo root directory
- `BROWSER`: chrome

**IMPORTANT: Always run tests in headless mode.** Use `npx cypress run` (which defaults to headless). Do NOT use `--headed`. Headless mode is faster, produces the same results, and avoids blocking the user's display. Video recordings and screenshots are still captured for debugging failures.

**If test passes:** Proceed to Phase 5.

---

## Phase 4.5: Failure Debugging (if test failed)

Launch the failure debugger subagent.

**Cursor Subagent:** `failure-debugger`
**Reference:** `subagents/failure-debugger.md`

Fill placeholders:
- `FAILURE_OUTPUT`: raw test runner output
- `SPEC_PATH`: path to failing spec
- `VIEW_FILES`: paths to view files
- `AREA`: from Phase 0
- `ACM_VERSION`: from user input
- `CLUSTER_URL`: hub API URL

The debugger will return a diagnosis:
- **automation_bug:** Apply the suggested fix, go back to Phase 4
- **environment_issue:** Report to user with evidence
- **product_bug:** Report to user, offer to file JIRA

---

## Phase 5: Report Results

- **All passed:** Report files created/modified, test duration. Ask user about commit.
- **Environment issue:** Report what's wrong, what the user needs to fix.
- **Product bug:** Report the issue, offer to file JIRA via `jira-operations` skill.
- **NEVER** commit, push, or modify `build/` directory.

---

## Style Rules

### Must Do

| Rule | Convention |
|------|-----------|
| Single test per case | One `it()` per Polarion ID |
| Centralize selectors | Named objects in view files |
| Text-based buttons | `cy.contains('button', 'Next')` |
| `failOnStatusCode: false` | All cleanup `cy.request()` calls |
| Log in helpers | `cy.log('message')` |
| Condition-based waits | `cy.waitUntil()` |
| Environment guards | `this.skip()` |
| Selector hierarchy | data-ouia > data-label > data-testid > aria-label > ID > PF6 class > text |
| Backend ops via action helpers | Wrap domain-specific `cy.exec()` / API calls in action files or dedicated helper modules. Spec files call high-level domain methods (e.g., `addPolicyLabels()`), not raw CLI strings. Backend logic stays in action files, not view files (view = UI selectors, action = backend + interaction logic). |

### Must NOT Do

| Anti-Pattern | Why |
|-------------|-----|
| Raw `cy.exec()` in spec files | Wrap in action/helper functions. Test steps should read as high-level intent, not raw CLI commands. |
| Domain CLI logic in view files | View files are for UI selectors. Backend operations belong in action files or dedicated helpers. |
| Hardcoded selectors in spec files | Fragile, duplicated -- use view file |
| Multiple test blocks per case | Breaks Polarion mapping and retry logic |
| `cy.wait(N)` | Use `cy.waitUntil()` with conditions |
| Assume UI text without MCP discovery | Text changes between versions |
| Leave `.only` in code | Breaks CI |
| Commit or push | User decides |
| Modify `build/` directory | Separate branch for user setup |
| Reinvent existing utilities | Check `genericFunctions.js` / `commonSelectors.js` first |

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
| Live page snapshot | `browser` -> `browser_navigate`, `browser_snapshot` |
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
list_versions()            # Check which versions map to main (dev)
set_acm_version('2.19')    # ACM Console: use (main) version for latest dev code
set_cnv_version('4.23')    # Fleet Virt only: use (main) version for latest dev code
list_repos()               # Verify versions point to correct branches
```
**Default to development branches.** When the user doesn't specify a version,
call `list_versions()` and pick the versions tagged `(main)`. This ensures
selectors come from the latest development code — not the GA release branch.

---

## Skill File Structure

```
~/.cursor/skills/write-automation-script-cypress/
  SKILL.md                    # This file (orchestrator)
  repo-conventions.md         # Cypress repo structure and conventions
  code-templates.md           # Cypress code templates
  # Knowledge base lives centrally in:
  # /Users/ashafi/Documents/work/notes/knowledge/automation/cypress/
  #   rbac.md, clusters.md, fleet-virt.md, credentials.md, cluster-sets.md,
  #   search.md, automation-ansible.md, ecosystem-cim.md, hosted-clusters.md
  # Also cross-reference: .claude/knowledge/ui/{area}.md for domain context
  subagents/                  # Subagent prompt templates (detailed reference)
    requirements-extractor.md # Polarion, JIRA, PR context
    ui-discovery.md           # acm-source MCP, browser MCP
    pattern-analyzer.md       # Existing code analysis
    code-quality-reviewer.md  # Post-generation review
    test-runner.md            # Test execution
    failure-debugger.md       # Failure diagnosis
  framework/                  # Framework-specific patterns
    cypress-patterns.md       # cy commands, chaining, async model

~/.cursor/agents/             # Cursor Subagents (persistent, invocable by name)
  requirements-extractor.md   # Phase 1: Polarion/JIRA/PR extraction
  ui-discovery.md             # Phase 1: selectors, routes, translations
  pattern-analyzer.md         # Phase 1: existing code patterns
  code-quality-reviewer.md    # Phase 3.5: code review
  test-runner.md              # Phase 4: test execution
  failure-debugger.md         # Phase 4.5: failure diagnosis
```

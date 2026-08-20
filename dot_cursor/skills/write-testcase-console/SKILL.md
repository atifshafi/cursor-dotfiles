---
name: write-testcase-console
description: Write ACM Console UI test cases for any console area. Uses subagent pipeline for deep feature investigation (JIRA + PR + code), live environment validation (browser + oc CLI), quality review, and Polarion HTML generation. Uses MCP servers (acm-source, jira, polarion, neo4j-rhacm, acm-search, acm-kubectl, browser) for discovery. Trigger on test case, Polarion, HTML format, setup section, test steps, or any ACM console feature.
---

# ACM Console UI Test Cases

Write, update, and format ACM Console UI test cases for Polarion using a subagent-orchestrated pipeline.

## Core Philosophy

1. **Investigate deeply** -- don't just read the JIRA summary. Read comments, linked tickets, PR diffs, and code changes.
2. **Discover, don't assume** -- use MCP servers for all UI elements, navigation paths, labels, and selectors.
3. **Validate on live cluster** -- when environment is available, verify behavior before writing.
4. **Review before delivering** -- quality reviewer catches assumed elements, missing metadata, and format issues.
5. **Follow conventions** -- match the structure and format of existing test cases (see [test-case-conventions.md](test-case-conventions.md)).

---

## MANDATORY: Phase Gate Enforcement

**This section is NON-NEGOTIABLE. Every phase must be tracked and gated.**

### On skill start, IMMEDIATELY create a TodoWrite with ALL phases:

```
TodoWrite (merge=false):
  phase-0  | Phase 0: Determine area, inputs, read conventions   | pending
  phase-1  | Phase 1: Context gathering (3 parallel subagents)   | pending
  phase-2  | Phase 2: Synthesize investigation results            | pending
  phase-3  | Phase 3: Live validation (if environment available)  | pending
  phase-4  | Phase 4: Write test case document                    | pending
  phase-45 | GATE: Phase 4.5 Quality review (must pass)          | pending
  phase-5  | Phase 5: Deliver to user                             | pending
```

### Gate rules:

1. **A phase CANNOT be marked `completed` without executing it.**
2. **Phase 4.5 is a HARD STOP.** Launch the testcase-reviewer subagent. Fix and re-run until all blocking issues are resolved. Do NOT deliver the test case to the user before this passes.
3. **Never skip Phase 3** when an environment URL was provided. If the environment is unavailable, log why and mark as `cancelled` (not `completed`).
4. **Phase 4 MUST complete before Phase 4.5.** Write the document first, then review it.

### STOP checkpoints:

- **STOP after Phase 2:** "Investigation complete. Starting live validation (or writing if no environment)."
- **STOP after Phase 4:** "Test case written. Running quality review now."
- **STOP after Phase 4.5 pass:** "Quality review passed. Delivering test case."

### MANDATORY: Investigation Traceability

After each phase, preserve a condensed summary of the investigation output in the test case's **Notes** section. This is NON-NEGOTIABLE -- without it, there is no way to debug why a test case missed a scenario or used a wrong UI element.

**After Phase 1 (each subagent returns):** Record key findings immediately -- do not wait until Phase 4. Keep a running summary:
- **Feature Investigator:** Acceptance criteria extracted (numbered), edge cases found, linked tickets, RBAC impact
- **Code Change Analyzer:** Changed components, conditional logic found, UI interaction models, coverage gaps (code paths not covered by any acceptance criterion)
- **UI Discovery:** Routes verified, translations confirmed, selectors found, live verification status

**After Phase 2:** Record design decisions:
- Scenarios planned (count and brief description)
- Optimizations applied (state transitions, resource consolidation)
- Coverage gaps triaged (count added/noted/skipped)
- Conflicts resolved between agents

**After Phase 4.5:** Record review outcome:
- Verdict and iteration count
- Issues found and fixed
- MCP verifications performed

Include this in the final test case under `## Notes > ### Investigation Trail` so anyone reviewing the test case can trace each decision back to its source.

---

## Engram Knowledge Base

Before starting, check the persistent knowledge base for feature context and conventions:
- `engram_recall("<feature area> architecture")` -- how the feature works, dependencies
- `engram_recall("Polarion test case conventions")` -- format, setup section, steps
- `engram_recall("MCP server Polarion usage")` -- Polarion MCP tools and query syntax
- After completing work, store discoveries: `engram_remember("...")`

## ASK QUESTIONS FIRST

| Category | Questions to Ask |
|----------|------------------|
| **JIRA Ticket** | "What's the JIRA ticket? (ACM-XXXXX)" |
| **Version** | "Which ACM version? (e.g., 2.18 / ACM 5.0)" — if unspecified, default to the MCP's `(main)` version for latest development code |
| **CNV Version** | (Fleet Virt only) "CNV version?" — if unspecified, default to the MCP's `(main)` version (development branch). Call `list_versions()` and use the version tagged `(main)`. |
| **Environment** | "Hub cluster name and console URL?" |
| **Feature Scope** | "What specific flow/scenario to cover?" |
| **Test Users** | "What test user? Any RBAC requirements?" |
| **Existing Coverage** | "Related test cases to reference or avoid duplicating?" |

---

## Phase 0: Determine Area and Inputs

Map user input to:
- **Area**: rbac | clusters | fleet-virt | credentials | cluster-sets | search | automation | ecosystem | hosted-clusters
- **JIRA ID**: ACM-XXXXX (story or feature ticket)
- **ACM Version**: from JIRA fix_versions or user input
- **PR Number**: from JIRA description/comments or user input

---

## Phase 1: Feature Investigation (3 Parallel Subagents)

Launch three subagents in parallel to gather comprehensive context.

**Knowledge DB lookup**: Search `acm-knowledge` MCP with `search_knowledge(query=<feature area>)` to find relevant conventions, area knowledge, and testing considerations. Also read these files directly if the MCP is unavailable:
- `conventions/test-case-format.md` -- test case format rules
- `conventions/polarion-html-templates.md` -- HTML template conventions
- `ui/<area>.md` -- area-specific UI knowledge (routes, components, testing gotchas)

### Subagent A: Feature Investigator

**Cursor Subagent:** `feature-investigator`

Provide: JIRA ticket ID.

The investigator will:
- Read the full JIRA story (description, acceptance criteria, fix version, components)
- Read ALL comments (implementation decisions, edge cases, QE feedback)
- Find linked tickets (QE tracking, sub-tasks, related stories, bugs)
- Find PRs referenced in the ticket
- Return: feature summary, acceptance criteria, edge cases, test scenarios

### Subagent B: Code Change Analyzer

**Cursor Subagent:** `code-change-analyzer`

Provide: PR number and repo (from Feature Investigator or user).

The analyzer will:
- Read PR metadata and diff
- For each changed file, identify new/modified UI elements
- Check component dependencies via neo4j-rhacm
- Map code changes to testable scenarios
- Return: changed components, new UI elements, new routes, new error messages, backend impact

### Subagent C: UI Discovery

**Cursor Subagent:** `ui-discovery` (shared with write-automation-script)

Provide: ACM version, CNV version (if Fleet Virt), feature name, area.

The discoverer will:
- Set ACM/CNV version in acm-source MCP
- Search source code for components
- Get selectors, translations, routes, wizard steps
- Return: selectors map, routes, translations, wizard structure

---

## Phase 2: Synthesize and Plan Test Scenarios

Merge all three subagent outputs using the **Conflict Resolution Hierarchy**:

| Data Type | Trust Source | Reason |
|-----------|-------------|--------|
| UI elements (labels, routes, selectors) | UI Discovery | reads source directly via MCP |
| Business requirements (ACs, scope) | Feature Investigator | reads JIRA directly |
| What changed (files, diff) | Code Change Analyzer | reads the PR diff |
| Metric names, translation strings, field labels | CURRENT source code (via `search_translations` or `get_component_source`) | JIRA descriptions may contain stale or proposed names changed during implementation |

When a discrepancy is found between JIRA and source code, use the source code value and add a Note: "JIRA says '{jira-name}' but source code uses '{source-name}' (verified via [tool])".

Plan the test case structure:
- How many test steps (typically 5-10 for medium complexity)
- What the setup needs (prerequisites, test users, resources)
- What each step validates (UI action + expected result)
- Where mid-test CLI validation is needed (resource state checks)
- What teardown is required
- **Negative scenarios:** If the feature is conditionally rendered (permission checks, feature gates, addon dependencies), plan at least one step verifying absence when the condition is not met.

**Scope Gating (MANDATORY):**
1. Extract the target JIRA story's Acceptance Criteria
2. For each planned test step, verify it maps to at least one AC
3. If a step tests functionality from a DIFFERENT story (even if same PR): do NOT include it as a test step; mention in Notes as "Related but scoped to [other-story]"
4. Title reflects target story scope, not PR scope

**AC vs Implementation Cross-Reference:**
1. For each AC, find the corresponding code behavior from code analysis
2. If they AGREE: no action needed
3. If they DISAGREE (AC says X, code does Y): flag as "AC-IMPLEMENTATION DISCREPANCY". The test case validates against the IMPLEMENTATION (what users see). Include a Note explaining the discrepancy with source code citation.

**Cross-Entity Verification:**
If the feature operates on a per-entity basis (per-cluster, per-namespace, per-node, per-resource), include at least one step that validates behavior on a DIFFERENT entity of the same type. This catches hardcoded names, filtering logic, and cache/state leakage.

**Test Design Optimization (5 passes, apply in order):**

1. **State Transition Consolidation:** When scenarios differ only by state (before/after, enabled/disabled, with/without a property), use ONE entity: test initial state → modify → test changed state. Never create two separate entities when one can serve both.
2. **Resource Minimization:** For each resource in Setup: is it consumed by a step? Can two resources be replaced by one used at different points? Target the minimum set.
3. **Step Flow Sequencing:** Order steps as observe → act → verify → act → verify. Start read-only, progress to state-changing, end with most complex.
4. **Deduplication:** Merge steps that verify the same behavior in the same context. Keep both only if they test different entry points/routes.
5. **Negative Scenario Placement:** Place the negative case (feature NOT visible) FIRST if it needs no special setup. Place after the positive flow if it requires setup (e.g., different user login).

After optimization, record: which passes changed the plan, resource count (reduced from raw plan), and any consolidations applied.

**Coverage Gap Triage (after building the test plan):**
If the Code Change Analyzer output includes a "Coverage Gaps" section (code paths not covered by any acceptance criterion), triage each gap:
- **ADD TO TEST PLAN:** User-visible behavior worth testing -- add a step or extend an expected result.
- **NOTE ONLY:** Real behavior but too minor for a dedicated step -- mention in Notes.
- **SKIP:** Internal/defensive code, not testable via UI.
Include the triage summary in the synthesized plan with format: `GAP-N: [description] → ADD/NOTE/SKIP (reason)`.

---

## Phase 3: Live Validation (if environment available)

**Cursor Subagent:** `live-validator`

Provide: console URL, feature path, steps to verify.

The validator will:
- Navigate to the feature page via browser MCP
- Test the feature flow (click through, fill forms, verify results)
- Check backend state via oc CLI
- Check for JavaScript errors
- Take screenshots at key verification points
- Return: confirmed UI behavior, discrepancies, screenshots

If no environment is available, proceed with source-code-based writing and note that live validation was not performed.

---

## Phase 4: Write Test Case

Write the test case markdown following [test-case-conventions.md](test-case-conventions.md).

**Key rules:**
- Title follows area naming pattern: `# RHACM4K-XXXXX - [Tag-X.XX] Area - Test Name`
- All Polarion metadata fields are present
- Description includes Entry Point (discovered, not assumed) and Dev JIRA Coverage
- Setup has numbered bash commands with expected output
- Test steps are UI-focused with clear actions and expected results
- CLI is allowed mid-test ONLY for backend validation (resource YAML, config state) -- not as a substitute for Search UI unless the test is not about Search
- Teardown cleans up all created resources
- Expected results reference discovered UI text (from translations or source code)

**File location:** `documentation/acm-components/virt/test-cases/{version}/RHACM4K-{ID}-{Feature-Description}.md`

---

## Phase 4.5: Test Case Review

**Cursor Subagent:** `testcase-reviewer`

Provide: path to the generated test case file, area, version.

The reviewer checks:
- Metadata completeness (all Polarion fields, correct release version)
- Description quality (entry point discovered, JIRA coverage listed)
- Test step quality (UI elements discovered not assumed, CLI-in-steps rule respected)
- Consistency with existing test cases in the same area
- Setup/teardown completeness
- Polarion HTML format (if HTML was generated)

**If blocking issues found:** Fix them and re-run the reviewer. Loop until pass.

---

## Phase 5: Output

### Markdown Output (default)
Deliver the `.md` file at the test case file location.

### Polarion HTML Output (on request)
When user asks "generate HTML" or "print HTML", convert the markdown to Polarion-compatible HTML using the fixed templates in [polarion-html-templates.md](polarion-html-templates.md).

Generate two HTML blocks:
1. **Setup section HTML** -- prerequisites, environment, setup commands
2. **Test steps table HTML** -- 2-column table (Step | Expected Result)

### Push to Polarion (on request)
When the user asks to "push to Polarion", "create in Polarion", or "upload the test case", follow the procedure in the `polarion-integration.mdc` rule (section: "Creating Test Cases"). The key points:
- Use `create_polarion_work_item` with `work_item_type="testcase"` (MUST be lowercase)
- Include setup HTML in `additional_fields` as `{"setup": {"type": "text/html", "value": "..."}}`
- Include all custom fields (caseimportance, caselevel, testtype, caseposneg, caseautomation, casecomponent) in `additional_fields`
- POST test steps separately via `update_polarion_test_steps` after creation
- Passcode is `adminATOMS`
- NEVER rely on PATCH (403 forbidden) -- get everything right on creation

---

## MCP and CLI Tool Reference

### 1. JIRA MCP (`jira`) -- Feature investigation

| Tool | Purpose | Used By |
|------|---------|---------|
| `get_issue(issue_key)` | Full story details, comments, acceptance criteria | Feature Investigator |
| `search_issues(jql)` | Find linked tickets, QE tracking, bugs | Feature Investigator |
| `get_project_components(project_key)` | List project components | Feature Investigator |

Gotchas:
- `get_issue` does NOT return issue links -- use `search_issues` with JQL to find them
- Comment parameter is `comment`, NOT `body`
- Always read ALL comments -- they contain implementation decisions and edge cases

### 2. Polarion MCP (`user-polarion`) -- Existing coverage + push

| Tool | Purpose | Used By |
|------|---------|---------|
| `get_polarion_work_items(project_id, query)` | Search existing test cases | Feature Investigator, Reviewer |
| `get_polarion_work_item(project_id, work_item_id, fields)` | Full test case details | Reviewer |
| `get_polarion_test_steps(project_id, work_item_id)` | Ordered test steps | Reviewer |
| `get_polarion_test_case_summary(project_id, work_item_id)` | Quick summary | Reviewer |
| `get_polarion_setup_html(project_id, work_item_id)` | Setup section HTML | Reviewer |
| `create_polarion_work_item(passcode, project_id, ...)` | Create new test case | Push phase |
| `update_polarion_test_steps(project_id, work_item_id, steps_json)` | POST test steps | Push phase |

Gotchas:
- Project ID is ALWAYS `RHACM4K`
- Query syntax is Lucene, NOT JQL (e.g., `type:testcase AND title:"feature"`)
- `work_item_ids` for batch: comma-separated STRING, not array
- `get_polarion_work_item_text` sometimes returns empty -- use `fields="@all"` instead
- `work_item_type` for creation MUST be `testcase` (lowercase) -- `testCase` breaks test steps
- PATCH operations return 403 -- always get everything right on creation

### 3. ACM Source MCP (`user-acm-source`) -- UI discovery

**CRITICAL: Always set version FIRST before any search/get call.**

```
list_versions()                    # Check which versions map to main (dev)
set_acm_version('2.19')           # Use (main) version for latest dev code
set_cnv_version('4.23')           # Fleet Virt only: use (main) version for dev
list_repos()                      # Verify branches point to main
```

| Tool | Purpose | Used By |
|------|---------|---------|
| `search_code(query, repo, scope)` | Find files by content. scope="all" (GitHub code search, default) or "components" (directory walk) | UI Discovery, Code Analyzer |
| `get_component_source(path, repo)` | Read full source file | UI Discovery, Code Analyzer |
| `search_translations(query, exact)` | Find UI label strings (partial match default; exact=true for exact) | UI Discovery, Reviewer |
| `get_wizard_steps(path, repo)` | Analyze wizard step structure | UI Discovery |
| `get_routes()` | All 112+ ACM navigation routes | UI Discovery, Reviewer |
| `get_acm_selectors(source, component)` | Existing QE selectors | UI Discovery |
| `get_fleet_virt_selectors()` | Fleet Virt Cypress selectors | UI Discovery |
| `find_test_ids(path, repo)` | Extract data-test attributes | UI Discovery |
| `get_patternfly_selectors(component)` | PF6 CSS fallback selectors | UI Discovery |
| `get_component_types(path, repo)` | TypeScript types/interfaces | Code Analyzer |

Repo keys: `acm` (stolostron/console), `kubevirt` (kubevirt-plugin), `acm-e2e` (clc-ui-e2e), `search-e2e`, `app-e2e`, `grc-e2e`

Gotchas:
- MUST call `set_acm_version` BEFORE any search/get -- results depend on the active branch
- QE repos always use `main` branch regardless of version setting
- For Fleet Virt: set BOTH `set_acm_version()` AND `set_cnv_version()` -- they are independent
- `search_translations` is partial match by default -- use `exact=true` for exact matches
- `search_code` returns file PATHS, not content. Use `get_component_source()` to read files.
- Old `search_component` tool is removed. Use `search_code(query, repo, scope="components")` instead.

### 4. Browser MCP (`cursor-ide-browser`) -- Live validation

| Tool | Purpose | Used By |
|------|---------|---------|
| `browser_navigate(url)` | Navigate to ACM console page | Live Validator |
| `browser_snapshot()` | Get accessibility tree (element refs, roles, labels) | Live Validator |
| `browser_click(ref)` | Click element by ref | Live Validator |
| `browser_fill(ref, value)` | Fill input field | Live Validator |
| `browser_take_screenshot()` | Capture current state | Live Validator |
| `browser_console_messages()` | Check for JavaScript errors | Live Validator |
| `browser_network_requests()` | Inspect API calls | Live Validator |

Gotchas:
- MUST `browser_navigate` before `browser_lock`
- Always `browser_snapshot()` before any interaction to get element refs
- Use short waits (1-3s) with snapshot checks, not single long waits
- Iframe content is NOT accessible

### 5. ACM Search MCP (`acm-search`) -- Live cluster resources

| Tool | Purpose | Used By |
|------|---------|---------|
| `find_resources(...)` | Search Kubernetes resources across all managed clusters with filtering, counting, grouping, and health analysis | Live Validator |

Use when: verifying test prerequisites exist on the cluster (namespaces, pods, policies), checking resource counts, or validating expected state before/after test steps.

**Auto-connect**: The MCP auto-connects to the cluster in `~/Documents/work/notes/notes.md` (lines 1-3). If errored, toggle the MCP off/on in Cursor Settings. Fall back to `oc` CLI for simple queries.

### 6. ACM Kubectl MCP (`acm-kubectl`) -- Multicluster operations

| Tool | Purpose | Used By |
|------|---------|---------|
| `clusters()` | List all managed clusters with status | Live Validator |
| `kubectl(command, cluster)` | Run kubectl on hub or spoke cluster | Live Validator |
| `connect_cluster(cluster)` | Generate kubeconfig for managed cluster | Live Validator |

Use when: checking spoke cluster state, verifying managed cluster availability, or running kubectl commands for test setup/validation.

### 7. Neo4j RHACM MCP (`neo4j-rhacm`) -- Architecture

| Tool | Purpose | Used By |
|------|---------|---------|
| `read_neo4j_cypher(query)` | Query ACM component dependencies | Code Analyzer |

```cypher
MATCH (dep)-[:DEPENDS_ON]->(t) WHERE t.label CONTAINS 'component' RETURN dep.label
```

Gotchas:
- Requires Podman with `neo4j-rhacm` container running
- 370 components, 541 relationships (includes Virtualization, MTV, CCLM, Fine-Grained RBAC, Hive, Klusterlet, Addon Framework, HyperShift, Tier 1+2 depth)

### 6. CLI Tools

| Tool | Purpose | Used By |
|------|---------|---------|
| `github` MCP `get_pull_request` or `gh pr view <N> --repo stolostron/console --json title,body,files` | PR metadata | Feature Investigator, Code Analyzer |
| `gh pr diff <N> --repo stolostron/console` | PR code diff | Code Analyzer |
| `oc get <resource> -n <ns> -o yaml` | Check resource state | Live Validator |
| `oc get pods -n open-cluster-management` | ACM health | Live Validator |
| `oc get managedcluster` | Spoke connectivity | Live Validator |
| `oc get mch -A` | MCH health | Live Validator |

### Subagent-to-Tool Matrix

```
Feature Investigator:
  jira      -> get_issue, search_issues
  polarion  -> get_polarion_work_items (check existing coverage)
  gh CLI    -> gh pr view

Code Change Analyzer:
  gh CLI     -> gh pr view, gh pr diff
  acm-source -> search_code, get_component_source, get_component_types
  neo4j      -> read_neo4j_cypher (component dependencies)

UI Discovery (shared):
  acm-source -> set_acm_version, set_cnv_version, search_code, get_component_source,
               search_translations, get_wizard_steps, get_routes, get_acm_selectors,
               get_fleet_virt_selectors, find_test_ids, get_patternfly_selectors

Live Validator:
  browser   -> browser_navigate, browser_snapshot, browser_click, browser_fill,
               browser_take_screenshot, browser_console_messages
  oc CLI    -> oc get pods/csv/mch/managedcluster (environment health)

Testcase Reviewer:
  acm-source -> search_translations, get_routes, get_wizard_steps (verify discovered elements)
  polarion   -> get_polarion_work_item, get_polarion_test_case_summary (verify metadata)
  files      -> read existing test cases for consistency comparison
```

---

## Skill File Structure

```
~/.cursor/skills/write-testcase-console/
  SKILL.md                      # This file (orchestrator)
  test-case-conventions.md      # Format, naming, section structure from 85 existing test cases
  polarion-html-templates.md    # Fixed Polarion HTML templates (setup, steps table, code blocks)

~/.cursor/agents/               # Cursor Subagents (persistent)
  feature-investigator.md       # Phase 1: Deep JIRA investigation
  code-change-analyzer.md       # Phase 1: PR diff and code impact analysis
  ui-discovery.md               # Phase 1: acm-source MCP selectors/routes (shared with automation skill)
  live-validator.md              # Phase 3: Browser + oc CLI live verification
  testcase-reviewer.md          # Phase 4.5: Quality review

Test case output location:
  /Users/ashafi/Documents/work/automation/documentation/acm-components/virt/test-cases/{version}/
```

# Investigate & Learn -- Deep Knowledge Acquisition for Engram

## Trigger
User says: "investigate", "learn about", "update knowledge", "deep dive", "what changed in", or similar research-oriented requests.

## Purpose
Perform targeted, deep investigation using all available MCP servers and store structured findings in engram. Unlike the nightly sweep (broad but shallow), this skill does contextual deep dives with cross-source correlation.

## MANDATORY: Phase Gate Enforcement

### On skill start, create a TodoWrite tracking phases:

```
TodoWrite (merge=false):
  phase-1  | Phase 1: Gather context (parallel MCP queries)      | pending
  phase-2  | Phase 2: Correlate and analyze findings              | pending
  phase-3  | Phase 3: Store in engram                             | pending
  phase-4  | Phase 4: Report to user                              | pending
```

### Gate rules:

1. **Phase 2 MUST complete before Phase 3.** Do not store raw, uncorrelated data in engram.
2. **Phase 3: filter before storing.** Do NOT store raw noise, transient PR state, or temporary CI failures. Only store structured, verified findings.
3. **All phases are sequential** -- do not skip Phase 2 (correlation) and go straight to storing.

---

## ASK QUESTIONS FIRST

Before investigating, clarify:
1. **What area?** (RBAC, Fleet Virt, Search, GRC, Clusters, Console-wide, or specific ticket/PR)
2. **What scope?** (last 24h, last week, specific sprint, specific feature)
3. **What depth?** (quick summary vs full investigation with cross-referencing)

If the user provides a specific ticket (ACM-*), PR URL, or feature name, skip questions and start investigating.

## Investigation Workflow

### Phase 1: Gather Context from Multiple Sources (Parallel)

**Knowledge DB lookup (FIRST)**: Before querying external sources, search `acm-knowledge` MCP with `search_knowledge(query=<investigation topic>)` to find existing architecture docs, failure signatures, known issues, and data-flow descriptions. Also read directly from `/Users/ashafi/Documents/work/notes/knowledge/`:
- `architecture/<subsystem>/architecture.md` -- existing architectural knowledge
- `failures/<subsystem>/failure-signatures.md` -- known failure patterns
- `health/<subsystem>/known-issues.md` -- documented health issues
- `ui/<area>.md` -- UI behavior documentation

This prevents re-investigating topics already documented in the KB and provides a baseline to compare new findings against.

Use available MCPs to gather data from multiple sources simultaneously:

**JIRA (user-jira MCP)**
- `search_issues` with JQL for the target area
- `get_issue` for specific tickets (full details, comments, linked issues)
- Look for: status changes, new requirements, bug resolutions, blockers

**GitHub (gh CLI via Shell)**
- `gh pr list --repo <repo> --state merged` for recent merged PRs
- `gh pr view <number> --repo <repo>` for full PR details and diff
- Look for: selector changes, API changes, component renames, new routes

**Polarion (user-polarion MCP)**
- `get_polarion_work_item` for test case details
- `search_polarion_work_items` for area-specific test cases
- Look for: new test requirements, updated acceptance criteria

**Neo4j Knowledge Graph (user-neo4j-rhacm MCP)**
- `read_neo4j_cypher` for dependency queries
- Look for: architectural impacts, dependency chains, what breaks if X changes

**ACM Source (user-acm-source MCP)**
- `search_code` for selector and component queries
- `find_test_ids` for data-testid attributes
- `get_component_source` for actual component implementation
- Remember: set version first with `set_acm_version`

**ACM Search (user-acm-search MCP)** -- Live cluster resource queries
- `find_resources` for searching Kubernetes resources across all managed clusters (supports filtering by kind, name, namespace, cluster, status, labels; output modes: list, count, summary, health; grouping by cluster/namespace/status)
- Use when: verifying live cluster state, checking if resources exist, correlating runtime vs design-time
- **Auto-connect**: Reads cluster from `~/Documents/work/notes/notes.md` (lines 1-3). If errored, toggle MCP off/on in Cursor Settings. Fall back to `oc` CLI for simple queries.

**ACM Kubectl (user-acm-kubectl MCP)** -- Multicluster operations
- `clusters` to list all managed clusters with status
- `kubectl` to run kubectl commands on hub or spoke clusters
- `connect_cluster` to generate kubeconfig for a managed cluster
- Use when: checking spoke cluster state, verifying managed cluster health

### Phase 2: Cross-Source Correlation

After gathering data, correlate across sources:
- JIRA ticket mentions a new feature -> Check GitHub for the implementing PR -> Check ACM-UI for new selectors -> Verify test coverage in Polarion
- GitHub PR changes selectors -> Check if existing Cypress/Playwright tests reference old selectors -> Flag as automation impact
- Bug resolution in JIRA -> Check if the fix PR is merged -> Check if regression test exists

### Phase 3: Store Findings in Engram

For each significant finding, store in engram with rich metadata:

```
engram_remember({
  content: "Clear, standalone statement of the knowledge",
  // Include: what changed, why, impact on automation, source references
})
```

**What to store:**
- Architectural changes with impact analysis
- New selectors/test-ids with their component locations
- Bug root causes and their fix details
- Feature scope changes with JIRA references
- Cross-source correlations (e.g., "PR #1234 in console implements ACM-29080, adding new RBAC wizard step with data-testid='rbac-scope-selector'")

**What NOT to store:**
- Raw ticket metadata (status, assignee) without context
- Obvious information already in the ticket title
- Temporary states ("PR is in review" -- will change)

### Phase 4: Report to User

Present findings as a structured summary:
1. Key changes found (with source links)
2. Impact on test automation
3. Knowledge gaps identified (what needs manual verification)
4. Memories stored in engram (count and highlights)

## Nightly Sweep Integration

Check `~/.engram/last_sweep_state.json` to see what the nightly sweep already found.
Read `~/.engram/logs/sweep-*.log` for the latest sweep results.
Focus the investigation on areas the sweep flagged but couldn't deep-dive into.

## Example Usage

**User**: "Investigate what changed in RBAC this week"

**Agent**:
1. JIRA: Search `project = ACM AND labels = acmrbac AND updated >= -7d`
2. GitHub: Check merged PRs in `stolostron/console` touching `routes/Infrastructure/Clusters`
3. ACM-UI: `search_code("MulticlusterRoleAssignment", repo="acm")` for new selectors
4. Neo4j: Query RBAC dependency chain
5. Correlate: Match PRs to JIRA tickets, identify selector changes
6. Store: 5-10 structured memories in engram
7. Report: Summary with links and automation impact

**User**: "Learn about ACM-29080"

**Agent**:
1. JIRA: `get_issue("ACM-29080")` -- full details, all comments, linked tickets
2. Find implementing PR from JIRA comments or GitHub search
3. ACM-UI: Check selectors in the changed components
4. Store: Feature scope, acceptance criteria, selectors, architectural notes
5. Report: Complete feature understanding

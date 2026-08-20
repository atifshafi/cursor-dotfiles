---
name: acm-bug-hunter
description: >-
  Autonomously hunts for bugs in ACM feature implementations by using test cases
  as a starting point for systematic 10-dimension investigation. Spawns focused
  subagents per dimension with an orchestrator-investigator adversarial architecture
  to prevent self-bias. Uses confidence-aware feedback loops inspired by the
  "confession" pattern. Supports all ACM areas (Console, GRC, ALC, Observability,
  Cluster Lifecycle, Submariner, Search, Install). Works with or without a live
  cluster (graceful degradation). Input: Polarion test case ID, local .md file,
  or inline test case content.
---

# ACM Bug Hunter

Use a test case to systematically investigate whether the implemented feature has bugs the test case might miss. Hunts across 10 dimensions of implementation correctness.

## ASK QUESTIONS FIRST

| Category | Questions to Ask |
|----------|------------------|
| **Test Case** | "What test case? (Polarion ID, file path, or paste it)" |
| **ACM Version** | "Which ACM version? (e.g., 2.16, 2.17)" |
| **Environment** | "Is a live cluster available? (hub console URL, or 'no cluster')" |
| **Focus** | "Any specific concern to investigate? (or 'full audit')" |

---

## Phase Gate Enforcement

Create TodoWrite with phases: `phase-0` (Parse), `phase-1` (Context), `phase-2` (Investigation), `phase-3` (Docs research), `phase-4` (Synthesis), `phase-5` (Deliver).

Gate rules: (1) Cannot mark complete without executing. (2) Phase 2 is core -- do NOT rush. (3) Phase 3 fires ONLY for specific unresolved questions. (4) Phase 4 MUST complete before Phase 5.

---

## Phase 0: Parse Input, Detect Area, Adapt

1. **Read test case**: Polarion ID -> `get_polarion_work_item` + `get_polarion_test_steps` (project `RHACM4K`). Local file -> read. Inline -> parse.
2. **Extract metadata**: JIRA ticket, PR number, ACM version, test steps/expected results, setup requirements.
3. **Detect feature area** from JIRA components, tags, path, or keywords. Map to: `console-rbac` | `console-general` | `fleet-virt` | `clusters` | `grc` | `alc` | `search` | `observability` | `submariner` | `install` | `hosted-clusters` | `other`
4. **Dimension priority** by area:
   - `console-rbac` -> Dim 3 + Dim 10 get up to 6 questions
   - `grc` -> Dim 4 + Dim 7 get up to 6 questions
   - `alc` -> Dim 2 + Dim 4 get up to 6 questions
   - `observability` -> Dim 5 + Dim 6 get up to 6 questions
   - Other: orchestrator decides dynamically
5. **Check environment**: If cluster URL -> verify deployment (`oc get csv -n open-cluster-management`), check acm-search connection (`notes/notes.md` line 2), run `find_resources(outputMode="health")` for baseline. No cluster -> source-code-only mode.
6. **Architectural context**: `read_neo4j_cypher("MATCH (c)-[:BELONGS_TO]->(s) WHERE s.label CONTAINS '<area>' RETURN c.label, c.type")`

---

## Phase 1: Deep Context Gathering

Launch subagents in parallel. Also search `acm-knowledge` MCP (`search_knowledge`) and read knowledge DB files (`failures/`, `architecture/`, `health/` for the target subsystem).

**Subagent A -- Feature Investigator** (`feature-investigator`): Provide JIRA key. Returns full story, ALL comments, acceptance criteria, linked tickets, PRs.

**Subagent B -- Code Change Analyzer** (`code-change-analyzer`): Provide PR number + repo name. Returns code diff analysis (UI + backend for console; controller/CRD/webhook for non-console).

**Subagent C -- UI Discovery** (`ui-discovery`, console/UI areas only): Provide ACM version, CNV version (if Fleet Virt), feature name, area. Returns selectors, routes, translations, wizard structure.

**Inline docs lookup**: `gh search code "<feature keyword>" --repo stolostron/rhacm-docs --ref <version>_stage`

---

## Phase 2: Dimension Investigation (Subagent Loop)

Read [analysis-dimensions.md](references/analysis-dimensions.md) for the full 10-dimension model.

### Orchestrator-Investigator Architecture

Two roles prevent self-bias:
- **Orchestrator** (this agent) = lead/skeptic. Holds Phase 1 context. Evaluates findings, catches false negatives/positives.
- **Dimension subagent** = focused engineer. Gets a targeted brief for ONE dimension. Fresh context. Returns findings + confidence report.

Read [confidence-mechanism.md](references/confidence-mechanism.md) for confidence scoring specification.

### Per-Dimension Flow

For each applicable dimension (1-10):

**Step 0 -- Applicability Check** (inline): Check matrix in analysis-dimensions.md. Skip with note if not applicable.

**Step 1 -- Brief Preparation** (inline): Prepare brief with test case content, Phase 1 context (filtered to this dimension), 1-6 critical questions (per Phase 0 priority), feature area, available MCP tools with usage instructions. Include: "Return both Investigation Findings AND Confidence Report."

**Step 2 -- Spawn Subagent**: Launch `generalPurpose` subagent with brief. Returns structured findings with evidence + Confidence Report (evidence inventory + self-assessed score + uncertainties + single easiest item to verify).

**Step 3 -- Evaluate and Classify** (inline): Check Evidence Inventory, spot-check "Single Easiest Item to Verify", then apply classification tree:

```
CLEAN + thorough evidence     -> Accept. Move on.
CLEAN + shallow evidence      -> PUSHBACK: specify missing checks.
POTENTIAL_BUG + strong evidence -> Spot-check via different path.
                                  Corroborated -> CONFIRMED_BUG.
                                  Not reproducible -> keep POTENTIAL_BUG.
POTENTIAL_BUG + weak evidence -> PUSHBACK: request harder proof.
CONFIRMED_BUG                 -> ALWAYS corroborate via different
                                  evidence path. If contradicted ->
                                  downgrade, pushback.
```

For full evaluation cases (thorough+high, shallow+any, thorough+low, spot-check calibration) and pushback mechanics (resume SAME subagent, max 3 rounds), see [confidence-mechanism.md](references/confidence-mechanism.md).

**Step 4 -- Fresh Subagent** (if unresolved after 3 pushback rounds): Spawn FRESH `generalPurpose` subagent with original brief + orchestrator's objections/counter-evidence + NO prior subagent reasoning (unbiased second opinion). Also max 3 rounds. Compare both subagents' evidence inventories: stronger evidence wins; if tied -> POTENTIAL_BUG with both perspectives.

**Step 5 -- Record** final classification + evidence trail.

### No-Cluster Adjustments

When no live cluster is available:
- Accept lower evidence inventory scores (API/CLI verified = NO is expected)
- Do not drill more than 2 rounds per dimension
- Backend logic bugs CAN reach CONFIRMED_BUG from source code alone
- UI bugs are capped at POTENTIAL_BUG (cannot confirm without live validation)
- Dimension 6.4 (probe creation) is skipped entirely
- Dimensions 6.1-6.3 can still run from source code and Neo4j

---

## Phase 3: Internal Documentation Research (Conditional)

Fires ONLY for specific unresolved questions from Phase 2. Sources: (1) `stolostron/rhacm-docs` (branch per version), (2) component source repos, (3) Neo4j RHACM, (4) local docs at `documentation/architecture/rhacm-docs/`. No external web search.

---

## Phase 4: Cross-Dimension Synthesis

Consolidate findings, check for cross-dimension root causes, prioritize (CONFIRMED_BUG > POTENTIAL_BUG > GAP), generate report per [report-template.md](references/report-template.md).

---

## Phase 5: Deliver to User

Present report highlighting: confirmed/potential bug counts, evidence per finding, clean dimensions, skipped dimensions.

---

## MCP Reference

**acm-source** (`user-acm-source`): MUST call `set_acm_version(version)` before any other acm-source tool.

**acm-search** (`acm-search`): Verify cluster match (`notes/notes.md` line 2) before calling. Per-dimension patterns:
- Dim 4 (Multicluster): `find_resources(kind="ManagedClusterAddon", name="<addon>", outputMode="list")` -- addon propagation; `find_resources(kind="ManifestWork", namespace="<cluster-ns>", outputMode="count")` -- work distribution
- Dim 6.2 (Dependency Health): `find_resources(kind="ClusterServiceVersion", outputMode="health")` -- operator health; `find_resources(kind="Pod", status="CrashLoopBackOff,Error", groupBy="cluster")` -- failing pods
- Phase 0 (Environment): `find_resources(outputMode="health")` -- fleet baseline

If 0 results and known resources should exist, verify with `oc get` (possible index staleness).

**Other servers**: `user-jira`, `user-polarion`, `neo4j-rhacm`, `acm-kubectl` -- use standard MCP tool interfaces.

**CLI**: `gh pr view/diff`, `gh search code`, `oc get/describe`, `oc auth can-i`, `oc apply --dry-run=server` (Dim 6 only).

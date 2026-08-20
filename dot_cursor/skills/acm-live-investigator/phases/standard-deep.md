# Phases 2-6: Standard and Deep Investigation

Loaded for Standard, Deep, and Targeted depths. Quick depth does NOT read this file.

## Phase 2: Learn (Standard+)

Read knowledge files for context. Spawn an `explore` subagent (`model: "composer-2.5"`) to read in parallel while processing Phase 1 output:
1. `${KNOWLEDGE}/baselines/component-registry.md`
2. `${KNOWLEDGE}/architecture/acm-platform.md` (if exists)
3. For affected subsystems: `${KNOWLEDGE}/architecture/<subsystem>/architecture.md`
4. `${KNOWLEDGE}/diagnostics/diagnostic-traps.md` (or read [../references/diagnostic-traps.md](../references/diagnostic-traps.md))
5. `${KNOWLEDGE}/diagnostics/diagnostic-layers.md`

Where `KNOWLEDGE = /Users/ashafi/Documents/work/notes/knowledge/`

If knowledge files are missing, proceed with best-effort analysis using the references/ in this skill.

## Phase 3: Check (Standard+)

Bottom-up 12-layer health verification. Read [../references/diagnostic-layers.md](../references/diagnostic-layers.md) for full per-layer commands.

**Check order:**
1. **Foundational (L1-3):** Nodes Ready? OCP operators Available? NetworkPolicies or ResourceQuotas in ACM namespaces?
2. **Storage (L4):** PVCs Bound? search-postgres data integrity? (`SELECT count(*) FROM search.resources`)
3. **Configuration (L5):** MCH component toggles, OLM subscriptions, CatalogSources
4. **Component (L6-9):** Pod health across MCH/MCE/hive namespaces vs baselines. Restart counts >3 flagged.
5. **Cross-cluster (L10):** ManagedCluster status, addon health (`oc get managedclusteraddons -A`)
6. **Application (L11-12):** Only if lower layers healthy. Console plugins, data flow, search-api.

Walk through ALL 14 traps from [../references/diagnostic-traps.md](../references/diagnostic-traps.md).

## JIRA Bug Check (Phase 3 to Phase 4 Bridge)

Fires only when Phase 3 confirms something is genuinely broken with concrete evidence.

**Trigger criteria (ALL must be true):**

| Criterion | Required |
|---|---|
| Specific component name identified | Yes |
| Unhealthy confirmed via `oc` output | Yes |
| NOT explained by a known trap | Yes |
| Searchable symptom (error message, status condition) | Yes |

**Do NOT search JIRA for:** pods in ContainerCreating, MCH Pending without specific component, restart count 1-3, anything without Tier 1 evidence.

**When criteria met:**
```
jira MCP: search_issues(jql="project = ACM AND status != Closed AND text ~ '<component> <error-keyword>'", max_results=5)
```

**Match found:** Report as `[KNOWN BUG] <JIRA-ID>: <summary>. Status: <status>. Fix version: <version>.` Stop root-cause analysis for this issue. Note if fix version already deployed (possible regression).

**No match found:**
1. Continue through Phase 4 to rule out known issues
2. If still unexplained after Phase 4: escalate to Deep investigation on the affected component
3. Collect: exact error messages (`oc logs --tail=50` + `--previous`), timeline (pod age, event timestamps), reproduction conditions, version info (ACM/MCE/OCP + image tags), related resources (CRD status, owning operator, upstream deps)
4. Determine: confirmed broken (high confidence) / possibly broken (medium, report with caveats) / environment-specific (infra issue with fix)
5. Re-search JIRA with refined root-cause keywords

## Phase 4: Pattern Match (Standard+)

Cross-reference findings against known issues:
1. Read `${KNOWLEDGE}/health/failure-patterns.md`
2. Read `${KNOWLEDGE}/health/<subsystem>/known-issues.md` for each affected subsystem
3. Check for version-specific incompatibilities

Note JIRA references, fix versions, and cluster-fixability for matched patterns.

## Phase 5: Correlate (Deep Only)

Trace dependency chains when multiple issues found:
1. Read [../references/dependency-chains.md](../references/dependency-chains.md) (12 chains)
2. For each chain: check each link against Phase 3 findings
3. If `neo4j-rhacm` MCP available: query for dependencies not in static chains
4. Weight evidence per [../references/evidence-tiers.md](../references/evidence-tiers.md)
5. Verify conclusions against trap list (avoid false attributions)

## Phase 6: Deep Investigate (Deep/Targeted)

For CRITICAL findings or targeted investigations:
```bash
oc logs <pod> --tail=100
oc logs <pod> --previous
oc get events -n <ns> --sort-by=.lastTimestamp
oc describe <resource>
```

Read the subsystem's `data-flow.md` from knowledge DB to trace where flow breaks.

**acm-search MCP** (`user-acm-search`) -- use only if search-postgres is healthy (Phase 3 L4):

| Use Case | Example |
|---|---|
| Addon pods on ALL spokes | `find_resources(kind="Pod", labelSelector="app=search-collector", cluster="*")` |
| Fleet-wide resource counts | `find_resources(outputMode="count", groupBy="cluster")` |
| Failing pods fleet-wide | `find_resources(kind="Pod", status="Failed,Error,CrashLoopBackOff", limit=10)` |

Do NOT use acm-search when: search-postgres is unhealthy, simple single-namespace queries, hub-only resources. If MCP shows "Error", inform user to toggle it off/on in Settings > MCPs.

## Subagent Strategy

| Subagent Type | When | Phase | Model |
|---|---|---|---|
| `explore` | Knowledge DB file reading in parallel | Phase 2 | `composer-2.5` |
| `failure-debugger` | Test failure triggered this investigation | Phase 6 | `inherit` |
| `ci-investigator` | Jenkins CI check failure triggered this | Phase 6 | `inherit` |
| `live-validator` | UI/console accessibility needs verification | Phase 3 L12 | `inherit` |
| `generalPurpose` | Per-subsystem deep investigation | Phase 6 | `inherit` |

**Depth limits:** Quick=0, Standard=max 2, Deep=max 4, Targeted=appropriate specialized subagent.
Include safety rules (read-only) and cluster context (KUBECONFIG, MCH namespace, server URL) in every subagent prompt. Subagents do NOT read this skill file -- they receive instructions inline.

## MCP & Tool Reference

| MCP Server | Used In | Fallback |
|---|---|---|
| `user-acm-kubectl` | Phase 1 (multi-cluster) | Shell `oc` directly |
| `user-acm-search` | Phase 5-6 (fleet queries) | Skip spoke-side verification, note "reduced confidence" |
| `user-neo4j-rhacm` | Phase 5 (dependency graph) | Read references/dependency-chains.md (static) |
| `user-acm-source` | Phase 6 (source tracing) | Skip source-level tracing, runtime evidence only |
| `user-engram` | Post-diagnosis (store learnings) | Skip memory storage |

Never BLOCK diagnosis on an MCP failure. Use fallback and note "[reduced: server unavailable]" in evidence. If `user-acm-search` is available but search-postgres is unhealthy, do NOT use it.

When investigating a CI/test environment, also read [../references/ci-environment-checks.md](../references/ci-environment-checks.md).

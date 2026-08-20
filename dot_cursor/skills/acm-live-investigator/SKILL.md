---
name: acm-live-investigator
description: >-
  Diagnoses live ACM hub cluster health using a 6-phase pipeline, 12-layer
  diagnostic model, and 14 trap patterns. Auto-invokes when the agent encounters
  cluster connectivity failures, pod crashes, route timeouts, or correlated
  multi-test failures. Also invoked explicitly with "health check", "diagnose",
  "investigate environment", "cluster broken", "why is X failing", "check my hub",
  "environment not working". Do NOT use for single test failures with selector
  errors (use failure-debugger), code review, or non-cluster issues.
metadata:
  author: acm-qe
  version: "1.1.0"
---

# ACM Live Investigator

Diagnoses live ACM hub cluster health at 4 depth levels. Produces structured findings with evidence-based root causes. Strictly read-only -- never modifies the cluster.

**Knowledge DB:** `/Users/ashafi/Documents/work/notes/knowledge/`

## Auto-Invoke Triggers

**Positive (auto-invoke at Quick):** connection refused/timeout, pods CrashLoopBackOff/ImagePullBackOff/Pending, test logs with EHOSTUNREACH/cert expired/unauthorized, route 502/503, Jenkins cluster errors, multiple unrelated tests failing simultaneously.
**Negative (do NOT invoke):** single selector/assertion error, writing code (not executing), no KUBECONFIG, application-logic errors (TypeError/syntax), plan/ask mode.

## Entry Paths

**Auto-invoke:** Do NOT ask questions. Use existing KUBECONFIG, Quick depth, proceed to pre-flight then Phase 1. Report inline.
**Explicit:** Ask only if unclear: which cluster (default: current), depth (default: Standard), specific area (default: full scan).

## Pre-Flight: Cluster Context Verification

Run before Phase 1 (~5 seconds):
```bash
oc whoami --show-server        # Verify cluster reachable (timeout 10s)
oc get mch -A --no-headers     # Verify this is an ACM hub
```
- KUBECONFIG set by parent agent → use it (do NOT create a new one)
- KUBECONFIG not set but `~/.kube/config` exists → ask user which cluster
- Multiple kubeconfigs in session → ask user to confirm target
- Cluster unreachable → report CRITICAL immediately, do NOT proceed
- No MCH found → STOP (not an ACM hub)

Record cluster identity: server URL + `oc get clusterversion -o jsonpath='{.items[0].spec.clusterID}'`

**Rule:** This skill NEVER creates or modifies kubeconfig files.

## Depth Router

| User Intent | Depth | Phases | Duration |
|---|---|---|---|
| Auto-invoke, "quick check", "is my hub alive" | Quick | Phase 1 only | ~30s |
| "Health check", "how's my hub", "check cluster" | Standard | Phases 1-4 | ~2-3 min |
| "Deep audit", "thorough check", "full diagnostic" | Deep | All 6 phases | ~5-10 min |
| "Why are clusters Unknown?", "investigate search" | Targeted | Full depth on specific area | ~3-5 min |

Default to Standard when intent is unclear.

**For Standard/Deep/Targeted:** Read [phases/standard-deep.md](phases/standard-deep.md) for Phases 2-6, JIRA checks, subagent strategy, and MCP reference.

**Escalation (Quick to Standard):** Upgrade from Quick inline to Standard standalone when: (1) inline verdict is CRITICAL and blocks the parent task, (2) user asks for more ("tell me more", "full report", "what's wrong"), or (3) more than 2 DEGRADED findings accumulate in one session. When escalating, re-run at Standard depth minimum.

## Phase 1: Discover (All Depths)

Inventory what's deployed. Run these commands:
```bash
oc get mch -A -o yaml
oc get multiclusterengines -A -o yaml
oc get nodes --no-headers
oc get clusterversion
oc get managedclusters --no-headers
oc whoami --show-server
```

**Critical:** Discover MCH namespace from the MCH resource. NEVER hardcode `open-cluster-management`.

**Operator health** (immediately after MCH discovery):
```bash
oc get deploy multiclusterhub-operator -n $MCH_NS --no-headers
oc get deploy multicluster-engine-operator -n multicluster-engine --no-headers
```

If multiclusterhub-operator has 0 replicas: **CRITICAL immediately**. MCH `.status.phase: Running` is stale (Trap 1). This takes priority over all other findings.

**For Quick depth: STOP HERE.** Report MCH/MCE status, node count, managed cluster count, operator health. Verdict: HEALTHY/DEGRADED/CRITICAL.

**Knowledge DB lookup** (Standard+ only): Search `acm-knowledge` MCP with `search_knowledge(query=<symptom or component>)` to find relevant diagnostics, failure signatures, and known issues. Also read these files directly if the MCP is unavailable:
- `diagnostics/diagnostic-layers.md` -- 12-layer diagnostic model
- `diagnostics/diagnostic-traps.md` -- common investigation pitfalls
- `health/<subsystem>/known-issues.md` -- known issues for the affected subsystem
- `failures/<subsystem>/failure-signatures.md` -- failure classification patterns

## Safety Rules

ALL operations are strictly **read-only** during diagnosis.
**Allowed:** `oc get`, `oc describe`, `oc logs`, `oc exec` (read-only), `oc adm top`, `oc whoami`, `oc auth can-i`, `oc get events`
**Forbidden:** `oc apply`, `oc create`, `oc delete`, `oc patch`, `oc scale`, `oc edit`, `oc annotate`, `oc label`, `oc rollout restart`
If remediation is needed, inform the user of what needs fixing and ask before taking action.

## Report Format

**Verdict (mechanical):** HEALTHY (all OK), DEGRADED (any WARN, no CRIT), CRITICAL (any CRIT).
**Inline (auto-invoke):** `[HEALTH: <VERDICT>] Hub <server-url> -- <1-line summary>. <action>.` Then continue parent task.
**Standalone:** Use format from [references/report-template.md](references/report-template.md). Each finding has 9 required fields (What, Evidence, Root Cause, Layer, Known Issue, Fix Version, Cluster-Fixable, Impact, Recommended Action).

## Output Efficiency

- **Quick/inline:** Report in 1 line per the inline format. Do not explain methodology.
- **Standalone:** Use the structured report format from `report-template.md`. Report findings only, do not narrate the investigation process.

## Gotchas

Top traps that cause misdiagnosis. Read [references/diagnostic-traps.md](references/diagnostic-traps.md) for all 14 traps with detection commands.

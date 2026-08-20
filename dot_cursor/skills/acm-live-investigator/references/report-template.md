# Report Output Format

Two report modes for different invocation contexts. The agent selects the mode automatically based on how the investigation was triggered.

---

## Mode Selection

| Trigger | Mode | Rationale |
|---|---|---|
| User explicitly asked: "health check", "diagnose", "check my hub" | **Standalone** | User expects a full report as the primary deliverable |
| User asked: "deep audit", "full diagnostic", "thorough check" | **Standalone** | Full depth, full report |
| Auto-invoked mid-task (positive signal detected) | **Inline** | Don't derail the user's primary task |
| Auto-invoked Quick check found no issues | **Inline** | Brief "all clear" and continue |
| Auto-invoked Quick check found CRITICAL issues | **Inline** initially, then offer Standalone | Alert immediately, let user decide depth |
| Targeted investigation ("why is search broken?") | **Standalone** | User wants focused depth on a specific area |

---

## Mode 1: Standalone Report

Use when the health check is the primary task. Full structured output.

```markdown
# ACM Hub Health Report

## Cluster Identity
- **Server:** <URL from `oc whoami --show-server`>
- **Cluster ID:** <from `oc get clusterversion -o jsonpath='{.items[0].spec.clusterID}'`>
- **ACM Version:** <from MCH status or CSV>
- **OCP Version:** <from `oc get clusterversion`>
- **Managed Clusters:** <count from `oc get managedclusters --no-headers | wc -l`>
- **Depth:** <Quick | Standard | Deep | Targeted>

---

## Verdict: [HEALTHY | DEGRADED | CRITICAL]

<1-2 sentence summary of overall cluster state.>

---

## Findings

### [CRIT] <title>

1. **What:** <Clear description of the problem>
2. **Evidence:**
   - [Tier 1] <source>: <observation>
   - [Tier 2] <source>: <supporting evidence>
3. **Root Cause:** <assessment> (confidence: X%)
4. **Layer:** <1-12> (<layer name>)
5. **Known Issue:** <JIRA-ID with summary> or "No match"
6. **Fix Version:** <ACM X.Y.Z> or "N/A"
7. **Cluster-Fixable:** <Yes: <how> | Workaround: <steps> | No: <why>>
8. **Impact:** <affected features, tests, or user-facing functionality>
9. **Recommended Action:** <specific next step>

### [WARN] <title>

1. **What:** ...
2. **Evidence:** ...
   <same 9-field structure>

### [INFO] <title>

1. **What:** ...
   <same 9-field structure, used for notable observations that aren't problems>

```

Include these sections in the report (agent creates tables from trap list, findings, and execution data):
- **Traps Checked:** Table with columns: #, Trap, Status (TRIGGERED / NOT triggered / N/A). One row per trap.
- **Subsystem Health Summary:** Table with columns: Subsystem, Status (OK/WARN/CRIT/DEGRADED/N/A/UNKNOWN), Notes.
- **Layers Checked:** Table with columns: Layer, Status, Duration.

### Standalone Report Rules

1. **Findings are ordered by severity:** CRIT first, then WARN, then INFO
2. **Every finding has all 9 fields.** No exceptions, no shortcuts.
3. **Evidence must include tier labels.** Every evidence item tagged `[Tier 1]`, `[Tier 2]`, or `[Tier 3]`.
4. **Traps section is always present** for Standard+ depth. Mark each as `TRIGGERED`, `NOT triggered`, or `N/A`.
5. **Subsystem summary uses only:** `OK`, `WARN`, `CRIT`, `DEGRADED`, `N/A` (not deployed), `UNKNOWN` (couldn't check).
6. **Layers Checked section** shows what was actually checked and timing. Useful for audit trail.

---

## Mode 2: Inline Report

Use when the health check was auto-invoked during another task. One line. Do not derail the user's workflow.

### Format

```
[HEALTH: <VERDICT>] Hub <server-url> -- <1-line summary>. <action>.
```

### Example

```
[HEALTH: CRITICAL] Hub api.bm12.dev.red-chesterfield.com:6443 -- multiclusterhub-operator at 0 replicas, MCH status is stale. Hub is non-functional. Run `oc scale deploy multiclusterhub-operator -n open-cluster-management --replicas=1` to restore.
```

### Inline Report Rules

1. **Always include the server URL** (identifies which cluster if multiple are in play)
2. **Summary is 1 sentence** describing the most important finding
3. **Action is 1 sentence** -- what the agent will do or what the user should do
4. **After inline report, continue the parent task.** Do not pause for acknowledgment unless CRITICAL.
5. **Offer expansion:** If DEGRADED or CRITICAL, end with "Run a full health check for details." or similar

---

## Verdict Decision Logic

```
IF any finding is CRIT:
    verdict = CRITICAL
ELSE IF any finding is WARN or DEGRADED:
    verdict = DEGRADED
ELSE:
    verdict = HEALTHY
```

Verdicts are mechanical. Do not editorialize -- a single CRIT pod makes the verdict CRITICAL even if everything else is perfect. The findings section provides nuance.

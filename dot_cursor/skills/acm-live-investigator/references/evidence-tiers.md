# Evidence Tier Framework

Structured evidence classification for ACM hub health diagnosis. Every conclusion requires evidence from multiple sources with explicit tier labeling.

---

## Tier Definitions

### Tier 1: Definitive (weight 1.0)

Direct observation from primary sources. The evidence speaks for itself.

| Source | Examples |
|---|---|
| `oc` command output | `oc get pods` showing CrashLoopBackOff, `oc get nodes` showing NotReady |
| Pod status/phase | Explicit pod state: Pending, Error, ImagePullBackOff |
| Log error messages | `oc logs <pod>` showing stack traces, panic, fatal errors |
| HTTP status codes | curl returning 503, 502, connection refused |
| Event messages | `oc get events` showing FailedScheduling, BackOff, Unhealthy |
| MCP search results | `acm-search` returning empty for resources that should exist |
| Command exit codes | `oc exec` failing with specific error codes |
| Resource spec/status | `oc get <resource> -o yaml` showing explicit field values |

### Tier 2: Strong (weight 0.5)

Indirect evidence that supports a conclusion but doesn't prove it alone.

| Source | Examples |
|---|---|
| Knowledge graph dependency | `neo4j-rhacm` showing component X depends on component Y (which is down) |
| JIRA correlation | Known bug matching observed symptoms + affected version |
| Known issue match | Pattern from `known-issues.md` matching observed behavior |
| High restart count | Pod restart count > 3 (indicates instability, not the cause) |
| Resource usage | CPU/memory above 80% (pressure, not necessarily the root cause) |
| Version-bug correlation | Running a version known to have a specific bug |
| Missing resources | Expected CRD, ConfigMap, or Secret not found |
| Stale timestamps | Last transition time far in the past for a condition that should update |

### Tier 3: Suggestive (weight 0.25)

Contextual signals. Useful for narrowing investigation, never sufficient alone.

| Source | Examples |
|---|---|
| Pod age | Recently restarted pod (suggests crash, but could be normal rollout) |
| Timing correlation | Issue started after an upgrade, config change, or certificate rotation |
| Similar symptoms | Related component shows comparable behavior |
| Cluster topology | Cluster size, cloud provider, or network configuration that's known to be problematic |
| Historical pattern | "This happened before on another cluster" (from Engram) |
| Absence of evidence | Expected log line NOT present (could mean many things) |

---

## Evidence Combination Rules

### Minimum Requirements Per Conclusion

Every diagnostic conclusion MUST meet these minimums:

| Combination | Minimum Confidence | Use For |
|---|---|---|
| 2x Tier 1 | High (90%+) | Root cause attribution, remediation recommendations |
| 1x Tier 1 + 1x Tier 2 | High (80-90%) | Root cause with known-issue correlation |
| 1x Tier 1 + 2x Tier 3 | Medium (65-75%) | Likely cause, flag for further investigation |
| 3x Tier 2 | Medium (70-85%) | Probable cause, needs Tier 1 confirmation |
| 2x Tier 2 | Low-Medium (50-65%) | Working hypothesis only, label as "unconfirmed" |
| Tier 3 only | **NEVER SUFFICIENT** | Must escalate to collect Tier 1/2 evidence |

### Hard Rules

1. **Minimum 2 sources per conclusion**, at least 1 from Tier 1
2. **Tier 3 alone is NEVER sufficient** for any conclusion -- not even "likely"
3. **Single Tier 1 alone** can state a fact (pod is down) but not attribute root cause
4. **Contradictory evidence** at the same tier: do not resolve by picking one. Report both and label the conclusion as "conflicting evidence, confidence reduced"
5. **Weight calculation:** Sum `(count_at_tier × tier_weight)` across tiers. Score ≥ 2.0 = High, 1.5-2.0 = Medium, < 1.5 = Low

---

## Confidence Levels

| Level | Score Range | What It Means | Report Language |
|---|---|---|---|
| High | 90-100% | Root cause confirmed by direct observation | "Root cause: X (confidence: 95%)" |
| High | 80-89% | Root cause supported by strong evidence | "Root cause: X (confidence: 85%)" |
| Medium | 65-79% | Probable cause, needs additional verification | "Probable cause: X (confidence: 70%) -- needs verification" |
| Low | 50-64% | Working hypothesis only | "Hypothesis: X (confidence: 55%) -- unconfirmed" |
| Insufficient | < 50% | Cannot draw conclusion | "Insufficient evidence to determine root cause" |

---

## Counter-Bias Validation Checklist

Before finalizing any conclusion, verify:

1. **Confirmation:** Looked for contradicting evidence? Checked alternate explanation at a different layer? Different root cause could produce same symptoms?
2. **Recency:** Blaming recent change without causal evidence? Issue existed before the change? Timing supported by Tier 1?
3. **Anchoring:** Fixated on first anomaly? Completed full layer check? Lower-layer findings explain upper symptoms?
4. **ACM traps:** Checked MCH operator replicas (Trap 1)? search-postgres data (Trap 3)? NetworkPolicies (Trap 11)? addon-manager (Trap 7)?
5. **Completeness:** Every Tier 1 from THIS session (not memory)? Each evidence tier-labeled? Weight meets minimum?

---

## Evidence Collection

For each finding, capture: severity (CRIT/WARN/INFO), layer (1-12), evidence items with tier labels, confidence %, counter-check, and root cause.

| Field | Required | Description |
|---|---|---|
| Tier label | Yes | `[Tier 1]`, `[Tier 2]`, or `[Tier 3]` |
| Source type | Yes | Command output, log line, MCP result, knowledge match |
| Exact command | Tier 1 only | The `oc` or MCP command that produced the evidence |
| Relevant output | Tier 1 only | The specific lines that matter (not full output) |
| Reference | Tier 2 only | JIRA ID, knowledge DB file path, or graph query |
| Timestamp | When relevant | When the evidence was collected (for staleness checks) |

---

## Classification After Root Cause Found

The root cause layer does NOT directly determine the classification. Investigate WHO caused the breakage:

| Root Cause Scenario | Classification |
|---|---|
| Product operator created a broken resource | PRODUCT_BUG |
| Product code has a logic error (wrong data, wrong rendering) | PRODUCT_BUG |
| Operator crashes from code bug (nil pointer, panic) | PRODUCT_BUG |
| External action broke infrastructure (NetworkPolicy, quota, scaling) | INFRASTRUCTURE |
| Environment not configured for test (IDP missing, spoke down) | INFRASTRUCTURE |
| Operator scaled to 0 by external action | INFRASTRUCTURE |
| Test selector stale (product renamed, test not updated) | AUTOMATION_BUG |
| Test assertion wrong (expects old behavior) | AUTOMATION_BUG |
| Feature intentionally disabled or post-upgrade settling | NO_BUG |

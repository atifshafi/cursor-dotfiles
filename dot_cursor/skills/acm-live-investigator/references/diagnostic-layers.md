# 12-Layer Diagnostic Model

Systematic investigation framework for finding root causes in ACM clusters. Each layer is a distinct failure domain. A failure at a lower layer cascades upward and manifests as symptoms at higher layers.

---

## The 12 Layers (bottom to top)

```
    SYMPTOM APPEARS HERE (top)
    ─────────────────────────
    Layer 12: UI / Plugin / Rendering
    Layer 11: Data Flow / Content Integrity
    Layer 10: Cross-Cluster / Hub-Spoke
    Layer  9: Operator / Reconciliation
    Layer  8: API / CRD / Webhook
    Layer  7: Authorization / RBAC
    Layer  6: Authentication / Identity
    Layer  5: Configuration / Desired State
    Layer  4: Storage / Data Persistence
    Layer  3: Network / Connectivity
    Layer  2: Control Plane / State Store
    Layer  1: Compute / Scheduling
    ─────────────────────────
    ROOT CAUSE LIVES HERE (bottom)
```

Each layer depends on all layers below it. A network issue (Layer 3) looks like a data issue (Layer 11) which looks like a UI issue (Layer 12). The diagnostic challenge is tracing downward to the actual broken layer.

**Layers are failure domains to check or eliminate, NOT mandatory steps.** Skip layers that don't apply to the current investigation.

---

## Symptom-to-Layer Mapping

When starting from a specific symptom (Targeted depth), use this table to identify the starting layer:

| Error Pattern | Start At Layer |
|---|---|
| "element not found", selector missing | Layer 12 (UI) |
| "timed out waiting for" | Layer 12, trace down |
| "Expected X but got Y" (data mismatch) | Layer 11 (Data Flow) |
| "Expected to find content" (empty data) | Layer 11 (Data Flow) |
| "500 Internal Server Error" | Layer 9 (Operator) |
| "403 Forbidden" | Layer 7 (RBAC) |
| "401 Unauthorized" | Layer 6 (Auth) |
| "connection refused" / "connection timed out" | Layer 3 (Network) |
| blank page / `class="no-js"` / empty body | Could be 3, 6, 9, or 12 |
| "button disabled" / `aria-disabled` | Layer 7, 11, or 12 |
| `cy.exec()` failed / shell error | Layer 1 (Compute/CI) |
| pod OOMKilled / CrashLoopBackOff | Layer 1 or 9 |

---

## Layer 1: Compute / Scheduling

**Commands:**

```bash
oc get nodes -o wide
oc adm top nodes
oc get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'
```

**Healthy:** All nodes `Ready`, no pressure conditions, CPU/memory usage below 80%.

**Red Flags:**
- Node `NotReady` or `SchedulingDisabled`
- MemoryPressure, DiskPressure, or PIDPressure conditions True
- CPU or memory usage above 90% (causes pod evictions, OOM kills)
- Fewer nodes than expected for the cluster profile

**Skip When:** Never. Always check compute first.

---

## Layer 2: Control Plane / State Store

**Commands:**

```bash
oc get clusterversion
oc get clusteroperators
oc get clusteroperators -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Available")].status}{"\t"}{.status.conditions[?(@.type=="Degraded")].status}{"\n"}{end}'
time oc get namespaces > /dev/null  # Should be < 1 second; >2s = etcd latency
```

**Healthy:** ClusterVersion `Available`, all ClusterOperators `Available=True, Degraded=False`, API responsive under 1 second.

**Red Flags:**
- Any ClusterOperator `Degraded=True`
- Any ClusterOperator `Available=False`
- ClusterVersion stuck in `Progressing` (stalled upgrade)
- etcd operator degraded (causes cascading failures -- ~51% of cluster-wide K8s failures trace to state store issues)
- `authentication` operator degraded (breaks OAuth, console, all user-facing access)
- API response time >2 seconds (etcd latency, causes leader election failures at Layer 9)

**Skip When:** Never. Control plane issues mask everything above.

---

## Layer 3: Network / Connectivity

**Commands:**

```bash
oc get networkpolicy -n $MCH_NS
oc get networkpolicy -n multicluster-engine
oc get resourcequota -n $MCH_NS --no-headers
oc get resourcequota -n multicluster-engine --no-headers
oc get endpoints -n $MCH_NS --no-headers | awk '$2 == "<none>" {print $1}'
oc get endpoints -n multicluster-engine --no-headers | awk '$2 == "<none>" {print $1}'
```

**Healthy:** Services have endpoints, no `<none>` endpoint addresses, no ResourceQuotas in ACM namespaces.

**Red Flags:**
- Services with no endpoints (backend pods missing or selector mismatch -- silent failure)
- ResourceQuotas in ACM namespaces (can starve components silently -- Trap 9)
- NetworkPolicies in pre-5.0 ACM namespaces (ACM did NOT create these before 5.0 -- Trap 11)

**Note (ACM 5.0+):** ACM 5.0 introduces per-component NetworkPolicies. Their presence is NORMAL in 5.0+. Only flag NetworkPolicies that don't match ACM-created labels.

**Skip When:** Never. Network issues cause symptoms that look like application bugs.

---

## Layer 4: Storage / Data Persistence

**Commands:**

```bash
oc get pvc -n $MCH_NS
oc get pvc -n multicluster-engine
oc get pvc -n open-cluster-management-observability 2>/dev/null
# Search data integrity:
oc exec -n $MCH_NS $(oc get pods -n $MCH_NS -l name=search-postgres -o name 2>/dev/null || oc get pods -n $MCH_NS -l app=search-postgres -o name 2>/dev/null) -- psql -U searchuser -d search -c "SELECT count(*) FROM search.resources"
```

**Healthy:** All PVCs `Bound`, search-postgres row count > 0 (proportional to managed cluster count, ~200 resources per cluster).

**Red Flags:**
- PVC in `Pending` state (StorageClass issue, no available PVs)
- search-postgres with 0 rows (Trap 3 -- data lost on pod restart, pods still show Running)
- PVC in `Lost` state (underlying storage disappeared)
- S3 credentials expired (thanos-store crashes -- Trap 4)

**Storage models vary by component:**

| Component | Storage Model | Concern |
|---|---|---|
| search-postgres | emptyDir (default) | Pod restart = total data loss. Check pod age + row count |
| observability (thanos-*) | PVC (StatefulSet) | PVC bound? Disk full? S3 credentials valid? |
| search-api, console, grc | stateless | No Layer 4 concern |
| hive-clustersync | emptyDir | Pod restart = sync state lost |

**Skip When:** Cluster has no PVCs and no search deployed (unlikely for ACM hubs).

---

## Layer 5: Configuration / Desired State

**Commands:**

```bash
oc get mch -A -o yaml
oc get multiclusterengines -A -o yaml
oc get csv -n $MCH_NS --no-headers
oc get csv -n multicluster-engine --no-headers
oc get sub -n $MCH_NS --no-headers
oc get catalogsources -n openshift-marketplace -o custom-columns='NAME:.metadata.name,STATE:.status.connectionState.lastObservedState'
```

**Healthy:** MCH `.status.phase: Running`, all CSVs `Succeeded`, subscriptions have `currentCSV`, CatalogSources `READY`.

**Red Flags:**
- MCH phase not `Running` (but verify operator replicas first -- Trap 1)
- CSV in `InstallReady` or `Pending` for extended period
- CatalogSource not ready or missing (blocks operator updates)
- MCH component explicitly disabled that should be enabled
- Subscription `state` not `AtLatestKnown`
- CatalogSource with stale gRPC connection (OLM can't resolve new versions)

**Skip When:** Never. Misconfiguration is a common root cause.

---

## Layer 6: Authentication / Identity

**Commands:**

```bash
oc get oauth cluster -o jsonpath='{range .spec.identityProviders[*]}{.name} ({.type}){"\n"}{end}'
oc get csr --no-headers | grep -v Approved
oc get secrets -n $MCH_NS -o json | python3 -c "import json,sys; [print(i['metadata']['name']) for i in json.load(sys.stdin)['items'] if i['type']=='kubernetes.io/tls']" 2>/dev/null
```

**Healthy:** IDPs configured, no pending/denied CSRs, TLS secrets present and not expired, OAuth working.

**Red Flags:**
- Pending CSRs (node join blocked, certificate rotation stalled)
- Expired certificates (causes TLS handshake failures -- Trap 12)
- Missing TLS secrets (service-serving certs not generated)
- OAuth pods not Running (breaks all non-admin authentication)

**Skip When:** Layer 2 shows `authentication` operator healthy AND no TLS-related errors in symptoms AND test uses admin/ServiceAccount auth.

---

## Layer 7: Authorization / RBAC

**Commands:**

```bash
oc auth can-i --list --as=system:serviceaccount:$MCH_NS:multiclusterhub-operator -n $MCH_NS
oc get clusterrolebinding | grep open-cluster-management
oc get clusterrolebinding | grep klusterlet
```

**Healthy:** Operator service accounts have expected permissions, no orphaned role bindings.

**Red Flags:**
- Operator SA missing expected permissions (silent failures -- components can't create resources)
- klusterlet ClusterRole missing permissions (blocks agent deployment -- ACM-40357 pattern)
- Orphaned ClusterRoleBindings from previous ACM install

**Skip When:** No RBAC-related errors in symptoms and Layers 1-6 are clean. Check if symptoms include "forbidden" or "cannot" messages first.

---

## Layer 8: API / CRD / Webhook

**Commands:**

```bash
oc get validatingwebhookconfigurations | grep -E 'ocm|cluster-manager|multicluster|hive'
oc get mutatingwebhookconfigurations | grep -E 'ocm|cluster-manager|multicluster|hive'
oc get endpoints -n $MCH_NS | grep webhook
oc get endpoints -n hive | grep admission
```

**Healthy:** Webhook configurations present with valid service references, webhook service endpoints exist and have addresses.

**Red Flags:**
- Webhook configured but backing service has no endpoints (blocks all operations -- Trap 10)
- `failurePolicy: Fail` on a webhook whose service is down
- "admission webhook denied" in events
- ALL cluster lifecycle operations failing simultaneously (check hiveadmission)

**Skip When:** No "admission webhook denied" errors in symptoms. Check if symptoms include resource creation/update failures first.

---

## Layer 9: Operators / Reconciliation

**Commands:**

```bash
oc get pods -n $MCH_NS --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers
oc get pods -n multicluster-engine --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers
oc get pods -n hive --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null
oc get deploy -n $MCH_NS -o custom-columns='NAME:.metadata.name,DESIRED:.spec.replicas,READY:.status.readyReplicas'
oc get deploy multiclusterhub-operator -n $MCH_NS --no-headers
oc get deploy multicluster-engine-operator -n multicluster-engine --no-headers
oc get statefulset -n $MCH_NS --no-headers
oc get statefulset -n hive --no-headers 2>/dev/null
```

**Healthy:** All pods `Running` with all containers ready, restart counts < 3, deployments at desired replica count.

**Red Flags:**
- Pods in `CrashLoopBackOff`, `ImagePullBackOff`, `Pending`, `Error`
- Restart count > 3 (indicates recurring crashes)
- multiclusterhub-operator at 0 replicas (Trap 1 -- makes MCH status stale, CRITICAL)
- StatefulSet not at desired replica count
- Container not ready but pod shows Running (readiness probe failing)

**Leader election check (Trap 1b/14):**
```bash
oc get lease -n $MCH_NS | grep multiclusterhub
oc get lease <lease-name> -n $MCH_NS -o jsonpath='{.spec.renewTime}'
# If renewTime not within last few minutes -> reconciliation stopped
```

Both operator replicas may be Running/Ready but reconciliation stopped because leader election Lease expired (often due to etcd latency at Layer 2).

**Skip When:** Never for Standard+. This is the core ACM component health check.

---

## Layer 10: Cross-Cluster / Hub-Spoke

**Commands:**

```bash
oc get managedclusters -o custom-columns='NAME:.metadata.name,AVAILABLE:.status.conditions[?(@.type=="ManagedClusterConditionAvailable")].status,JOINED:.status.conditions[?(@.type=="ManagedClusterJoined")].status'
oc get managedclusteraddons -A --no-headers
oc get managedclusteraddons -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Available")].status}{"\n"}{end}'
```

**Healthy:** All ManagedClusters `Available=True, Joined=True`, addons show `Available=True`.

**Red Flags:**
- ManagedCluster `Available=Unknown` (heartbeat lost -- check lease, not klusterlet first -- Trap 6)
- ALL addons Unavailable across ALL clusters (Trap 7 -- check addon-manager pod, single point of failure)
- Addons Unavailable on a SINGLE cluster (spoke-side issue, not hub)
- local-cluster not Available (hub self-management broken)

**Skip When:** No managed clusters exist (hub-only deployment).

---

## Layer 11: Data Flow / Content Integrity

**Commands:**

```bash
# Search API health:
oc exec -n $MCH_NS $(oc get pods -n $MCH_NS -l app=search-api -o name | head -1) -- curl -sk https://localhost:4010/readiness 2>/dev/null
# Data counts:
oc exec -n $MCH_NS $(oc get pods -n $MCH_NS -l app=search-postgres -o name 2>/dev/null || oc get pods -n $MCH_NS -l name=search-postgres -o name 2>/dev/null) -- psql -U searchuser -d search -c "SELECT count(*) FROM search.resources"
# Policy status:
oc get policy -A --no-headers 2>/dev/null | head -5
```

**Healthy:** API readiness endpoints return 200, search returns results proportional to cluster count, policy status reflects actual compliance.

**Red Flags:**
- search-api readiness fails (breaks Search page, Fleet Virt, RBAC views -- Trap 8)
- Data counts are 0 or stale (check Layer 4 search-postgres first)
- Policy status stuck (propagator or status-sync issues)
- API returns incorrect data (possible product bug at this layer)

**Skip When:** Layers 4 and 9 show search-postgres or search-api pods unhealthy (root cause already identified lower).

---

## Layer 12: UI / Plugin / Rendering

**Commands:**

```bash
oc get consoleplugins --no-headers
oc get pods -n $MCH_NS -l app=console-chart-console-v2 --no-headers
oc get pods -n multicluster-engine | grep console
oc get route multicloud-console -n $MCH_NS -o jsonpath='{.spec.host}' 2>/dev/null
oc get deploy console-chart-console-v2 -n $MCH_NS -o jsonpath='{.spec.template.spec.containers[0].image}'
```

**Healthy:** Console pods Running, plugins registered and enabled, route accessible.

**Red Flags:**
- Console pods not Running (UI completely inaccessible)
- ConsolePlugin not registered (ACM nav items missing -- Trap 2)
- Console route returns 503/502
- Multiple console areas broken simultaneously (check search-api first -- Trap 8)
- Feature tabs present but render errors (plugin backend unhealthy -- Trap 13)

**Skip When:** Issue is purely API/CLI-based with no UI component. Also skip if Layer 9 found console pods unhealthy.

---

## Layer Discrepancy Detection

During layer-by-layer investigation, when you verify a lower layer is healthy but the higher layer shows a problem, this is strong evidence of a product bug. Record as `layer_discrepancy`:

| Lower Layer Says | Higher Layer Shows | Conclusion |
|---|---|---|
| L7: User HAS permission (`oc auth can-i` = yes) | L12: Button disabled | PRODUCT_BUG (UI permission logic) |
| L11: Backend returns correct data | L12: UI shows wrong data | PRODUCT_BUG (rendering bug) |
| L9: Operator healthy, reconciling | L11: Data not flowing | PRODUCT_BUG (data pipeline bug) |
| L3: Network OK, endpoints reachable | L11: Service returns empty | PRODUCT_BUG (service logic bug) |
| L6: Auth working, token valid | L12: Login redirect fails | PRODUCT_BUG (auth flow bug) |

A layer discrepancy OVERRIDES subsystem health status -- it proves a product code defect exists between the two layers.

---

## Using Layers with Dependency Chains

Dependency chains trace HORIZONTALLY (console→search→postgres). Layers trace VERTICALLY (why is postgres down? → Layer 3: NetworkPolicy). When a chain shows a broken link, use layers to find WHY.

**Vertical tracing (Deep/Targeted):** Find the LOWEST affected layer across all findings. If a single issue at that layer explains all higher findings, that's the root cause. Verify with evidence-tiers.md rules (minimum 2 sources). Trace ownership: `oc get <resource> -o jsonpath='{.metadata.ownerReferences}'`

---

## Layers and Diagnostic Traps

| Trap | Symptom | Obvious (wrong) Layer | Actual Layer |
|------|---------|---|---|
| 1 | MCH says Running | OK (no issue) | Layer 9 (operator at 0 replicas) |
| 2 | Console pod healthy, tabs missing | Layer 12 | Layer 9/12 (console-mce pod) |
| 3 | Search all green, empty results | Layer 9 (pods fine) | Layer 4 (emptyDir data loss) |
| 4 | Observability dashboards empty | Layer 9 (operator) | Layer 4 (S3 storage) |
| 5 | GRC non-compliant after upgrade | Layer 9 (operator) | Normal settling (wait) |
| 6 | ManagedCluster NotReady | Layer 10 (klusterlet) | Layer 3/6 (network/auth) |
| 7 | ALL addons Unavailable | Layer 10 (per-addon) | Layer 9 (addon-manager) |
| 8 | Multiple console pages broken | Layer 12 (console UI) | Layer 9 (search-api) |
| 9 | Pods gradually disappearing | Layer 9 (per-pod) | Layer 3 (ResourceQuota) |
| 10 | ALL cluster ops fail | Layer 9 (Hive operator) | Layer 8 (Hive webhook) |
| 11 | Pods Running, cross-service fails | Layer 9 (per-service) | Layer 3 (NetworkPolicy) |
| 12 | TLS errors, service-ca healthy | Layer 9 (service-ca) | Layer 6 (corrupted secret) |
| 13 | Feature tabs present but broken | Layer 12 (UI rendering) | Layer 9 (plugin backend) |
| 14 | Both replicas Running, nothing reconciling | OK (pods healthy) | Layer 9 (leader election stuck) |

---

## Layer Quick-Reference Card

```
Layer  Check                         Key Command
-----  ----------------------------- -----------------------------
  1    Nodes Ready? Pods schedule?   oc get nodes
  2    API server + etcd healthy?    oc get co etcd kube-apiserver
  3    NetworkPolicy? Endpoints?     oc get netpol -n $MCH_NS
  4    PVCs Bound? Data present?     oc get pvc -n $MCH_NS
  5    MCH toggles? CSVs healthy?    oc get csv -n $MCH_NS
  6    Certs valid? IDP working?     oc get csr | grep -v Approved
  7    RBAC bindings correct?        oc auth can-i <verb> <res>
  8    CRDs exist? Webhooks up?      oc get validatingwebhook
  9    Operators reconciling?        oc get deploy -n $MCH_NS
 10    Clusters Available? Addons?   oc get managedclusters
 11    Data correct? Counts right?   psql SELECT count(*)
 12    Plugins registered? UI ok?    oc get consoleplugins
```

**Principle:** If a lower layer is broken, document it and note which upper layers are likely affected. Do not spend time diagnosing upper-layer symptoms that are explained by a lower-layer failure.

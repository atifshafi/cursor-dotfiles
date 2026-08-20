# Dependency Chains -- 12 Critical Paths

When failures cascade across ACM subsystems, trace UPSTREAM through these chains to find the root cause. If Component A depends on B and B is broken, A's failures are CAUSED BY B.

**Implicit Service layer:** Every dependency arrow passes through a Kubernetes Service. If a Service has zero ready endpoints, the chain breaks silently. Check `oc get endpoints -n <ns> <service-name>` at each hop.

---

## Chain 1: Console → Search → Managed Clusters

```
Console UI (VM page, search page, RBAC resource views)
  → console-api Resource Proxy
    → search-api (GraphQL)
      → search-indexer → search-postgres (storage)
      → search-collector addon (per spoke) → klusterlet
```

**Impact:** search-api down → Console VM pages empty, RBAC views blank, search broken.

**Trace:**
1. Console page loading? → check console-api pods
2. search-api healthy? → `oc get pods -n $MCH_NS -l app=search-api`
3. search-postgres healthy? → `oc exec deploy/search-postgres -n $MCH_NS -- psql -U searchuser -d search -c "SELECT count(*) FROM search.resources"`
4. Results missing from specific clusters? → check search-collector addon on that spoke

---

## Chain 2: Governance → Framework Addon → Config Policy → Spokes

```
Policy + PlacementBinding + Placement
  → grc-policy-propagator (creates replicated policies)
    → governance-policy-framework-addon (Spec Sync)
      → config-policy-controller (on spoke, evaluates)
        → Status Sync Controller (reports back to hub)
```

**Impact:** Propagator down → no new policies distribute. Framework addon missing → policies don't reach spoke.

**Trace:**
1. Policy Unknown vs Non-compliant?
2. `oc get pods -n $MCH_NS -l app=grc-policy-propagator`
3. `oc get managedclusteraddon governance-policy-framework -n <cluster>`
4. Check work-manager: `oc get pods -n open-cluster-management-hub -l app=work-manager`

---

## Chain 3: MCH Operator → Backplane → Component Operators

```
OLM (Subscription + CSV)
  → MCH Operator → MCE CR → Backplane Operator
    → All MCE components (cluster-manager, hive, import-controller, addon-manager, placement)
    → All ACM components (search, grc, subscription, console, observability)
```

**Impact:** MCH operator down → all component lifecycle stops. Backplane down → MCE components unmanaged.

**Trace:**
1. `oc get mch -A` → phase?
2. `oc get multiclusterengines` → Available?
3. `oc get pods -n multicluster-engine | grep backplane`
4. `oc get csv -n $MCH_NS` and `oc get sub -n $MCH_NS`

---

## Chain 4: HyperShift Addon → Import Controller → Klusterlet

```
HostedCluster CR → hypershift-addon (creates ManagedCluster)
  → managedcluster-import-controller (generates klusterlet manifests)
    → klusterlet on hosted cluster → registration-agent → hub
```

**Impact:** hypershift-addon down → new hosted clusters aren't imported.

---

## Chain 5: MCRA → ClusterPermission → ManifestWork → Spoke RBAC

```
MultiClusterRoleAssignment (RBAC wizard)
  → MCRA Operator → ClusterPermission (per cluster)
    → ManifestWork (Role + RoleBinding) → klusterlet work-agent
      → Role + RoleBinding on spoke
```

**Impact:** MCRA operator down → role assignments not processed. User doesn't get permissions, VM pages empty.

**Trace:**
1. `oc get mcra -A -o yaml | grep -A5 conditions`
2. `oc get clusterpermission -n <cluster>`
3. `oc get manifestwork -n <cluster> | grep permission`
4. `oc get pods -n $MCH_NS | grep cluster-permission`

---

## Chain 6: Observability → Addon → Prometheus → Thanos → S3

```
MultiClusterObservability CR → observability-operator
  → observability-controller addon (on spokes)
    → metrics-collector (scrapes Prometheus) → thanos-receive
      → S3 object storage → thanos-store → thanos-query → Grafana
```

**Impact:** S3 misconfigured → thanos-store crashes (most common failure). metrics-collector missing → no data from that spoke.

**Trace:**
1. `oc get pods -n open-cluster-management-observability | grep thanos`
2. Check S3 errors in thanos-store logs
3. `oc get managedclusteraddon -A | grep observability`

---

## Chain 7: Addon Manager → Addon Framework → Spoke Addon Pods

```
addon-manager (MCE namespace)
  → ManagedClusterAddon CRs → ManifestWork delivery
    → klusterlet work-agent → spoke addon pods
```

**Impact:** addon-manager is SINGLE POINT OF FAILURE for ALL spoke addons. Down → no addons on any spoke.

**Trace:**
1. ALL addons Unavailable? → `oc get pods -n multicluster-engine | grep addon-manager`
2. Specific addon stuck? → `oc get manifestwork -n <cluster> | grep <addon-name>`

---

## Chain 8: StorageClass → CSI → PV → PVC → Pod

```
StorageClass → CSI Driver → PersistentVolume → PVC → Stateful pod
```

**Impact:** Storage failures affect: thanos-receive, thanos-store, alertmanager. search-postgres uses emptyDir by default.

**Trace:**
1. `oc get pvc -n open-cluster-management-observability`
2. `oc get sc` → is one marked `(default)`?
3. If PVCs Pending: `oc describe pvc <name>`

---

## Chain 9: Channel → Subscription → ManifestWork → Spoke App

```
Channel CR → channel controller → Subscription + Placement
  → hub-subscription controller → ManifestWork
    → klusterlet → application-manager addon (spoke)
```

**Impact:** hub-subscription down → app deployment halts. Channel auth fails → subscription stuck with no explicit error.

---

## Chain 10: CNV → Search Collector → Search API → kubevirt-plugin → Console

```
CNV HyperConverged (spoke) → search-collector → search-indexer
  → search-postgres → search-api → kubevirt-plugin → ACM console
```

**Impact:** search-collector missing → VMs don't appear in hub. kubevirt-plugin unregistered → Fleet Virt tab absent.

**Trace:**
1. Fleet Virt tab visible? → `oc get consoleplugins | grep kubevirt`
2. VMs in search? → query search-api
3. `oc get managedclusteraddon search-collector -n <cluster>`
4. CNV on spoke? → `oc get csv -A | grep kubevirt-hyperconverged`

---

## Chain 11: SubmarinerConfig → Addon → Gateway → Tunnel → DNS

```
SubmarinerConfig → submariner-addon → submariner-operator (spoke)
  → gateway (IPsec tunnels) → routeagent → lighthouse-agent
    → lighthouse-coredns (clusterset.local)
```

**Impact:** Gateway unhealthy → all cross-cluster tunnels down. Lighthouse down → service discovery fails.

---

## Chain 12: HiveConfig → ClusterDeployment → Install Pod → ManagedCluster

```
HiveConfig → hive-operator → hive-controllers
  → hiveadmission webhook (failurePolicy: Fail)
    → ClusterProvision + Install Pod → cloud infrastructure
      → kubeconfig secrets → import-controller → klusterlet → ManagedCluster
```

**Impact:** hiveadmission webhook down → ALL cluster operations blocked (Trap 10). hive-controllers down → ALL provisioning stops.

---

## Cross-Chain Patterns

| Symptom | Shared Cause |
|---|---|
| Search + Observability both broken | Shared storage or node pressure |
| All features broken on one spoke | klusterlet disconnected (chains 1,2,5,6) |
| Multiple addons failing on same spoke | addon-manager down or spoke connectivity |
| Nothing works | MCH/MCE/backplane issue (chain 3) |
| UI "everything broken" but oc works | Console issue only (chain 1 top) |
| ALL addons Unavailable everywhere | addon-manager down (chain 7) |
| New clusters import but get no addons | addon-manager down; import works independently |
| ALL cluster ops fail | Hive webhook down (chain 12, Trap 10) |

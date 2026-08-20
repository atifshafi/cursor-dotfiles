# Diagnostic Traps -- 14 Patterns + 3 Counter-Traps

Patterns where the obvious diagnosis is WRONG. Check these before concluding any investigation.

---

## Quick Reference

| Trap | Symptom | Check First | Wrong → Correct |
|------|---------|-------------|-----------------|
| 1 | MCH says Running but things break | Operator pod replicas | Healthy → INFRASTRUCTURE |
| 1b | Operator pods Running but nothing reconciling | Leader election Lease renewTime | Healthy → INFRASTRUCTURE |
| 2 | Console pod healthy, tabs missing | console-mce + ConsolePlugin CRDs | AUTOMATION_BUG → INFRASTRUCTURE |
| 3 | Search all green, empty results | Postgres pod age + data count | PRODUCT_BUG → INFRASTRUCTURE |
| 4 | Observability dashboards empty | Thanos pods + S3 secret | PRODUCT_BUG → INFRASTRUCTURE |
| 5 | GRC non-compliant after upgrade | Addon pod age (wait 15 min) | PRODUCT_BUG → NO_BUG |
| 6 | ManagedCluster NotReady | Lease + conditions (not klusterlet) | Wrong root cause |
| 7 | ALL addons Unavailable everywhere | addon-manager pod | Multiple issues → single root cause |
| 8 | Multiple console pages broken | search-api pod | Multiple PRODUCT_BUG → single INFRASTRUCTURE |
| 9 | Pods gradually disappearing | ResourceQuota in ACM namespace | Hidden INFRASTRUCTURE |
| 10 | ALL cluster ops fail | Hive webhook service | Operator blame → webhook blame |
| 11 | Pods Running, cross-service fails | NetworkPolicy in ACM namespace | PRODUCT_BUG → INFRASTRUCTURE |
| 12 | TLS errors, service-ca healthy | Corrupted cert secret | Operator blame → secret blame |
| 13 | Feature tabs present but broken | Plugin backend pod health | PRODUCT_BUG → INFRASTRUCTURE |
| 14 | Both replicas Running, nothing reconciling | Leader election lease | Healthy → INFRASTRUCTURE |

---

## Trap 1: Stale MCH/MCE Status (Operator Not Running)

**Symptom:** `oc get mch` shows `phase: Running` but components are broken.

**Reality:** MCH operator at 0 replicas means `.status.phase` is frozen at last-known value.

**Detect:**
```bash
oc get deploy multiclusterhub-operator -n $MCH_NS -o jsonpath='{.spec.replicas}/{.status.availableReplicas}'
```
If `0/0` or replicas mismatch → MCH status is STALE.

**Rule:** Never trust MCH `.status.phase` without confirming operator pod is Running.

---

## Trap 1b: Leader Election Stuck

**Symptom:** Operator pods Running/Ready, health probes pass, but nothing reconciles.

**Reality:** Leader election Lease expired (etcd latency), neither replica re-acquired it.

**Detect:**
```bash
oc get lease -n $MCH_NS | grep multiclusterhub
oc get lease <lease-name> -n $MCH_NS -o jsonpath='{.spec.renewTime}'
# If renewTime not within last few minutes → stuck

time oc get namespaces > /dev/null
# If >2 seconds → etcd latency causing lease expiry
```

**Applies to:** MCH operator (2 replicas), MCE operator, grc-policy-propagator, cluster-manager, any controller with `--leader-elect`.

---

## Trap 2: Console Pod Healthy but Feature Tabs Missing

**Symptom:** Console Running/Ready but entire sections missing from UI.

**Reality:** ACM uses dynamic plugins. `console-mce` in MCE namespace serves MCE tabs. If it's down, tabs disappear silently.

**Detect:**
```bash
oc get pods -n $MCH_NS | grep console
oc get pods -n multicluster-engine | grep console
oc get consoleplugins
```

**Rule:** Console pod healthy ≠ console fully functional. Check console-mce and ConsolePlugin CRDs.

---

## Trap 3: Search Returns Empty but All Pods Green

**Symptom:** All search pods Running, but search returns 0 results.

**Reality:** search-postgres uses `emptyDir`. Pod restart = all data lost. Re-collection takes 10-30 min.

**Detect:**
```bash
oc exec deploy/search-postgres -n $MCH_NS -- psql -U searchuser -d search -c "SELECT count(*) FROM search.resources" 2>&1
# "relation does not exist" → schema dropped
# count = 0 → data lost, wait for collectors
```

**Rule:** Search "all green" + "empty results" → always check postgres data count first.

---

## Trap 4: Observability Empty -- Actually S3

**Symptom:** Grafana dashboards show no data.

**Reality:** Most common cause is S3/object storage misconfiguration, not operator issues.

**Detect:**
```bash
oc get pods -n open-cluster-management-observability | grep thanos
oc logs -n open-cluster-management-observability <thanos-store-pod> --tail=20
# Look for: "bucket operation failed", "Access Denied", "NoSuchBucket"
```

**Rule:** Observability failures → check thanos pods + S3 secret before investigating operator.

---

## Trap 5: GRC Non-Compliant After Upgrade (Normal)

**Symptom:** After upgrade, policies show non-compliant or Unknown.

**Reality:** Normal post-upgrade settling. Governance addon restarts, compliance resets, re-evaluation takes 5-15 min.

**Detect:**
```bash
oc get managedclusteraddons -A | grep governance
# If "Progressing" or "Unknown" → still settling
```

**Rule:** Post-upgrade GRC non-compliance for 5-15 min is expected. Only investigate if persists >20 min or pods CrashLooping.

---

## Trap 6: ManagedCluster NotReady

**Symptom:** Cluster shows AVAILABLE=False.

**Reality:** Usually NOT a klusterlet crash. Most common: network/firewall, proxy config, hub API overload, stale lease.

**Detect:**
```bash
oc get lease -n <cluster-namespace> --sort-by=.spec.renewTime
oc get managedcluster <name> -o jsonpath='{.status.conditions[*].message}'
oc get managedclusteraddons -n <cluster-namespace>
# ALL addons unavailable = connectivity issue (not individual addon failures)
```

---

## Trap 7: ALL Addons Unavailable -- Single Pod Failure

**Symptom:** ALL addons Unavailable across multiple/all managed clusters.

**Reality:** `addon-manager` in MCE namespace is the single point of failure for ALL spoke addons.

**Detect:**
```bash
oc get pods -n multicluster-engine | grep addon-manager
```

**Rule:** Mass addon failure → check addon-manager BEFORE investigating individual addons.

---

## Trap 8: Multiple Console Pages Broken -- Check Search First

**Symptom:** Search, Fleet Virt VM list, RBAC resource views, some policy views all broken.

**Reality:** All share `search-api` as dependency. When search-api is down, all dependent features fail.

**Detect:**
```bash
oc get pods -n $MCH_NS | grep search-api
oc logs -n $MCH_NS -l app=search-api --tail=20
```

**Rule:** 3+ console features broken simultaneously → check search-api first.

---

## Trap 9: ResourceQuota Blocking Pod Restarts

**Symptom:** Pods gradually disappearing, services degrading. Pods not restarting.

**Reality:** ResourceQuota in ACM namespace blocks pod recreation. ACM does NOT create these -- externally added.

**Detect:**
```bash
oc get resourcequota -n $MCH_NS --no-headers
oc get resourcequota -n multicluster-engine --no-headers
```

**Rule:** Missing pods + no restarts → check ResourceQuota.

---

## Trap 10: Hive Webhook Blocks ALL Cluster Operations

**Symptom:** Cluster create/import/delete all fail with webhook errors.

**Reality:** `hiveadmission` webhook has `failurePolicy: Fail`. If down, ALL ClusterDeployment operations are rejected.

**Detect:**
```bash
oc get pods -n hive | grep hiveadmission
oc get events -n <cluster-ns> --sort-by=.lastTimestamp | grep webhook
```

---

## Trap 11: NetworkPolicy Hiding Failures

**Symptom:** Pods Running/Ready (probes pass) but cross-service communication fails.

**Reality:** NetworkPolicy blocking inter-pod traffic. ACM does NOT create these.

**Detect:**
```bash
oc get networkpolicy -n $MCH_NS --no-headers
oc get networkpolicy -n multicluster-engine --no-headers
```

**Rule:** Check L3 (Network) BEFORE L9 (Operators). NetworkPolicy in ACM namespace is always suspicious.

---

## Trap 12: TLS Cert Corrupted

**Symptom:** TLS handshake errors between services. service-ca-operator is healthy.

**Reality:** service-ca-operator creates but doesn't OVERWRITE secrets. Corrupted cert persists.

**Detect:**
```bash
oc get secret <secret-name> -n <ns> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates 2>&1
# "unable to load certificate" → corrupted
```

**Fix:** Delete the secret → service-ca recreates it fresh. Restart affected pods.

---

## Trap 13: ConsolePlugin Registered but Backend Unreachable

**Symptom:** Feature tabs present in navigation but render errors/blank content.

**Reality:** Plugin is registered but its backend service pod is unhealthy.

**Detect:**
```bash
oc get consoleplugins -o yaml  # Note .spec.backend.service
oc get endpoints -n <ns> <service-name>  # No ready addresses = backend down
```

---

## Trap 14: Both Replicas Running but Reconciliation Stopped

Same as Trap 1b. Applies to any HA operator with leader election.

---

## Counter-Traps (Prevent Over-Attribution)

### A: Degraded Cluster + Selector Error ≠ INFRASTRUCTURE

If `console_search.found=false` for a test selector, it NEVER existed in the product source. No amount of healthy infrastructure will fix it → AUTOMATION_BUG regardless of cluster state.

### B: Backend Returns Wrong Data ≠ INFRASTRUCTURE

If Kubernetes API returns correct data but console shows wrong data → PRODUCT_BUG in the console's data transformation layer, not infrastructure.

### C: Missing Prerequisite ≠ NO_BUG

If Jenkins parameters say "install feature X" but the operator is absent → INFRASTRUCTURE (setup failure), not NO_BUG (feature intentionally disabled).

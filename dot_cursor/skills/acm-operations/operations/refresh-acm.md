# Operation 2: Refresh ACM to Latest Nightly Build

**Permission Required:** This is DESTRUCTIVE. STOP and confirm with user before executing.

**Fallback rule:** If a jsonpath command returns empty or errors, fall back to `-o yaml | grep <field>`.

---

## When to Use

- User asks to "update ACM", "refresh ACM", "pick up latest build", "reinstall the operator"
- A fix has been merged but the cluster's CSV still references old images
- The catalog uses a rolling tag and newer images exist

## When NOT to Use

- For GA-to-GA upgrades (e.g., 2.15 to 2.16) -- that's a channel change
- If the user hasn't explicitly asked for it

## How It Works

The catalog image tag (e.g., `latest-2.16`) is a rolling tag overwritten by nightly CI. OLM won't reinstall when the CSV version string stays the same. Deleting and recreating the Subscription forces OLM to pull the latest bundle.

---

## Steps

**Step 1: Capture current Subscription (KEEP full YAML -- user needs visibility before delete)**

```bash
ACM_NS=ocm
oc get sub advanced-cluster-management -n $ACM_NS -o yaml
```

Note: `channel`, `source`, `sourceNamespace`, `installPlanApproval`.

**Step 2: Delete Subscription and CSV**

```bash
oc delete sub advanced-cluster-management -n $ACM_NS
oc delete csv advanced-cluster-management.v2.16.0 -n $ACM_NS
```

This removes only the OLM management layer. Does NOT delete: MCH CR, MCE, workloads, managed clusters, or data.

**Step 3: Recreate the Subscription**

```bash
oc apply -f - <<'EOF'
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: advanced-cluster-management
  namespace: <ACM_NS>
spec:
  channel: release-2.16
  installPlanApproval: Automatic
  name: advanced-cluster-management
  source: acm-dev-catalog
  sourceNamespace: openshift-marketplace
EOF
```

Adjust `channel`, `source`, and `namespace` to match Step 1 values.

**Step 4: Wait for CSV installation**

```bash
sleep 20
oc get csv -n $ACM_NS -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.phase}{"\n"}{end}' | grep advanced-cluster-management
oc get csv advanced-cluster-management.v2.16.0 -n $ACM_NS -o jsonpath='{.metadata.annotations.createdAt}'
```

**Step 5: Wait for MCH reconciliation**

```bash
oc get multiclusterhub multiclusterhub -n $ACM_NS -o jsonpath='{.status.phase}'
oc rollout status deploy/console-chart-console-v2 -n $ACM_NS --timeout=180s
```

Full reconciliation takes 3-8 minutes. Poll MCH phase until "Running".

**Step 6: Verify**

```bash
oc get multiclusterhub -n $ACM_NS -o jsonpath='phase={.status.phase} version={.status.currentVersion}'
oc get csv -n $ACM_NS -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.phase}{"\n"}{end}' | grep advanced-cluster-management
oc get deploy console-chart-console-v2 -n $ACM_NS -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

## What to Expect

| Phase | Duration | What Happens |
|-------|----------|--------------|
| Sub+CSV deletion | ~5s | OLM management removed |
| Sub recreation | ~1s | OLM picks up latest bundle |
| CSV installation | 20-40s | New CSV installs, operator deploys |
| MCH reconciliation | 3-8 min | All operand images roll out |
| MCH phase: Running | End | All components healthy |

## Risks

- **Low risk** -- standard operator lifecycle operation
- **Brief disruption** -- ACM console pod restarts (~2 min unavailability)
- **Managed clusters unaffected** -- spokes, klusterlets, addons not touched

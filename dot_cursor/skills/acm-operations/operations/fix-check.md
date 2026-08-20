# Operation 3: Check if a Fix/PR is Present

**Fallback rule:** If a jsonpath command returns empty or errors, fall back to `-o yaml | grep <field>`.

---

## Steps

**Step 1: Get the fix details**

```bash
gh pr view <PR_NUMBER> --repo stolostron/<REPO> --json state,mergedAt,mergeCommit,title
```

**Step 2: Get the running component image**

```bash
ACM_NS=ocm
oc get deploy <COMPONENT_DEPLOY> -n $ACM_NS -o jsonpath='{.spec.template.spec.containers[0].image}'
```

**Step 3: Inspect the running image's build info**

```bash
oc get secret multiclusterhub-operator-pull-secret -n $ACM_NS \
  -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d > /tmp/acm-auth.json
oc image info <IMAGE_DIGEST> -a /tmp/acm-auth.json --filter-by-os linux/amd64
rm -f /tmp/acm-auth.json
```

Key labels: `build-date`, `vcs-ref` (git commit of the image source).

**Step 4: Compare dates and commits**

| Check | Condition for fix being present |
|-------|-------------------------------|
| PR merge date | Must be **before** image `build-date` |
| `vcs-ref` | Fix commit must be an ancestor of the image commit |

```bash
gh api repos/stolostron/<REPO>/compare/<IMAGE_VCS_REF>...<PR_MERGE_COMMIT> \
  --jq '.commits[] | .sha[:12] + " " + (.commit.message | split("\n")[0])' \
  | grep -i '<JIRA_KEY>'
```

If the fix commit appears, the image contains the fix.

**Step 5: If fix is NOT present**

Offer to run Operation 2 (Refresh ACM) to pick up the latest build.

---

## CRITICAL: Upstream vs Downstream Pipeline Lag

**Do NOT conflate upstream staging with downstream availability.**

| System | Registry | What it does | Speed |
|--------|----------|-------------|-------|
| **Upstream (quay-retag)** | `quay.io/stolostron/<component>` | Tags upstream images in `stolostron/pipeline` repo | ~1-2 hours after merge |
| **Downstream (Konflux)** | `quay.io:443/acm-d/<component>-rhel9` → `acm-dev-catalog:latest-X.Y` | Builds RHEL-based images, updates OLM catalog index | **12-24 hours** after merge |

**The `stolostron/pipeline` repo staging does NOT mean the downstream OLM catalog has the fix.**

### Verification chain (all must be true):

1. PR merged to `main` (or `release-X.Y`) ✓
2. `stolostron/pipeline` shows staging commit ✓ (UPSTREAM only)
3. Konflux rebuilt the downstream `-rhel9` image ← **check this**
4. Konflux rebuilt the catalog index ← **check this**
5. Cluster pulled catalog AFTER step 4 ← **timing matters**

### Fix verification timelines:

| Time since merge | Safe to provision? |
|------------------|--------------------|
| 0-6 hours | NO -- downstream catalog likely stale |
| 6-12 hours | MAYBE -- depends on Konflux rebuild schedule |
| 12-24 hours | LIKELY -- most rebuilds complete |
| 24+ hours | YES -- safe to assume downstream has it |

**When in doubt:** Provision, then check `vcs-ref` label. If fix isn't present, use Operation 2 (Refresh) to force re-pull.

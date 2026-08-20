# Operation 1: Get ACM Build Tag / Snapshot

**Fallback rule:** If a jsonpath command returns empty or errors, fall back to `-o yaml | grep <field>`. Do not retry jsonpath with variations -- the field path may have changed between ACM versions.

---

## Steps

**Step 1: Identify catalog source and installed CSV**

```bash
ACM_NS=ocm
oc get catalogsource -A -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.image}{"\n"}{end}' | grep acm
oc get sub advanced-cluster-management -n $ACM_NS -o jsonpath='{.status.installedCSV}'
oc get multiclusterhub -n $ACM_NS -o jsonpath='{.items[0].status.currentVersion}'
```

**Step 2: Get the bundle image from the catalog pod**

```bash
CATALOG_POD=$(oc get pods -n openshift-marketplace \
  -l olm.catalogSource=acm-dev-catalog \
  -o jsonpath='{.items[0].metadata.name}')

oc exec -n openshift-marketplace $CATALOG_POD \
  -- cat /configs/advanced-cluster-management/bundles.yaml \
  | python3 -c "
import sys, yaml
for doc in yaml.safe_load_all(sys.stdin):
    if doc and doc.get('schema') == 'olm.bundle' and '2.16' in doc.get('name', ''):
        print(f'Bundle: {doc[\"name\"]}')
        print(f'Image: {doc.get(\"image\", \"N/A\")}')
"
```

If Python parsing fails, the full YAML dumps into history. Always pipe directly, never capture intermediate output.

**Step 3: Inspect the bundle image labels**

```bash
oc get secret multiclusterhub-operator-pull-secret -n $ACM_NS \
  -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d > /tmp/acm-auth.json
oc image info quay.io:443/acm-d/acm-operator-bundle@sha256:<DIGEST> -a /tmp/acm-auth.json
rm -f /tmp/acm-auth.json
```

**Step 4: Read the key labels**

| Label | What it tells you |
|-------|-------------------|
| `konflux.additional-tags` | Snapshot tag + version-build (e.g., `v2.16.0-252,snapshot-release-acm-216-20260223-010439-000`) |
| `build-date` | When the bundle image was built |
| `release` | Version-build number (e.g., `2.16.0-252`) |
| `vcs-ref` | Git commit SHA of the bundle repo |
| `com.redhat.openshift.versions` | Supported OCP version range |

---

## Output Format

Present as a summary table:

| Property | Value |
|---|---|
| **Snapshot Tag** | `snapshot-release-acm-216-YYYYMMDD-HHMMSS-000` |
| **Version-Build** | `v2.16.0-NNN` |
| **Release** | `2.16.0-NNN` |
| **Build Date** | `YYYY-MM-DDTHH:MM:SSZ` |
| **Git Commit** | `<sha>` |
| **OCP Compatibility** | `v4.18-v4.22` |

---

## DOWNSTREAM Tag Format (for JIRA)

Convert snapshot tag to DOWNSTREAM format: `<ACM_VERSION>-DOWNSTREAM-<YYYY-MM-DD-HH-MM-SS>`

Example: `snapshot-release-acm-216-20260223-010439-000` becomes `2.16.0-DOWNSTREAM-2026-02-23-01-04-39`

| Context | Format |
|---------|--------|
| Bug description (`h4. Version-Release number`) | `2.16.0-DOWNSTREAM-2026-02-23-01-04-39` |
| JIRA verification comment | "Verified on build `2.16.0-DOWNSTREAM-...`" |
| Regression reporting | "Regressed between `<tag-A>` and `<tag-B>`" |

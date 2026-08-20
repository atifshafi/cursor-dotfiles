# Environment Checks for Bug Verification

Procedures used during **Subagent 2 (Environment Assessor)** and **Phase 2.5 (Prerequisites)**. Pair with `~/.cursor/skills/acm-operations/SKILL.md` Operation 1 for full build-tag extraction.

---

## 1. Session kubeconfig

- Use a **session-specific** `KUBECONFIG` path (see global `.cursorrules` kubeconfig isolation).
- After login, run `oc whoami --show-server` and state the URL in the report.

---

## 2. Full DOWNSTREAM build tag

Users expect the **full** tag, not only CSV semver:

- Format: `VERSION-DOWNSTREAM-YYYY-MM-DD-HH-MM-SS` (full downstream identifier, not CSV semver alone).
- Derive from catalog bundle image labels (`konflux.additional-tags`, `build-date`) per `acm-operations` Op 1.
- **Quay path**: bundle images are typically `quay.io:443/acm-d/acm-operator-bundle@sha256:<digest>` — not `registry.redhat.io` paths copied from CSV alone.

---

## 3. OIDC / Keycloak clusters

**Symptom**: `oc login -u user -p pass` fails with OAuth discovery 404 or unsupported grant.

**Pattern**:

1. Obtain **ID token** (not access token) from Keycloak token endpoint (ROPC or device flow per env docs).
2. `oc login --token=<id_token> <api_server>`
3. For browser: Playwright `browser_fill_form` on Keycloak + OCP consent pages; avoid cursor-ide-browser for password flows.

Reference QE patterns in `stolostron/clc-ui-e2e` OIDC PRs when available.

---

## 4. Fix presence vs release branch

**Rule**: `main` merges do **not** appear in `release-2.XX` downstream builds unless cherry-picked or merged to that branch.

**CLI discovery** (GitHub):

```bash
gh pr list --repo stolostron/console --search "ACM-NNNNN" --state all \
  --json number,title,state,mergedAt,baseRefName,headRefName
```

For each candidate PR:

- Check `baseRefName` for `release-2.17` vs `main`.
- Search merged cherry-picks: `--base release-2.17` with same JIRA key in title/body.

**Date sanity**: merge timestamp vs bundle `build-date` — merge must be **before** build for "should be included" hypothesis (still confirm in cluster).

---

## 5. Code-level fix check in running cluster

When PR touched console backend or static assets:

1. Resolve console pod in ACM namespace (e.g. `ocm`).
2. `oc exec` + `grep -n` for distinctive string from the fix (function name, error message change).
3. Record pod image ID / digest if disputing cache.

---

## 6. Cluster capability matrix (quick)

Run / infer as appropriate:

| Check | Command / source |
|-------|------------------|
| ACM CSV / sub | `oc get sub,csv -n <acm_ns>` |
| MCH version / flags | `oc get mch -n <acm_ns> -o yaml` |
| FG-RBAC | MCH spec / feature flags + `oc get multiclusterroleassignments` |
| Managed clusters | `oc get managedcluster` |
| CNV / Virt add-on | `oc get csv -A`, `oc get managedclusteraddons -A` |
| Hive / pools | `oc get clusterpool -A`, hive operator CSV |
| Policies | `oc get policy -A` or governance CRDs per version |
| OAuth IDPs | `oc get oauth cluster -o yaml` |

---

## 7. Catalog refresh / upgrade (informational)

- Changing `CatalogSource` image or approving `InstallPlan` is **state-changing** — requires user permission per global rules.
- Before suggesting upgrade: show current vs target snapshot and risk (operator restart).

---

## 8. Common failure modes

| Symptom | Likely cause |
|---------|----------------|
| `jsonpath` array index out of bounds | No matching pod/resource; broaden label selector |
| CSRF errors on console proxy | Use Playwright `fetch` in page context, not raw curl |
| Password field clears on login | Wrong browser MCP — switch to Playwright |
| `oc image info` manifest unknown | Wrong registry host or missing pull secret |
| Spoke-only bug | `acm-kubectl` or kubeconfig for spoke; confirm ManagedCluster name |

---

## 9. Neo4j prerequisite hints

Use `neo4j-rhacm` MCP to map component → dependencies (operators, subsystems). Then map each dependency to section 6 checks. Cypher patterns live in `.cursor/rules/neo4j-rhacm.mdc` (project automation repo).

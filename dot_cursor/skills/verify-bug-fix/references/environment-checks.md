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

---

## 10. Version Compatibility Gate (Phase 0.5 Check 1)

**Purpose**: Catch ACM/OCP version mismatches before any verification work.

### Procedure

1. Get OCP version:
   ```bash
   oc get clusterversion version -o jsonpath='{.status.desired.version}'
   ```

2. Get ACM version (one of):
   - From JIRA `fix_versions` field (already fetched in Phase 0)
   - From cluster: `oc get csv -n <acm-ns> --no-headers | grep advanced-cluster-management`
   - For MCE-only: `oc get csv -n multicluster-engine --no-headers | grep multicluster-engine`

3. Read the version matrix:
   - Primary source: `~/Documents/work/notes/knowledge/versions/version-matrix.md` → "OCP Version Requirements" table
   - Fallback (if file missing): use the ranges below

4. Compare OCP version against the supported range for the ACM/MCE version:

   | ACM Version | MCE Version | OCP Minimum | OCP Maximum |
   |---|---|---|---|
   | 2.13 | 2.8 | 4.16 | 4.19 |
   | 2.14 | 2.9 | 4.17 | 4.20 |
   | 2.15 | 2.10 | 4.18 | 4.21 |
   | 2.16 | 2.11 | 4.19 | 4.21 |
   | 5.0 | 5.0 | 4.20 | 4.22+ |

5. **If OCP is below minimum or above maximum**: Emit INFEASIBLE.

### Evidence format (for INFEASIBLE verdict)

```
Environment: OCP {ocp_version} / ACM {acm_version}
Supported OCP range for ACM {acm_version}: {min} - {max}
Status: OCP {ocp_version} is BELOW/ABOVE the supported range.
Impact: ACM console dynamic plugins and UI routes will not function.
```

---

## 11. Feature-Area Infrastructure Requirements (Phase 0.5 Check 2)

**Purpose**: Identify bugs that require **architecturally impossible** infrastructure for the current environment.

### Classification Table

Scan the JIRA `summary` and `components` fields for keywords. Match the FIRST applicable row:

| Feature Area | Keywords | Hard Requirement | Cannot be added when... |
|---|---|---|---|
| KubeVirt HCP | "kubevirt", "KubeVirt", "attachDefaultNetwork", "HCP.*virt", "NodePool.*virt" | CNV + bare-metal/nested-virt workers | Workers are standard cloud VMs |
| Fleet Virtualization | "fleet virt", "virtual machine", "VM migration", "CCLM", "cross-cluster live migration" | CNV on spoke + bare-metal spoke workers | Spoke workers are cloud VMs |
| Submariner | "submariner", "service discovery", "globalnet", "clusterset.*network" | 2+ clusters with L3 connectivity | Only local-cluster exists |
| Disconnected | "disconnected", "air-gap", "mirror registry", "ICSP", "imageContentSourcePolicy" | Network isolation + mirror registry | Cluster is connected |
| Bare-metal provisioning | "bare metal", "BMC", "Metal3", "assisted installer", "infraenv" (without "kubevirt") | Metal3 + BMC + physical hosts | Platform is cloud |
| Other / Unknown | *(no keyword match)* | **No hard gate** | N/A — proceed |

### Hard vs Soft distinction

**Hard prerequisites (Phase 0.5 gates on these)**:
- Physical hardware requirements (bare-metal, BMC access)
- Network topology requirements (disconnected, multi-cluster connectivity)
- Multiple-cluster requirements (Submariner needs 2+ clusters)

**Soft prerequisites (Phase 2.5 handles these)**:
- Installable operators (Observability, GitOps, Ansible, Global Hub, Hive)
- Configurable credentials (cloud provider, pull secrets)
- Feature flags (MCH components, FG-RBAC)
- Managed cluster addons (search, policy, app-manager)

Rule: If a missing prerequisite can be resolved with `oc apply` or operator install (without hardware changes), it belongs in Phase 2.5, not Phase 0.5.

---

## 12. Platform Capability Assessment (Phase 0.5 Check 3)

**Purpose**: Given a hard requirement from Check 2, determine if the current cluster CAN satisfy it.

### Assessment Methods

| Hard Requirement | How to Check | NOT POSSIBLE verdict |
|---|---|---|
| Bare-metal / nested-virt workers | `oc get nodes -o jsonpath='{.items[*].metadata.labels.node\.kubernetes\.io/instance-type}'` | All instance types are standard VMs (m5.xlarge, Standard_D4s_v3, e2-standard-4, etc.) |
| Multiple managed clusters | `oc get managedclusters --no-headers | wc -l` | Count = 1 (only local-cluster) AND no ClusterDeployments pending |
| Network isolation | `curl -s -o /dev/null -w "%{http_code}" https://quay.io` (from a pod) | Returns 200 (cluster is connected — cannot be made disconnected) |
| Physical hosts / BMC | `oc get infrastructure cluster -o jsonpath='{.status.platformStatus.type}'` | Type is AWS, Azure, GCP, or other cloud |

### Instance Type Reference (common cloud types that are NOT metal)

| Cloud | Standard (NOT metal) | Metal (supports CNV) |
|---|---|---|
| AWS | m5.xlarge, m5.2xlarge, c5.xlarge, r5.xlarge | m5.metal, c5.metal, i3.metal, m5zn.metal |
| Azure | Standard_D4s_v3, Standard_D8s_v3, Standard_E4s_v3 | Standard_D*_v5 with nested virt (limited) |
| GCP | e2-standard-4, n2-standard-8 | c2-standard-60 (bare-metal equivalent) |

### Output Format

Produce for each hard requirement:

```
Requirement: {requirement}
Assessment: {POSSIBLE | NOT POSSIBLE | POSSIBLE WITH ADDITIONAL SETUP}
Evidence: {command output or reasoning}
```

If ANY requirement is NOT POSSIBLE → the overall gate verdict is INFEASIBLE (subject to Tier C viability criteria in SKILL.md Phase 0.5).

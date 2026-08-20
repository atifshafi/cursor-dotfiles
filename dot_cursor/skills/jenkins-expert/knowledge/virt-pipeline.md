<!-- Last verified: 2026-08-10 against acmqe-autotest components/console/Jenkinsfile_console_virt_e2e -->
<!-- Verify paths and counts against the live repo before acting on specifics -->

# Console Virt/FG-RBAC Playwright Pipeline Reference

## Location
- Jenkinsfile: `acmqe-autotest/ci/jenkinsfiles/components/console/Jenkinsfile_console_virt_e2e`
- Test repo: `stolostron/console-e2e` (Playwright), branch controlled by `CONSOLE_GIT_BRANCH`
- Agent pod: `ciAgentPod_console.yaml` (ubi9-playwright)
- Timeout: 8 hours (vs 120 min for other console pipelines)

## Pipeline Stages

| Stage | Condition | Duration |
|-------|-----------|----------|
| Validate Parameters | Always | instant |
| Checkout Test Code | Always | ~10s |
| Install Dependencies | Always (npm ci) | ~30s |
| Azure Spoke Provisioning | VIRT_TIER includes azure | ~50 min (downstream) |
| BM Spoke Provisioning | VIRT_TIER includes bm | ~30 min (downstream) |
| RBAC User Setup | Always | ~2 min (gen-rbac.sh, install-glauth.sh, setup-test-roles.sh) |
| Platform Detection | Always | ~5s |
| Test Execution | Always | 10-90 min (depends on tier) |
| Post Actions | Always | ~30s (archive artifacts + junit) |

## Parameters

| Parameter | Default | Purpose |
|-----------|---------|---------|
| OCP_API_URL | (required) | Hub API URL |
| OCP_USER | kubeadmin | Hub admin user |
| OCP_PASSWORD | (required) | Hub password |
| CONSOLE_IDP | kube:admin | Identity provider |
| CONSOLE_GIT_BRANCH | main | console-e2e branch |
| VIRT_SPOKE_CLUSTER | (auto-discover) | Spoke cluster name |
| VIRT_TIER | full | Test tier: `full`, `vm`, `rbac-ui`, or custom tag |
| RBAC_TEST_PASSWORD | (required for RBAC) | Password for clc-e2e-* test users |
| CNV_VERSION | (auto-detect) | CNV version on spoke |
| PLAYWRIGHT_GREP | (empty) | Tag filter override |
| EXTRA_PLAYWRIGHT_ARGS | (empty) | Extra Playwright CLI args |
| CI_GIT_BRANCH | main | acmqe-autotest branch |

## Tier-Based Test Selection

| Tier | Tags | Specs | When |
|------|------|-------|------|
| full (Azure) | `@fg-rbac`, `@fleet-virt` | fg-rbac + fleet-virt specs | Azure spoke with CNV |
| vm | `@fleet-virt` | Fleet virt specs only | Spoke with CNV but not Azure |
| rbac-ui | `@fg-rbac` | FG-RBAC specs only | Spoke without CNV |
| custom | (PLAYWRIGHT_GREP) | User-provided | PLAYWRIGHT_GREP set |

## RBAC Setup Scripts (from console-e2e repo)

Run in order during RBAC User Setup stage:
1. `scripts/rbac/gen-rbac.sh` -- creates htpasswd IDP, test users (clc-e2e-* prefix)
2. `scripts/rbac/install-glauth.sh` -- configures LDAP identity provider (glauth)
3. `scripts/rbac/setup-test-roles.sh` -- creates MCRAs, OCP groups, Placements for test scenarios

## Downstream Pipelines Called

| Job | When |
|-----|------|
| CI-Jobs/virt_cclm_tests | Spoke provisioning (Azure: UI-based, BM: MIST-based) |
| CI-Jobs/ClusterLifecycle/clc_bm_spoke_provisioning | BM MIST spoke provisioning |

## JUnit XML Chain

```
Playwright junit reporter -> test-results/junit.xml
Jenkinsfile post -> archiveArtifacts '**/test-results/**' + junit '**/test-results/*.xml'
fix-junit-polarion-names.sh -> normalizes test names for Polarion
```

## Env Variable Mapping (Pipeline -> Playwright)

| Pipeline Param | Env Var | Playwright Config |
|---------------|---------|-------------------|
| OCP_API_URL | HUB_URL | getHubAuth().hubUrl |
| OCP_PASSWORD | HUB_PASSWORD | getHubAuth().password |
| OCP_USER | CONSOLE_USERNAME | getHubAuth().username |
| CONSOLE_IDP | CONSOLE_IDP | getHubAuth().idp |
| VIRT_SPOKE_CLUSTER | VIRT_SPOKE_CLUSTER | getRbacConfig().spokeCluster |
| RBAC_TEST_PASSWORD | RBAC_TEST_PASSWORD | getRbacUsers() passwords |

<!-- Last verified: 2026-08-10 -->
<!-- Verify paths and counts against the live repo before acting on specifics -->

# Parameter Mapping Reference

## Orchestrator → Component Parameter Mapping

### CLC (clc.groovy → clc-e2e-pipeline)

| Orchestrator Param | clc.groovy Maps To | CLC Pipeline Param |
|-------------------|-------------------|-------------------|
| OCP_HUB_CLUSTER_USER | CYPRESS_OPTIONS_HUB_USER | Hub username |
| OCP_HUB_CLUSTER_PASSWORD | CYPRESS_OPTIONS_HUB_PASSWORD | Hub password |
| OCP_HUB_API_URL (→ API_URL) | CYPRESS_HUB_API_URL | Hub API URL |
| OCP_HUB_IDP (→ IDP_USER) | CYPRESS_OC_IDP | Identity provider |
| TEST_GIT_BRANCH | GIT_BRANCH | clc-ui-e2e branch |
| HIVE_CLOUD_PROVIDERS | CLOUD_PROVIDERS | Cloud providers for create |
| SNO_CLUSTERS | SNO_CLUSTERS | SNO cluster list |
| CLUSTER_POOL | CLUSTER_POOL | Cluster pool providers |
| IMPORT_KUBERNETES_CLUSTERS | IMPORT_KUBERNETES_CLUSTERS | Import cluster types |
| HIVE_OCP_VERSION | CYPRESS_CLC_OCP_IMAGE_VERSION | OCP image version |
| FIPS_ENABLED | FIPS | FIPS flag |
| BROWSER | BROWSER | Browser type |
| TEST_TAGS (→ testStage logic) | TEST_STAGE | create/e2e/destroy/all/etc. |

### Virt Playwright (Jenkinsfile_console_virt_e2e → console-e2e)

| Pipeline Param | Env Var | Playwright Config |
|---------------|---------|-------------------|
| OCP_API_URL | HUB_URL | getHubAuth().hubUrl |
| OCP_PASSWORD | HUB_PASSWORD | getHubAuth().password |
| OCP_USER | CONSOLE_USERNAME | getHubAuth().username |
| CONSOLE_IDP | CONSOLE_IDP | getHubAuth().idp |
| CONSOLE_GIT_BRANCH | (checkout) | console-e2e branch |
| VIRT_SPOKE_CLUSTER | VIRT_SPOKE_CLUSTER | getRbacConfig().spokeCluster |
| RBAC_TEST_PASSWORD | RBAC_TEST_PASSWORD | getRbacUsers() passwords |
| VIRT_TIER | VIRT_TIER | Tier-based test selection |
| CNV_VERSION | CNV_VERSION | Fleet Virt version detection |
| PLAYWRIGHT_GREP | PLAYWRIGHT_GREP | Tag filter |

### ALC Console (alc.groovy → alc_e2e_tests)

| Orchestrator Param | alc.groovy Maps To | ALC Param |
|-------------------|-------------------|-----------|
| OCP_HUB_CLUSTER_USER | OCP_HUB_CLUSTER_USER | Hub username |
| OCP_HUB_CLUSTER_PASSWORD | OCP_HUB_CLUSTER_PASSWORD | Hub password |
| OCP_HUB_API_URL | OCP_HUB_CLUSTER_API_URL | Hub API URL |
| OCP_HUB_IDP | OCP_HUB_IDP | Identity provider |
| TEST_GIT_BRANCH | TEST_GIT_BRANCH | Test repo branch |
| CI_GIT_BRANCH | CI_GIT_BRANCH | CI branch |
| BROWSER | BROWSER | Browser type |

### GRC (grc.groovy → grc-e2e-test-execution)

| Orchestrator Param | grc.groovy Maps To | GRC Param |
|-------------------|-------------------|-----------|
| OCP_HUB_CLUSTER_USER | OCP_HUB_CLUSTER_USER | Hub username |
| OCP_HUB_CLUSTER_PASSWORD | OCP_HUB_CLUSTER_PASSWORD | Hub password |
| OCP_HUB_CLUSTER_URL | OCP_HUB_CLUSTER_URL | Console URL |
| TEST_GIT_BRANCH | GIT_BRANCH | Test branch |
| BROWSER | BROWSER | Browser type |

### Console Playwright (all 6 Jenkinsfile_console_* pipelines)

| Pipeline Param | Env Var | Playwright Config |
|---------------|---------|-------------------|
| OCP_API_URL | HUB_URL | getHubAuth().hubUrl |
| OCP_PASSWORD | HUB_PASSWORD | getHubAuth().password |
| OCP_USER | CONSOLE_USERNAME | getHubAuth().username |
| CONSOLE_IDP | CONSOLE_IDP | getHubAuth().idp |
| CONSOLE_GIT_BRANCH | (checkout) | console-e2e branch |
| PLAYWRIGHT_GREP | PLAYWRIGHT_GREP | Tag/test filter |
| PLAYWRIGHT_GREP_INVERT | PLAYWRIGHT_GREP_INVERT | Exclude filter |
| EXTRA_PLAYWRIGHT_ARGS | (appended to CLI) | Extra args after start.sh |

## Naming Convention Mismatches

These are the most common sources of confusion:

| Orchestrator Name | CLC/Virt Name | Why Different |
|------------------|---------------|---------------|
| OCP_HUB_CLUSTER_USER | CYPRESS_OPTIONS_HUB_USER | Cypress prefix convention |
| OCP_HUB_CLUSTER_PASSWORD | CYPRESS_OPTIONS_HUB_PASSWORD | Cypress prefix convention |
| OCP_HUB_API_URL | CYPRESS_HUB_API_URL | Cypress prefix convention |
| TEST_GIT_BRANCH | GIT_BRANCH (CLC) / CLC_UI_BRANCH (virt) | Repo-specific naming |
| HIVE_CLOUD_PROVIDERS | CLOUD_PROVIDERS | Orchestrator adds HIVE_ prefix |
| HIVE_OCP_VERSION | CYPRESS_CLC_OCP_IMAGE_VERSION | Completely different naming |

## Environment Variable Flow (in test execution)

After parameters reach the test repo, they become environment variables:

### CLC start-tests.sh
```
CYPRESS_HUB_API_URL → oc login + CYPRESS_BASE_URL (from oc whoami --show-console)
CYPRESS_OPTIONS_HUB_USER → login user
CYPRESS_OPTIONS_HUB_PASSWORD → login password
TEST_STAGE → routes to run_create/run_validate/run_destroy/etc.
NODE_ENV=virt → routes to virtualization pipeline path
CUSTOMER_TAGS → grepTags for Cypress cy-grep
```

### Cypress test access
```javascript
Cypress.env('OPTIONS_HUB_USER')    // from CYPRESS_OPTIONS_HUB_USER
Cypress.env('HUB_API_URL')         // from CYPRESS_HUB_API_URL
Cypress.env('VIRT_SPOKE_CLUSTER')  // from CYPRESS_VIRT_SPOKE_CLUSTER
Cypress.env('CLC_RBAC_PASS')      // from CYPRESS_CLC_RBAC_PASS
```

## archArtifacts Filter Patterns (per component)

| Component | archArtifacts Filter | Target |
|-----------|---------------------|--------|
| CLC | `reports/*.xml` | `results/clc_ui` |
| Virt | `reports/*.xml` | `results/virt_ui` |
| CAPA | `results/**/*.xml` | `results/capi` |
| CAPZ | `results/**/*.xml` | `results/capz` |
| Hypershift | `hypershift/e2e-go/pkg/test/results/*.xml` | `results/hypershift` |
| Server Foundation | `results/*.xml` | `results/server_foundation` |
| GRC | `grc-ui/results/*.xml` (etc.) | `results/grc_ui` + `grc_api` + `grc_framework` |
| ALC Console | `results/*.xml` | `results/app_ui` |
| Search | `results/*.xml` | `results/search` + `results/search_api` |
| Observability | `results/**/*.xml` | `results/observability` |

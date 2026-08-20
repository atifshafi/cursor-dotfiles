<!-- Last verified: 2026-08-10 against live Jenkins CI-Jobs/e2e_ui_test_pipeline (build #839) -->
<!-- Verify paths and counts against the live repo before acting on specifics -->

# e2e_ui_test_pipeline -- Orchestrator Reference

## Location
- Jenkins: `CI-Jobs/e2e_ui_test_pipeline`
- Jenkinsfile: `acmqe-autotest/ci/jenkinsfiles/e2e/e2e-common/Jenkinsfile`
- Parameters: `ciParams.getE2eParams()`

## Stage List (in execution order)

Each stage is gated by `params.TEST_STAGES.contains('STAGE_NAME')`.

| Stage Name | Groovy Wrapper | Downstream Job | Results Path |
|------------|---------------|----------------|--------------|
| PRE_CONFIG | `install.callOperatorsInstall()` | CI-Jobs/operators_install | -- |
| CI_SETUP | `ci.callCiSetup()` | CI-Jobs/ci_setup_and_config | cidata/ |
| CLC_CREATE | `clc.clcCreateUI()` | qe-acm-automation-poc/clc-e2e-pipeline | results/clc_ui |
| VIRT_CONSOLE | `virt.callVirtE2E()` | CI-Jobs/virt_console_e2e_tests | results/virt_ui |
| CAPA | `capa.callCAPA()` | CI-Jobs/capi_tests | results/capi |
| CAPZ | `capz.callCAPZ()` | CI-Jobs/capz_tests | results/capz |
| FETCH_CLUSTERS | `managedClusters.callManagedClusters()` | CI-Jobs/fetch_managed_clusters_info | -- |
| HYPERSHIFT | `hypershift.callHypershift()` | CI-Jobs/hypershift-acmqe-e2e | results/hypershift |
| SERVER_FOUNDATION | `serverfoundation.callServerFoundation()` | CI-Jobs/server_foundation_e2e_tests | results/server_foundation |
| DISCOVERY | `discovery.callDiscoveryCLI()` | CI-Jobs/discovery_cli_tests | results/discovery |
| GRC | `grc.callGRC()` | qe-acm-automation-poc/grc-e2e-test-execution | results/grc_ui + grc_api + grc_framework |
| ALC_CONSOLE | `alc.callALCConsole()` | qe-acm-automation-poc/alc_e2e_tests | results/app_ui |
| ALC_BACKEND | `alc.callALCBackend()` | CI-Jobs/alc_backend_tests | results/alc_backend |
| OBSERVABILITY | `obs.callObservability()` | qe-acm-automation-poc/obs-e2e-test-execution | results/observability |
| SEARCH | `search.callSearch()` | qe-acm-automation-poc/search-e2e-test-execution | results/search + search_api |
| HOH | `globalhub` | regionalhub-create, globalhub-e2e | results/hoh |
| SUBMARINER | `submariner` | qe-acm-automation-poc/submariner | results/submariner |
| HDRAPP | `hdrapp` | qe-acm-automation-poc/hdrapp | results/hdrapp |
| VOLSYNC | `volsync` | qe-acm-automation-poc/volsync | results/volsync |
| HDRVIRT | `hdrvirt` | qe-acm-automation-poc/hdrvirt | results/hdrvirt |
| DR4HUB | `dr4hub` | qe-acm-automation-poc/dr4hub | results/dr4hub |
| RIGHTSIZING | `rightsizing` | qe-acm-automation-poc/rightsizing | results/rightsizing |
| SITE_CONFIG | `siteconfig` | (siteconfig tests) | results/site_config |
| INSTALL | `install` | (install tests) | results/install |
| ACM_MUST_GATHER | `mustgather` | (must-gather) | -- |
| HOH_DESTROY | `globalhub` | (regional hub destroy) | -- |
| CLC_DESTROY | `clc.clcDestroyUI()` | qe-acm-automation-poc/clc-e2e-pipeline (destroy) | results/clc_ui |
| RESULTS_SUMMARY | `testsummary.callTestSummary()` | (generates summary) | -- |
| POLARION | `polarion.callPolarion()` | push_results_to_polarion | -- |
| REPORT_PORTAL | `reportportal.callReportPortal()` | (report portal) | -- |
| TEARDOWN_ENV | `teardown.callTeardown()` | (scheduled teardown) | -- |

## Default TEST_STAGES

```
PRE_CONFIG,CI_SETUP,INSTALL,CLC_CREATE,CAPA,CAPZ,FETCH_CLUSTERS,HYPERSHIFT,
ALC_CONSOLE,ALC_BACKEND,GRC,SEARCH,OBSERVABILITY,DISCOVERY,SERVER_FOUNDATION,
DR4HUB,VOLSYNC,HDRAPP,HDRVIRT,RIGHTSIZING,SITE_CONFIG,HOH,ACM_MUST_GATHER,
HOH_DESTROY,RESULTS_SUMMARY,POLARION,REPORT_PORTAL,
```

VIRT_CONSOLE is NOT in the default -- it is opt-in.

## Substring Collision Warning

`TEST_STAGES.contains()` does substring matching. These collisions exist:
- `ALC` matches `ALC_CONSOLE` and `ALC_BACKEND` (intentional parent gate)
- `HOH` matches `HOH_DESTROY` (intentional)
- `VIRT` would match `HDRVIRT` (DANGEROUS -- use `VIRT_CONSOLE` instead)

When naming new stages, always check the default TEST_STAGES string for substrings.

## Aggregate Report Stage

After all component stages complete:
```groovy
archiveArtifacts artifacts: 'results/**/*', followSymlinks: false
junit 'results/**/*.xml'
```
This collects all JUnit XML from all component subdirectories under `results/`.

## How to Add a New Component to the Orchestrator

### 5-file pattern (follow exactly):

**1. `ci/jenkinsfiles/vars/<component>.groovy`**
```groovy
def call<Component>E2E(params, apiUrl) {
    try {
        def buildResult = build propagate: false,
            job: "${ciUtils.getCIJobsFolder()}/<jenkins_job_name>",
            parameters: [
                string(name: 'PARAM_1', value: "${...}"),
                ...]
        return buildResult
    } catch(ex) {
        echo '<Component> E2E failed: ' + ex.getMessage()
        echo '... Continuing with the pipeline'
    }
}
```

**2. `ci/jenkinsfiles/e2e/e2e-common/Jenkinsfile`**
```groovy
stage('Run <Component> E2E Tests') {
    when {
        expression { params.TEST_STAGES.contains('<STAGE_NAME>') }
    }
    steps {
        script {
            def buildResult = <component>.call<Component>E2E(params, API_URL)
            results["<result_key>"] = buildResult.getAbsoluteUrl()
            ciUtils.archArtifacts("${CI_Jobs_folder}/<job_name>",
                "${buildResult.getNumber()}", "reports/*.xml", 'results/<result_key>')
        }
    }
}
```

**3. `ci/jenkinsfiles/vars/ciParams.groovy`** -- add to `getSupportedTestComponents()`:
```groovy
return ['', ..., '<STAGE_NAME>']
```

**4. `ci/jenkinsfiles/vars/ciUtils.groovy`** -- add case to `getComponentInfo()`:
```groovy
case "<result_key>":
    componentMap["name"] = '<DISPLAY_NAME>'
    componentMap["owners"] = '@slack-team-handle'
    break
```

**5. `ci/polarion/polarion_helpers.py`** -- add to `map_automation_squad_name_to_polarion_squad_name()`:
```python
elif automation_squad_name == "<result_key>":
    return "<polarion_squad>"
```

### Testing:
1. Test standalone pipeline first (JUnit XML generated?)
2. Merge to main (shared library requires it)
3. Trigger orchestrator with `TEST_STAGES=<STAGE_NAME>,POLARION`
4. Verify: artifacts archived, JUnit collected, Polarion updated

## Additional Parameters (not in getE2eParams)

These are set at the Jenkins job level, not in the shared library:

| Parameter | Default | Purpose |
|-----------|---------|---------|
| STREAM | (empty) | Regression stream type: `y-stream`, `z-stream` |
| HUB_CREDS | (empty) | Link to hub credentials spreadsheet |
| JIRA_TICKET | (empty) | JIRA ticket for the regression run |
| SLACK_MESSAGE_TITLE | (empty) | Custom Slack message title for results |
| DELETION_TIMEFRAME_IN_HOURS | 24 | Hours before scheduling managed cluster destruction |
| BACKUP_S3_BUCKET_PREFIX | (empty) | S3 bucket location for backups |
| GH_CATALOG_IMAGE | (empty) | Global Hub downstream build package |
| GH_CHANNEL | release-1.0 | Global Hub operator channel |

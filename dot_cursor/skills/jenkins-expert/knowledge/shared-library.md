<!-- Last verified: 2026-08-10 against acmqe-autotest ci/jenkinsfiles/vars/ -->
<!-- Verify paths and counts against the live repo before acting on specifics -->

# Jenkins Shared Library Reference

## How It Works

All Jenkinsfiles declare `@Library('ci-shared-lib') _` which loads the shared library
from the `acmqe-autotest` repo. The library name `ci-shared-lib` is configured in
Jenkins under "Manage Jenkins > Global Pipeline Libraries" pointing to the repo's
`main` branch.

Each `.groovy` file in `ci/jenkinsfiles/vars/` becomes a globally available object.
The filename (minus `.groovy`) is the object name: `clc.groovy` → `clc.clcCreateUI(...)`.

### Branch Constraint
The shared library loads from `main` only. New `.groovy` files are NOT available
to the orchestrator until merged to main. This is the key limitation for testing
new component integrations.

Rare override: `@Library('ci-shared-lib@branch-name') _` (seen in a few Tower pipelines).

## Key Infrastructure Files

### ciUtils.groovy
Utility functions used by all pipelines:
- `getCIJobsFolder()` → `"CI-Jobs"`
- `getQEJobsFolder()` → `"qe-acm-automation-poc"`
- `archArtifacts(jobName, buildNumber, filter, target)` → CopyArtifact from downstream
- `getEnvURL(branch, clusterUrl)` → derives console URL
- `getComponentInfo(component)` → returns name + Slack owners for notifications
- `getJenkinsCloud()` → load-balances across cloud pools for agent scheduling
- `getInstallJobsFolder(subfolder)` → resolves install job paths

### ciParams.groovy
Central parameter definitions:
- `getE2eParams()` → hub, tests, CLC, HOH, backup, branch, reporting params
- `getTestStages()` → default TEST_STAGES string (comma-separated)
- `getSupportedTestComponents()` → list for Polarion COMPONENT choice

### polarion.groovy
- `callPolarion(params, upstreamJob, buildNumber)` → triggers `push_results_to_polarion`
- `updatePolarionTestRun(component, testRunId, resultsPath)` → component-level push

### slack.groovy
- `sendE2EStart()`, `sendE2ECompleted()`, `sendE2EFailed()`
- `getChannel(component)` → maps component to Slack channel
- `sendMessage()` → generic Slack post

## Component Wrapper Pattern

Every component follows the same pattern in its `vars/*.groovy` file:

```groovy
def callComponentE2E(params, apiUrl) {
    try {
        def buildResult = build propagate: false,
            job: "${ciUtils.getCIJobsFolder()}/job_name",
            parameters: [
                string(name: 'PARAM', value: "${params.ORCHESTRATOR_PARAM}"),
                ...]
        return buildResult
    } catch(ex) {
        echo 'Component E2E failed: ' + ex.getMessage()
        echo '... Continuing with the pipeline'
    }
}
```

Key conventions:
- `propagate: false` -- don't fail the orchestrator if the component fails
- `try/catch` -- log and continue so other stages can run
- Return `buildResult` so the orchestrator can call `.getAbsoluteUrl()` and `.getNumber()`
- Job paths use `getCIJobsFolder()` or `getQEJobsFolder()` -- never hardcode

## Registration Points (When Adding a New Component)

### 1. ciParams.groovy -- `getSupportedTestComponents()`
Add the stage name to the list. Used by Polarion job's COMPONENT choice parameter.

### 2. ciUtils.groovy -- `getComponentInfo(component)`
Add a `case` block with:
- `componentMap["name"]` -- display name for Slack notifications
- `componentMap["owners"]` -- Slack handle to tag on failures

Existing entries for reference:
```groovy
case "app_ui": case "alc": case "alc_console":
    componentMap["name"] = 'ALC_CONSOLE'
    componentMap["owners"] = '<@U058MT35T18>'  // individual user
    break
case "clc_ui": case "clc":
    componentMap["name"] = 'CLC'
    componentMap["owners"] = '@acm-qe-workload-mgmt'  // team group
    break
case "virt_ui":
    componentMap["name"] = 'VIRT_CONSOLE'
    componentMap["owners"] = '@acm-qe-cnv-hcp'
    break
```

### 3. ciParams.groovy -- `getTestStages()` (optional)
Add the stage name to the default TEST_STAGES if it should run in every regression.
Leave it out for opt-in stages (like VIRT_CONSOLE).

## Additional vars/*.groovy Files

| File | Purpose |
|------|---------|
| `k8s.groovy` | Managed K8s cluster deploy/destroy wrappers: `deployEKSCluster()`, `deployAKSCluster()`, `deployGKECluster()` + destroy equivalents |
| `mce.groovy` | MCE install/uninstall on K8s clusters: `installMceOnK8s(params, kubeconfigPath)`, `uninstallMceOnK8s(params)` |

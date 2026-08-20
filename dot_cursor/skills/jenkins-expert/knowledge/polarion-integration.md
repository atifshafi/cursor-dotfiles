# Polarion Integration Reference

## Two Push Mechanisms

### 1. `polarion.callPolarion(params, upstreamJobName, upstreamJobBuildNumber)`
Used by the e2e orchestrator. Passes full environment metadata (cloud provider, OCP version,
ACM image, test tags, test type, Polarion plan ID). Auto-generates test run IDs per component.

### 2. `polarion.updatePolarionTestRun(component, testRunId, resultsPath)`
Used by standalone component pipelines (Discovery, Install). Passes only component name,
explicit test run ID, and results path. Simpler but requires knowing the run ID upfront.

Both trigger the downstream `push_results_to_polarion` Jenkins job.

## Push Flow (Orchestrator Path)

```
1. polarion.callPolarion() triggers push_results_to_polarion job
2. push_results_to_polarion Jenkinsfile:
   a. CopyArtifact: copies results/**/*.* from upstream build
   b. Runs: python3 polarion/push_results_to_polarion.py
3. Python script:
   a. Iterates subdirectories of results/ (each = component)
   b. Per component: reads all *.xml files
   c. Extracts test case IDs from JUnit XML
   d. Maps component name to Polarion squad
   e. Creates/updates Polarion TestRun
   f. Updates test records (passed/failed/blocked)
```

## Test ID Extraction from JUnit XML

The `polarion_helpers.py` function `get_test_case_end_result()`:
1. Reads `name` attribute of `<testcase>` element
2. If `name` starts with project ID (e.g., `RHACM4K`), splits on `:` to get ID
3. Falls back to `classname` attribute if `name` doesn't match
4. Example: `name="RHACM4K-60558: Tree View (sanity): Toggle Button"` → ID = `RHACM4K-60558`

The `testCaseSwitchClassnameAndName: true` setting in Cypress config swaps classname/name
so the test title (containing the Polarion ID) ends up in the `name` field.

## Squad Mapping (polarion_helpers.py)

`map_automation_squad_name_to_polarion_squad_name(automation_squad_name)`:

| Component Key (results/ subdir) | Polarion Squad |
|--------------------------------|----------------|
| ci | ci |
| app_ui, alc, alc_console, app_api, virt_ui | console |
| app_non_ui, alc_backend | application |
| clc_ui, clc | cluster |
| server_foundation | serverfoundation |
| discovery | discovery |
| grc_ui, grc_framework, grc, grc_api | grc |
| observability | obs |
| search, search_api, search-canary | search |
| install | install |
| dr4hub, volsync, hdrapp, hdrvirt | backuprestore |
| hoh | hoh |
| maestro | maestro |
| hypershift | hypershift |
| mce | Multi_Cluster_Engine |
| capi, capa | capi |
| capz | capz |
| rightsizing | analytics |
| (anything else) | common |

## Polarion Connection

- Endpoint: `https://polarion.engineering.redhat.com/polarion`
- Project: `RHACM4K`
- User: `acm_machine` (service account)
- Template: `acmqe-automation-template`
- Library: Pylero (`TestRun.create`, `TestRecord`)

## Debugging Polarion Push Failures

1. **No JUnit XML**: Check component pipeline artifacts -- are `reports/*.xml` files archived?
2. **Empty results directory**: Check `ciUtils.archArtifacts()` filter matches the actual XML path
3. **Wrong squad**: Verify the `results/<key>/` directory name matches the squad mapping
4. **Missing test IDs**: Ensure test names start with `RHACM4K-XXXXX:` (the `:` separator is required)
5. **Test not in Polarion**: Check if the work item ID exists in project RHACM4K
6. **Shared lib not loaded**: `virt.groovy` (or new component files) only available after merge to main

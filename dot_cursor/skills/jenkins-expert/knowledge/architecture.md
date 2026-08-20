<!-- Last verified: 2026-08-10 against acmqe-autotest main -->
<!-- Verify paths and counts against the live repo before acting on specifics -->

# ACM Jenkins CI/CD Architecture

## Pipeline Hierarchy

```
e2e_ui_test_pipeline (CI-Jobs/) ── THE ORCHESTRATOR
│
├── PRE_CONFIG ──► install.callOperatorsInstall()
├── CI_SETUP ──► ci.callCiSetup()
├── CLC_CREATE ──► clc.clcCreateUI() ──► qe-acm-automation-poc/clc-e2e-pipeline
├── VIRT_CONSOLE ──► virt.callVirtE2E() ──► CI-Jobs/virt_console_e2e_tests
├── CAPA ──► capa.callCAPA() ──► CI-Jobs/capi_tests
├── CAPZ ──► capz.callCAPZ() ──► CI-Jobs/capz_tests
├── FETCH_CLUSTERS ──► managedClusters.callManagedClusters()
├── HYPERSHIFT ──► hypershift.callHypershift()
├── SERVER_FOUNDATION ──► serverfoundation.callServerFoundation()
├── DISCOVERY ──► discovery.callDiscoveryCLI() / Cypress
├── GRC ──► grc.callGRC()
├── ALC_CONSOLE ──► alc.callALCConsole() ──► qe-acm-automation-poc/alc_e2e_tests
├── ALC_BACKEND ──► alc.callALCBackend() ──► CI-Jobs/alc_backend_tests
├── OBSERVABILITY ──► obs.callObservability()
├── SEARCH ──► search.callSearch()
├── HOH ──► globalhub (regional hub create/test/destroy)
├── SUBMARINER ──► submariner
├── DR4HUB ──► dr4hub
├── VOLSYNC ──► volsync
├── HDRAPP ──► hdrapp
├── HDRVIRT ──► hdrvirt
├── RIGHTSIZING ──► rightsizing
├── SITE_CONFIG ──► siteconfig
├── INSTALL ──► install
├── ACM_MUST_GATHER ──► mustgather
├── CLC_DESTROY ──► clc.clcDestroyUI()
├── RESULTS_SUMMARY ──► testsummary.callTestSummary()
├── POLARION ──► polarion.callPolarion()
├── REPORT_PORTAL ──► reportportal.callReportPortal()
└── TEARDOWN_ENV ──► teardown.callTeardown()
```

## Standalone Pipelines (not orchestrator-managed)

| Pipeline | Jenkins Path | Jenkinsfile |
|----------|-------------|-------------|
| virt_console_e2e_tests | CI-Jobs/virt_console_e2e_tests | acmqe-autotest: ci/jenkinsfiles/components/virt/Jenkinsfile_virt_e2e |
| virt_cclm_tests | CI-Jobs/virt_cclm_tests | acmqe-autotest: ci/jenkinsfiles/components/virt/Jenkinsfile_cclm_setup |
| clc_post_config | CI-Jobs/ClusterLifecycle/clc_post_config | acmqe-autotest |
| clc_bm_spoke_provisioning | CI-Jobs/ClusterLifecycle/clc_bm_spoke_provisioning | acmqe-autotest |
| push_results_to_polarion | CI-Jobs/push_results_to_polarion | acmqe-autotest: ci/jenkinsfiles/polarion/Jenkinsfile |
| Console Playwright (6 pipelines) | (see `console-e2e-pipelines.md`) | acmqe-autotest: ci/jenkinsfiles/components/console/ |
| ocp_deploy_and_acm_install | CI-Jobs/ocp_deploy_and_acm_install | acmqe-autotest: ci/jenkinsfiles/ocp_deployment_acm_install/common/Jenkinsfile |
| pics_cloud_deploy / destroy | CI-Jobs/pics_cloud_deploy, pics_cloud_destroy | acmqe-autotest: ci/jenkinsfiles/ocp/self-managed-ocp/ |
| acm-install / uninstall | acm/acm-install, acm/acm-uninstall | acmqe-autotest: ci/jenkinsfiles/acm/ |

## Jenkins Folder Structure

```
Jenkins Root
├── CI-Jobs/                              ← ciUtils.getCIJobsFolder()
│   ├── e2e_ui_test_pipeline              ← main orchestrator
│   ├── virt_console_e2e_tests            ← virt standalone
│   ├── virt_cclm_tests                   ← CCLM/spoke setup
│   ├── capi_tests, capz_tests            ← CAPI/CAPZ
│   ├── alc_backend_tests                 ← ALC backend
│   ├── server_foundation_e2e_tests       ← SF
│   ├── push_results_to_polarion          ← Polarion push job
│   ├── ci_setup_and_config               ← CI setup
│   └── ClusterLifecycle/
│       ├── clc_post_config
│       └── clc_bm_spoke_provisioning
│
├── qe-acm-automation-poc/                ← ciUtils.getQEJobsFolder()
│   ├── clc-e2e-pipeline                  ← CLC UI Cypress
│   ├── alc_e2e_tests                     ← ALC Console
│   ├── grc-e2e-test-execution            ← GRC
│   └── (obs, search, submariner, hdr*, volsync, dr4hub, install)
│
└── push_results_to_polarion              ← top-level (used by callPolarion)
```

## Shared Library Dependency

All Jenkinsfiles load `@Library('ci-shared-lib') _` which resolves to the
`ci/jenkinsfiles/vars/` directory in the `acmqe-autotest` repo, `main` branch.

Each `.groovy` file becomes a global variable:
- `ciUtils.getCIJobsFolder()` → `"CI-Jobs"`
- `clc.clcCreateUI(params, apiUrl, idpUser)` → triggers downstream CLC job
- `polarion.callPolarion(params, upstreamJob, buildNumber)` → Polarion push

## Artifact Flow (JUnit XML → Polarion)

```
Step 1: Test repo generates JUnit XML
  Cypress: mocha-junit-reporter → results/junit_cypress-[hash].xml
  Playwright: junit reporter → reports/junit-results.xml (when configured)

Step 2: Component Jenkinsfile archives artifacts
  archiveArtifacts artifacts: '**/reports/*'
  junit '**/reports/*.xml'

Step 3: Orchestrator copies artifacts from downstream build
  ciUtils.archArtifacts(jobName, buildNumber, "reports/*.xml", "results/<component>")
  → CopyArtifact plugin flattens XMLs into results/<component>/

Step 4: Orchestrator aggregates all components
  archiveArtifacts artifacts: 'results/**/*'
  junit 'results/**/*.xml'

Step 5: Polarion push
  polarion.callPolarion() → triggers push_results_to_polarion job
  → CopyArtifact from orchestrator build
  → Python traverses results/<component>/ directories
  → Extracts RHACM4K-XXXXX from test names
  → Maps component to Polarion squad
  → Creates/updates test run in Polarion
```

## Shared Library Files (vars/*.groovy -- 45 total)

Key files for common operations:
- `ciParams.groovy` -- central parameter definitions, `getSupportedTestComponents()`
- `ciUtils.groovy` -- job folders, artifact copy (`archArtifacts`), component metadata (`getComponentInfo`)
- `polarion.groovy` -- Polarion push job trigger
- `virt.groovy` -- Virt console E2E wrapper
- `clc.groovy` -- CLC UI/API create/destroy/cleanup
- `alc.groovy` -- ALC console/backend/canary wrappers
- `grc.groovy` -- GRC E2E wrapper

Each `.groovy` matches a stage name. Pattern: `<component>.call<Component>()` triggers a downstream job. List all with: `ls ci/jenkinsfiles/vars/*.groovy`

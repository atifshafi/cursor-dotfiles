# Pipeline Monitoring Profiles

Match job path to profile. Load matching profile for subagent configuration.

---

## virt_console_e2e_tests

- **Jenkins path:** `CI-Jobs/virt_console_e2e_tests`
- **Type:** E2E test
- **Expected duration:** 20 min (without CCLM), 120 min (with SPOKE_COUNT > 0)
- **Stages:** Validate Parameters, Checkout Test Code, Build, Setup Virt Environment, Test
- **Downstream:**
  - `CI-Jobs/virt_cclm_tests` (when SPOKE_COUNT > 0)
  - `CI-Jobs/ClusterLifecycle/clc_bm_spoke_provisioning` (BM spokes)
  - `CI-Jobs/ClusterLifecycle/clc_post_config` (post-build)
- **Cluster watch:**
  ```
  oc get mcra -A -o wide
  oc get placements -A -o wide
  oc get vm -A -o wide
  oc get pods -n open-cluster-management -o wide | grep -E 'console|clusterlifecycle'
  oc get managedclusters -o wide
  ```
- **Failure patterns:** AssignmentsFailure, CrashLoopBackOff, ProvisionStopped
- **Polling:** 120 seconds
- **Key params:** CUSTOMER_TAGS, FG_RBAC_ONLY, SPOKE_COUNT, CLC_UI_BRANCH, CYPRESS_HUB_API_URL

---

## virt_cclm_tests

- **Jenkins path:** `CI-Jobs/virt_cclm_tests`
- **Type:** Environment setup (CCLM)
- **Expected duration:** 60 min
- **Stages:** Checkout and Clean, Phase 0: Validate and Prepare, Phase 1: Provision Spokes, Phase 1b: Recover Spoke Kubeconfigs, Phase 0b: CIDR Validation, Phase 2: Configure CCLM Environment, Phase 2: Configure FG-RBAC Only
- **Downstream:**
  - `qe-acm-automation-poc/clc-e2e-pipeline` (Azure creds fallback)
- **Cluster watch:**
  ```
  oc get clusterdeployments -A -o wide
  oc get managedclusters -o wide
  oc get csv -A | grep -iE 'cnv|hco|kubevirt|submariner'
  oc get mcra -A -o wide
  oc get secrets -n open-cluster-management | grep -iE 'azure|pull-secret'
  oc get mch -A -o wide
  ```
- **Failure patterns:** ProvisionStopped, InstallFailed, CrashLoopBackOff, AssignmentsFailure
- **Polling:** 180 seconds
- **Key params:** HUB_API_URL, SPOKE_NAMES, FG_RBAC_ONLY, SKIP_PROVISION, AZURE_REGION

---

## ocp_deploy_and_acm_install

- **Jenkins path:** `CI-Jobs/ocp_deploy_and_acm_install`
- **Type:** Deploy + install
- **Expected duration:** 75 min
- **Stages:** Clean up workspace, Deploying OCP, OCP Artifacts, Retrieve HUB Details, Run Operators Pre-config job, ACM Deployment
- **Downstream:**
  - `CI-Jobs/ocp_common_deployment` (OCP deploy)
  - `config/config-job` (operators pre-config)
  - `acm/acm-install` (ACM install)
- **Cluster watch:**
  ```
  oc get clusterdeployments -A -o wide
  oc get nodes -o wide
  oc get mch -A -o wide
  oc get csv -A | grep -iE 'acm|mce'
  oc get pods -n open-cluster-management --no-headers | head -20
  oc get catalogsources -n openshift-marketplace
  ```
- **Failure patterns:** ProvisionStopped, InstallFailed, Degraded, CrashLoopBackOff
- **Polling:** 300 seconds
- **Key params:** CLOUD_PROVIDER, OCP_CLUSTER_NAME, OCP_VERSION, RHACM_SNAPSHOT_TAG, ACM_CHANNEL
- **Credential source:** Download kubeconfig from `ocp_credentials/` artifact after "Deploying OCP" stage completes

---

## ocp_common_deployment

- **Jenkins path:** `CI-Jobs/ocp_common_deployment`
- **Type:** OCP deploy router
- **Expected duration:** 50 min
- **Stages:** Set Cloud Provider Parameters, Destroy Existing OCP Cluster, Deploying OCP
- **Downstream:** Routes based on CLOUD_PROVIDER:
  - AWS/Azure/GCP/VMware -> `CI-Jobs/pics_cloud_deploy`
  - ROSA -> `openshift/deploy/cloud/rosa-deployment`
  - OSD -> `openshift/deploy/cloud/osd-deployment`
  - ARO -> `openshift/deploy/cloud/aro-deployment`
  - BAREMETAL -> `openshift/deploy/metal/ocp-bm-ipi-deployment`
  - VMware (pre-destroy) -> `CI-Jobs/pics_cloud_destroy`
- **Cluster watch:** Same as `pics_cloud_deploy` (actual work done in downstream)
- **Failure patterns:** ProvisionStopped, InstallFailed
- **Polling:** 300 seconds
- **Key params:** CLOUD_PROVIDER, OCP_CLUSTER_NAME, OCP_VERSION, REGION

---

## pics_cloud_deploy

- **Jenkins path:** `CI-Jobs/pics_cloud_deploy`
- **Type:** OCP IPI install
- **Expected duration:** 40 min
- **Stages:** Clone the CI repo, Validate Parameters, Setup Environment, Download OpenShift Installer, Platform Specific Setup, Generate Install Config, Install, Post Installation
- **Downstream:** None (leaf job)
- **Cluster watch:**
  ```
  oc get nodes -o wide
  oc get clusterversion
  oc get co
  ```
- **Failure patterns:** ProvisionStopped, InstallFailed, NotReady
- **Polling:** 180 seconds
- **Key params:** PLATFORM, OCP_CLUSTER_NAME, OCP_RELEASE, REGION, OCP_WORKER_INSTANCE_TYPE
- **Credential source:** Artifacts: `ci/output.json`, kubeconfig in workspace

Note: Cluster tracking only possible after the "Install" stage completes and kubeconfig is available. Before that, only Jenkins tracking works.

---

## pics_cloud_destroy

- **Jenkins path:** `CI-Jobs/pics_cloud_destroy`
- **Type:** Cluster teardown
- **Expected duration:** 10 min
- **Stages:** Clone the CI repo, Download OpenShift Installer, Platform Specific Setup, Destroy clusters
- **Downstream:** None
- **Cluster watch:** None (infrastructure-level destruction, no cluster to monitor)
- **Failure patterns:** None typical (cloud API errors appear in logs only)
- **Polling:** 60 seconds
- **Key params:** PLATFORM, OCP_CLUSTER_NAME, REGION

---

## acm-install

- **Jenkins path:** `acm/acm-install`
- **Type:** ACM operator install
- **Expected duration:** 15 min
- **Stages:** Setup, Clone the ACM repo, Uninstall ACM, Install ACM, Check Control Plane Topology
- **Downstream:**
  - `acm/acm-uninstall` (when UNINSTALL=true)
- **Cluster watch:**
  ```
  oc get catalogsources -n openshift-marketplace
  oc get subscriptions -A | grep -iE 'acm|mce'
  oc get csv -A | grep -iE 'acm|mce'
  oc get mch -A -o wide
  oc get mce -A -o wide
  oc get pods -n open-cluster-management --no-headers | wc -l
  oc get pods -n open-cluster-management -o wide | grep -v Running | grep -v Completed
  ```
- **Failure patterns:** Degraded, InstallFailed, CrashLoopBackOff, ImagePullBackOff
- **Polling:** 120 seconds
- **Key params:** OCP_CLUSTER_URL, ACM_DS_TAG, ACM_CHANNEL, MCE_DS_TAG, ENABLE_FINE_GRAINED_RBAC, ENABLE_CNV_MTV

---

## e2e_ui_test_pipeline

- **Jenkins path:** `CI-Jobs/e2e_ui_test_pipeline`
- **Type:** Orchestrator (master E2E)
- **Expected duration:** 240 min
- **Stages:** Clean up workspace, Start Notification via Slack, Run Operators Pre-config job, Run CI Setup job, Run CLC Creation/Validate Tests, CAPA + CAPZ, Get Managed Cluster Data, Run Hypershift Creation/Validate Tests, Server Foundation e2e, DISCOVERY CLI, Virt Console + GRC + ALC + Observability + Search + Regional Hub (parallel block), Submariner + DR tests, HoH Global Hub Test, Install e2e + Site-Config + Right-Sizing, ACM Must Gather, Run CLC deletion tests, Aggregate Report, Generate Tests Results Summary, Publish Results to Report Portal, Publish Results to Polarion, Finish Notification via Slack, Create and Schedule the Teardown Job
- **Downstream:** Many component jobs:
  - `qe-acm-automation-poc/clc-e2e-pipeline` (CLC)
  - `CI-Jobs/virt_console_e2e_tests` (Virt)
  - `CI-Jobs/grc-tests-pipeline` (GRC)
  - `CI-Jobs/observability_tests` (Observability)
  - `CI-Jobs/search_tests` (Search)
  - `push_results_to_polarion` (reporting)
  - `CI-Jobs/clc_cleanup` (teardown)
  - And others based on TEST_STAGES
- **Cluster watch:** Varies by active component. Use a broad set:
  ```
  oc get managedclusters -o wide
  oc get clusterdeployments -A -o wide
  oc get mch -A -o wide
  oc get pods -n open-cluster-management --no-headers | grep -v Running | grep -v Completed
  oc get mcra -A -o wide
  ```
- **Failure patterns:** CrashLoopBackOff, ProvisionStopped, Degraded, AssignmentsFailure
- **Polling:** 300 seconds
- **Key params:** TEST_STAGES, OCP_HUB_CLUSTER_URL, RHACM_SNAPSHOT_TAG, POLARION_TEST_PLAN_ID

---

## clc-e2e-pipeline

- **Jenkins path:** `qe-acm-automation-poc/clc-e2e-pipeline`
- **Source repo:** `stolostron/clc-ui-e2e` (not acmqe-autotest)
- **Type:** CLC Cypress E2E
- **Expected duration:** 45 min
- **Stages:** Build: Ensure required variables, Build (npm ci), Prepare Import Clusters, Test, Destroy Import Clusters
- **Downstream:**
  - `CI-Jobs/ClusterLifecycle/clc_bm_spoke_provisioning`
  - `create-clc-ks-clusters`
  - `destroy-clc-ks-clusters`
  - `CI-Jobs/ClusterLifecycle/clc_post_config`
- **Cluster watch:**
  ```
  oc get clusterdeployments -A -o wide
  oc get clusterpools -A -o wide
  oc get managedclusters -o wide
  oc get clusterimagesets --no-headers | tail -5
  ```
- **Failure patterns:** ProvisionStopped, HibernatingFailed, ClaimExpired
- **Polling:** 120 seconds
- **Key params:** TEST_STAGE, CUSTOMER_TAGS, CLOUD_PROVIDERS, CYPRESS_HUB_API_URL

---

## push_results_to_polarion

- **Jenkins path:** `push_results_to_polarion`
- **Type:** Reporting (no cluster impact)
- **Expected duration:** 5 min
- **Stages:** Results Artifact Archive, Build, Publish
- **Downstream:** None
- **Cluster watch:** None
- **Failure patterns:** None typical (Polarion API errors in logs only)
- **Polling:** 60 seconds
- **Key params:** UPSTREAM_JOB, COMPONENT, POLARION_TEST_PLAN_ID

---

## GENERIC (unknown pipelines)

Use this profile when the job path does not match any profile above.

- **Type:** Unknown
- **Expected duration:** 30 min (default; adjust if user provides estimate)
- **Stages:** Unknown -- discover dynamically:
  1. Call `get_pipeline_stages` on first poll to discover stage names
  2. If the job is not a Pipeline type (freestyle), fall back to log-only tracking
- **Downstream:** Unknown -- scan build log for `Starting building:` patterns to detect triggers
- **Cluster watch:** None unless user explicitly requests cluster tracking
- **Failure patterns:** FAILED, ABORTED, OutOfMemoryError, exit code 137
- **Polling:** 120 seconds
- **Key params:** Report all non-credential parameters from `get_build`

Discover stages dynamically via `get_pipeline_stages`. Scan log for `Starting building:` to detect downstream triggers.

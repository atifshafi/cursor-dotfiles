<!-- Last verified: 2026-08-10 against acmqe-autotest + live Jenkins -->
<!-- Verify paths and counts against the live repo before acting on specifics -->

# Cluster Provisioning & Destruction

5 primary pipelines for cluster lifecycle. Focus on the ones Atif uses regularly.

## Decision Tree

| Need | Use |
|------|-----|
| New OCP + ACM cluster from scratch | `CI-Jobs/ocp_deploy_and_acm_install` |
| Bare OCP without ACM | `CI-Jobs/pics_cloud_deploy` |
| Refresh/reinstall ACM on existing cluster | `acm/acm-install` |
| ROSA managed cluster | `openshift/deploy/cloud/rosa-deployment` |
| Destroy any self-managed cluster | `CI-Jobs/pics_cloud_destroy` |
| Destroy ROSA | `openshift/destroy/cloud/rosa-destroy` |

---

## 1. ocp_deploy_and_acm_install (Primary Provisioner)

**Jenkins:** `CI-Jobs/ocp_deploy_and_acm_install`
**Jenkinsfile:** `ci/jenkinsfiles/ocp_deployment_acm_install/common/Jenkinsfile`
**What it does:** Deploys OCP via sub-job, then installs ACM via sub-job.

### Key Parameters

| Parameter | Default | Purpose |
|-----------|---------|---------|
| CLOUD_PROVIDER | (required) | AWS, AZURE, GCP, VMWARE-*, ROSA-*, ARO, OSD, BAREMETAL |
| OCP_CLUSTER_NAME | (required) | Cluster name (max 20 chars) |
| OCP_VERSION | (required) | Z-stream version (e.g. 4.18.6) |
| RHACM_SNAPSHOT_TAG | (required) | ACM snapshot (e.g. `2.17.0-DOWNSTREAM-2026-08-01-12-00-00` or `latest-2.17`) |
| ACM_CHANNEL | (derived) | Release channel |
| ACM_REPOSITORY | konflux | `konflux`, `acm-d`, `brew`, `production` |
| ACM_NAMESPACE | ocm | Namespace for ACM install |
| MCE_SNAPSHOT_TAG | (required) | MCE snapshot |
| FIPS_ENABLED | false | Enable FIPS |
| SKIP_ACM_INSTALL | false | Deploy OCP only |
| CI_GIT_BRANCH | main | acmqe-autotest branch |

### Stages
1. Clean workspace
2. Deploy OCP (calls `ocp_common_deployment` sub-job)
3. Archive OCP artifacts (kubeconfig)
4. Retrieve hub details (API URL, credentials)
5. Run operators pre-config
6. ACM install (calls `acm/acm-install` sub-job)

### Artifacts
- `ocp_credentials/kubeconfig` -- hub kubeconfig
- `ocp_credentials/output.json` -- cluster metadata (API URL, console URL, credentials)

---

## 2. pics_cloud_deploy (Bare OCP Deployer)

**Jenkins:** `CI-Jobs/pics_cloud_deploy`
**Jenkinsfile:** `ci/jenkinsfiles/ocp/self-managed-ocp/Jenkinsfile_pics_deploy`
**What it does:** Deploys bare OCP via openshift-install (no ACM).

### Key Parameters

| Parameter | Default | Purpose |
|-----------|---------|---------|
| PLATFORM | (required) | `aws`, `aws-arm`, `aws-bm`, `azure`, `gcp`, `vsphere` |
| OCP_CLUSTER_NAME | (required) | Cluster name (max 20 chars) |
| OCP_RELEASE | stable | Channel: `stable`, `stable-4.18`, `candidate` |
| OCP_RELEASE_IMAGE_TAG | (empty) | Specific z-stream tag |
| REGION | (platform default) | Cloud region |
| OCP_WORKER_INSTANCE_TYPE | (platform default) | Worker VM type |
| SNO | false | Single Node OpenShift |
| FIPS_MODE | false | FIPS enabled |
| SPOT_VM | false | Use spot/preemptible instances |

### When to Use
- Need bare OCP without ACM (e.g. for MCE-only testing)
- Need specific platform control (SNO, spot instances, custom regions)

---

## 3. pics_cloud_destroy (Cluster Destroyer)

**Jenkins:** `CI-Jobs/pics_cloud_destroy`
**Jenkinsfile:** `ci/jenkinsfiles/ocp/self-managed-ocp/Jenkinsfile_pics_destroy`
**What it does:** Destroys self-managed OCP clusters via openshift-install.

### Key Parameters

| Parameter | Default | Purpose |
|-----------|---------|---------|
| PLATFORM | (required) | `aws`, `azure`, `gcp`, `vsphere`, `eks`, `aks`, `gke` |
| OCP_CLUSTER_NAME | (required) | **InfraID** of the cluster (comma-separated for multiple) |
| REGION | (platform default) | Cloud region |

### How to Find InfraID
From the deploy job's archived `ocp_credentials/output.json`, or from `oc get infrastructure cluster -o jsonpath='{.status.infrastructureName}'`.

---

## 4. acm-install (Standalone ACM Install)

**Jenkins:** `acm/acm-install`
**Jenkinsfile:** `ci/jenkinsfiles/acm/acm_install/Jenkinsfile`
**What it does:** Installs or refreshes ACM on an existing OCP cluster.

### Key Parameters

| Parameter | Default | Purpose |
|-----------|---------|---------|
| OCP_CLUSTER_URL | (required) | API URL of existing cluster |
| OCP_USER | kubeadmin | Cluster admin user |
| OCP_PASSWORD | (required) | Cluster admin password |
| ACM_DS_TAG | (required) | Downstream build tag |
| ACM_CHANNEL | (derived) | Release channel |
| ACM_REPOSITORY | konflux | `konflux`, `brew`, `production` |
| ACM_NAMESPACE | ocm | Install namespace |
| ENABLE_FINE_GRAINED_RBAC | true | Enable FG-RBAC component |
| ENABLE_CNV_MTV | true | Enable CNV/MTV components |
| ENABLE_BACKUP_COMPONENT | false | Enable cluster backup |
| UNINSTALL | false | Uninstall existing ACM first |

### When to Use
- Refresh ACM to a newer build on an existing cluster
- Install ACM on a cluster provisioned by `pics_cloud_deploy`
- Change MCH component configuration (FG-RBAC, CNV, backup)

---

## 5. ROSA Deploy / Destroy

### Deploy
**Jenkins:** `openshift/deploy/cloud/rosa-deployment`
**Jenkinsfile:** `ci/jenkinsfiles/ocp/managed-ocp/rosa/deploy/Jenkinsfile`

| Parameter | Default | Purpose |
|-----------|---------|---------|
| OCP_CLUSTER_NAME | (required) | Max 15 chars |
| OCP_VERSION | (required) | OCP version |
| AWS_REGION | us-east-1 | AWS region |
| OCP_WORKER_INSTANCE_TYPE | m5.xlarge | Worker type |
| CONTROL_PLANE_TYPE | classic | `classic` or `hosted` (HCP) |

### Destroy
**Jenkins:** `openshift/destroy/cloud/rosa-destroy`

| Parameter | Default | Purpose |
|-----------|---------|---------|
| CLUSTER_NAME | (required) | Cluster name |
| AWS_REGION | us-east-1 | AWS region |

---

## Provision -> Test -> Destroy Flow

```
PROVISION: ocp_deploy_and_acm_install
    ├── ocp_common_deployment (sub-job: bare OCP)
    └── acm/acm-install (sub-job: ACM on top)
         ↓
TEST: e2e_ui_test_pipeline or console Playwright pipelines
         ↓
DESTROY: pics_cloud_destroy (InfraID from deploy artifacts)
```

For ROSA: `rosa-deployment` -> test -> `rosa-destroy` (by cluster name).

## Slack Notifications

Deploy and destroy pipelines post to `#team-acm-qe-auto-notify` with cluster details. Deploy notifications include a `[destroy_this_cluster]` link that pre-populates the destroy job parameters.

## Cleanup

- `CI-Jobs/create_e2e_destroy_job`: Scheduled delayed destruction (`DELETION_TIMEFRAME_IN_HOURS`, default 24)
- Weekly cron: `ci/jenkinsfiles/ocp/scheduled-cleanup/cleanup-clusters/Jenkinsfile`

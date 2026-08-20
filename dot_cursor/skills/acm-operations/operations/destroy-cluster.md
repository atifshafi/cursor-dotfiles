# Operation 4: Destroy OCP Cloud Cluster

**Permission Required:** This is DESTRUCTIVE. Always confirm with the user before triggering.

---

## Pipeline Details

| Property | Value |
|----------|-------|
| **Job path** | `CI-Jobs/pics_cloud_destroy` |
| **URL** | https://jenkins-csb-rhacm-tests.dno.corp.redhat.com/job/CI-Jobs/job/pics_cloud_destroy/ |
| **Source** | `stolostron/acmqe-autotest`, main branch |
| **Backend** | `openshift-install destroy cluster` (runs in K8s pod) |

## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `PLATFORM` | Choice | `aws`, `azure`, `gcp`, `vsphere`, `eks`, `aks`, `gke` |
| `OCP_CLUSTER_NAME` | String | **InfraID** (NOT cluster name). Comma-separated for multiple. Example: `ashafi-aws-test-zzh78` |
| `REGION` | String | Cloud region. Leave blank for defaults (AWS=us-east-1, Azure=eastus, GCP=us-east1). Must specify for non-default regions. |
| `CI_GIT_BRANCH` | String | Default: `main` |

## How to Trigger

```
trigger_build(
  job_path="CI-Jobs/pics_cloud_destroy",
  parameters={
    "PLATFORM": "<aws|azure|gcp|...>",
    "OCP_CLUSTER_NAME": "<infraID>",
    "REGION": "<region-if-non-default>",
    "CI_GIT_BRANCH": "main"
  }
)
```

## InfraID vs Cluster Name

`OCP_CLUSTER_NAME` expects the **InfraID** (cluster name + random suffix from `openshift-install`):
- Cluster name: `ashafi-aws-test` -> InfraID: `ashafi-aws-test-zzh78`
- User typically provides the InfraID directly (appears in cloud resource tags)

## Duration

Typically 1-6 minutes depending on platform and remaining resources.

## Related Pipelines

| Pipeline | Purpose |
|----------|---------|
| `CI-Jobs/pics_cloud_deploy` | Deploy OCP clusters (create counterpart) |
| `openshift/destroy/cloud/rosa-destroy` | Destroy ROSA clusters |
| `openshift/destroy/cloud/aro-destroy` | Destroy ARO clusters |
| `openshift/destroy/cloud/osd-destroy` | Destroy OSD clusters |

# Mode 3: Destroy (gated)

## Resolve target

Accept: API URL, cluster display name, or `job/path #build`.

1. Search `inventory.json` / in-memory candidates for match (cluster name substring, URL in `artifact` or known console host).
2. If missing InfraID: download `output.json` from the matching build and parse defensively (see [references/output-json.md](../references/output-json.md); keys such as `infraId`, `infraID`, nested `status`, etc.).
3. If still unknown: ask user for **InfraID** and **PLATFORM** for `pics_cloud_destroy`.

## Map to destroy job

Default: `CI-Jobs/pics_cloud_destroy` with `PLATFORM` (lowercase aws/azure/gcp/vsphere/eks/aks/gke), `OCP_CLUSTER_NAME` = InfraID, `REGION` from source build.

For ROSA / ARO / OSD use destroy jobs under `openshift/destroy/cloud/` per [references/provisioning-pipelines.md](../references/provisioning-pipelines.md).

## Trigger

Show infra id, platform, region, and job URL; require explicit approval; then `trigger_build`.

**Deliver in compact format:**

| Field | Value |
|-------|-------|
| Job | destroy job URL |
| InfraID | resolved value |
| Platform | provider |
| Status | queued / completed |

Note: inventory cache may be stale until next refresh after destroy completes.

# Mode 2: Provision (gated)

Default job: `CI-Jobs/ocp_deploy_and_acm_install`

## Parameter mapping (plain language to Jenkins)

| User intent | Parameters |
|-------------|--------------|
| ACM 2.17 nightly | `RHACM_SNAPSHOT_TAG=latest-2.17`, `ACM_CHANNEL=2.17` (if channel needed) |
| Azure | `CLOUD_PROVIDER=AZURE` |
| OCP 4.18 | `OCP_VERSION=4.18.x` (exact z-stream if user gave it), `OCP_RELEASE=stable-4.18` or user value |
| Defaults | Leave unset fields empty only when Jenkins default is acceptable; document chosen defaults in the approval summary |

## ACM_REPOSITORY default

**Always use `konflux`** (team standard as of May 2026). Do not use `production` or `acm-d` unless the user explicitly requests it. This applies to all ACM versions including older z-streams (2.15, 2.16).

## Cluster naming convention

**NEVER use the `ci-` prefix** in `OCP_CLUSTER_NAME`. The `ci-` prefix is reserved for the automated CI process. Use descriptive names like `atif-215-hub`, `atif-az-50`, `test-217-virt`, etc. Pattern: `<user>-<version/purpose>-<optional-qualifier>`.

## MCE snapshot tag mapping

| ACM version | MCE snapshot |
|-------------|-------------|
| latest-2.15 | latest-2.10 |
| latest-2.16 | latest-2.11 |
| latest-2.17 | latest-2.17 |
| latest-5.0 | latest-5.0 |

Use Jenkins MCP `get_job` to list current parameter definitions before trigger. For full parameter reference see [references/pipeline-parameters.md](../references/pipeline-parameters.md).

## Fix verification timing (upstream vs downstream lag)

The `latest-X.Y` snapshot tag resolves to the downstream Konflux catalog (`acm-dev-catalog:latest-X.Y`), NOT the upstream `stolostron/pipeline` quay-retag. The downstream catalog takes **12-24 hours** after a PR merge to include the fix.

**Rule:** Wait 24 hours after PR merge before provisioning for fix verification. If the user needs it sooner, warn them the fix may not be present and recommend checking the running image's build date after install.

See `~/.cursor/skills/acm-operations/SKILL.md` Op 3 for details.

## Trigger

1. Dry-run preview via CLI when available: `jenkins-run trigger URL --dry-run` (see `~/.cursor/skills/jenkins-expert/SKILL.md`).
2. Show user **all** parameters.
3. On explicit **yes**: `trigger_build(job_path="CI-Jobs/ocp_deploy_and_acm_install", parameters={...})`.
4. Monitor: `jenkins-run monitor BUILD_URL` (MCP `get_build_status` is single-shot). Otherwise poll Jenkins `.../api/json` for `building` / `result`.

## After success

Download `ocp_credentials/kubeconfig` and `output.json`, then `export KUBECONFIG`, run **`scripts/hub_validation_gate.py`** (exit 0 required), then run hub checks **only** per **`~/.cursor/skills/acm-hub-health-check/SKILL.md`** (Quick).

**Deliver in compact format:**

| Field | Value |
|-------|-------|
| Build | Jenkins URL |
| Status | SUCCESS / result |
| Kubeconfig | path |
| Console | URL |
| Health | Quick check summary |

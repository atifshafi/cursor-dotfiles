# Mode 1: Find

## Step A -- Parse user criteria

Capture when provided: ACM version or snapshot (`2.15.2`, `latest-2.17`, DOWNSTREAM tag), OCP version, `CLOUD_PROVIDER` / platform, need for **spokes** (filter `ManagedCluster` count later), **freshness** (prefer newer `build_timestamp` / Running sheet rows).

## Step B -- Sheet first (optional)

Spreadsheet ID: `1yg75xNpeO1i_K39D43FZmMauQe2d2OuJ1UjunX7jz3A`

If google-workspace MCP is available, call `read_sheet_values` (`user_google_email` = `ashafi@redhat.com`). Prefer rows with Status **Running** that match version/platform. Treat sheet as **hint** only. If no Sheet access, **skip** and rely on cache + Jenkins. See [references/google-sheet.md](../references/google-sheet.md) for column layout.

## Step C -- Local cache

Read `~/.acm-env-inventory/inventory.json` (see Inventory cache in main SKILL.md). If the file is missing or `entries` is absent/empty, run `refresh-inventory.py` per that section, then re-read the file.

**Note:** `refresh-inventory.py` uses stdlib + Jenkins REST directly; it works even when Jenkins MCP is unavailable.

Filter `entries` where `build_result == "SUCCESS"` (and `skip_acm_install` is false unless user wants OCP-only). Sort by `build_timestamp` descending.

## Step D -- Jenkins live (fill gaps)

Use Jenkins MCP `get_job` / `get_build` on provisioning jobs listed in [references/provisioning-pipelines.md](../references/provisioning-pipelines.md). Merge with cache; prefer artifacts present (`has_kubeconfig_artifact`).

## Step E -- Rank candidates

1. Successful install with matching **RHACM_SNAPSHOT_TAG** / **ACM_CHANNEL** / user version substring.
2. Matching **CLOUD_PROVIDER** / region.
3. Newer timestamp.
4. **No newer overwrite:** For each candidate, scan builds *after* it on the same `OCP_CLUSTER_NAME`. If a later build targets the same cluster with a different snapshot, the candidate is stale -- discard it.

## Step E.5 -- Reachability gate (mandatory, before Step F)

**NEVER present a candidate without verifying it is alive first.** The sheet is frequently stale (clusters destroyed but still listed as "Running"). For every candidate that passes Step E ranking:

```bash
curl -sk --max-time 10 -o /dev/null -w "%{http_code}" "https://console-openshift-console.apps.<cluster>.<domain>"
```

- **HTTP 200**: Proceed to Step F (full health check).
- **Any other result** (000, ERR_NAME_NOT_RESOLVED, timeout): Discard. Mark as dead in working notes and move to next candidate.

## Step F -- Health check (mandatory before recommending)

1. Build artifact URL: `{jenkins_build_url}artifact/ocp_credentials/kubeconfig`
2. `curl -sSk -u "$JENKINS_USER:$JENKINS_TOKEN" -o "$UNIQUE_KUBECONFIG" "$URL"` (credentials from `~/.jenkins/config.json`)
3. `export KUBECONFIG=$UNIQUE_KUBECONFIG` and verify `oc whoami --show-server`
4. **Preflight gate (required):** run `scripts/hub_validation_gate.py`. **Require exit code 0.** Parse the JSON on stdout: use `hub_skill_abspath` for the next step; on failure use `exit_reason` / `hint` and retry or pick another candidate. See [references/hub-validation-gate.md](../references/hub-validation-gate.md).

   ```bash
   python3 ~/.cursor/skills/acm-environment-finder/scripts/hub_validation_gate.py
   ```
5. **Hub validation:** read and execute **`~/.cursor/skills/acm-hub-health-check/SKILL.md`** at **Quick** depth (user may request Standard/Deep from that skill). Do not skip this file in favor of improvised checks.
6. If user asked for **spokes**, after hub Quick check run `oc get managedclusters --no-headers | wc -l` (or `acm-kubectl` `clusters` tool) and compare to expectation.
7. **Optional fleet health supplement:** If the recommended cluster matches the `acm-search` MCP's connected hub (`~/Documents/work/notes/notes.md` line 2), run `find_resources(outputMode="health")` to enrich the health report with fleet-wide resource status. This is informational only -- it does not gate the recommendation.
8. On failure: set `health_status` to `FAILED` in notes; try next candidate; delete temp kubeconfig.

## Step G -- Deliver

Present results in compact table format:

| Field | Value |
|-------|-------|
| Cluster | name |
| Platform | provider |
| Snapshot | tag/channel |
| Jenkins build | URL |
| Kubeconfig | path or download command |
| Console | URL hint from sheet (if available) |
| Spokes | count vs expected (if requested) |
| Health | Quick check summary |

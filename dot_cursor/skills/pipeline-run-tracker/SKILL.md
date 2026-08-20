---
name: pipeline-run-tracker
description: >-
  Spawn parallel monitoring agents to track Jenkins pipeline runs and their
  cluster-side effects in real time. Works for any pipeline: deploy, install,
  test, destroy, upgrade. Use when user says "track it", "monitor progress",
  "keep an eye on the pipeline", "spawn agents to watch", or triggers a build
  and wants status updates. Do NOT use for triggering builds (use jenkins-expert)
  or investigating past failures (use jenkins-expert).
---

# Pipeline Run Tracker

## Ask Questions First

Before spawning trackers, gather inputs. If REQUIRED input is missing, ask before proceeding.

| Input | Required? | How to Get |
|---|---|---|
| Build URL or job path + build number | **Yes** | From user message, or from a `trigger_build` call earlier in conversation |
| Hub credentials (KUBECONFIG or URL + password) | No | Only if cluster tracking requested or pipeline modifies a cluster |
| Specific watch items | No | User may say "watch for MCRA failures" or "let me know when the spoke is ready" |

**Auto-detect:** If user just triggered a build and says "track it" / "monitor it", extract the build URL from the preceding tool call output. Do not re-ask.

---

## Step 1: Identify the Pipeline

Extract job path from build URL: strip Jenkins base URL and `/job/` segments (e.g., `.../job/CI-Jobs/job/virt_console_e2e_tests/155/` -> `CI-Jobs/virt_console_e2e_tests`).

Look up in [references/pipeline-profiles.md](references/pipeline-profiles.md). Match found: load profile. No match: use GENERIC profile (polls every 2 min, discovers stages via `get_pipeline_stages`).

---

## Step 2: Credential Discovery (for Cluster Tracking)

Only needed when profile specifies cluster resources to watch or user requests cluster monitoring.

**Read** `kubeconfig-isolation.mdc` and create a session-specific KUBECONFIG before any `oc` commands.

Check sources in order -- stop at first success:

| Priority | Source | Method |
|---|---|---|
| 1 | Active `oc` session | Reuse KUBECONFIG from earlier successful `oc whoami --show-server` |
| 2 | Build parameters | `get_build` -> extract `HUB_API_URL`/`OCP_CLUSTER_URL` + password |
| 3 | Build artifacts | Deploy pipelines: download kubeconfig from `ocp_credentials/` artifact |
| 4 | Ask the user | "Can you provide a KUBECONFIG path or hub URL + password?" |

**Never expose credentials in chat.** If no credentials available, skip cluster tracking entirely.

---

## Step 3: Tracking Scope

| Pipeline Type | Jenkins Tracker | Cluster Tracker |
|---|---|---|
| E2E test (Cypress/Playwright) | Yes | Yes -- MCRAs, VMs, ClusterDeployments |
| OCP deploy | Yes | Yes -- ClusterDeployments, nodes |
| ACM/MCE install | Yes | Yes -- operator pods, MCH, CSVs |
| Cluster destroy | Yes | Optional -- verify resources removed |
| Reporting (Polarion push) | Yes | No |
| Unknown pipeline | Yes (generic) | Only if user explicitly requests |

---

## Step 4: Spawn Subagents

Read [references/subagent-templates.md](references/subagent-templates.md). Fill placeholders from the pipeline profile (placeholder names match profile field names).

- **Jenkins Tracker (always):** `generalPurpose`, `run_in_background: true`
- **Cluster Tracker (if credentials available):** `shell`, `run_in_background: true`

---

## Step 5: Status Requests

When user asks "status?" while agents are running: check both subagent outputs, synthesize into a single update (current stage + elapsed time, downstream jobs, cluster state, issues). Report final summary when a subagent completes.

---

## Error Handling

Error patterns are defined in each subagent template. On error: report immediately, continue tracking.
- **Jenkins-side failures** (build errors, stage failures, downstream failures) -> suggest `jenkins-expert` for root-cause analysis.
- **Cluster-side failures** (pod crashes, provisioning failures, RBAC errors, operator issues) -> suggest `acm-live-investigator` for diagnosis.

---

## ACM Search (`acm-search`) -- Optional Fleet Context

**Cluster-match guard:** acm-search connects to cluster in `~/Documents/work/notes/notes.md` line 2. Verify tracked hub matches before using. If hubs differ, skip entirely.
**Use for:** fleet snapshot (`find_resources(outputMode="health")`) and failure diagnostics (`find_resources(kind="Pod", status="CrashLoopBackOff,Error", groupBy="cluster")`).
**Do NOT use** in polling loop -- `oc get` is real-time; search has 15-45s lag.
**Empty results:** 0 + match = doesn't exist. 0 + expected = possible staleness (verify with `oc get`).

---

## Sibling Delegation

This skill tracks progress. It does NOT investigate, diagnose, provision, or trigger:
- Root-cause analysis -> `jenkins-expert`
- Live cluster diagnosis -> `acm-live-investigator`
- Hub health checks -> `acm-hub-health-check`
- Environment finding/provisioning -> `acm-environment-finder`
- Triggering builds -> `jenkins-expert` (unless auto-chain authorized)

---

## Auto-Chain (Optional)

If user requests "when this succeeds, trigger Y": wait for SUCCESS, show parameters, **GATE: wait for explicit user approval** before calling `trigger_build`.

## Utility

JUnit XML parsing: `bash ~/.cursor/skills/pipeline-run-tracker/scripts/parse-test-results.sh /path/to/results.xml`

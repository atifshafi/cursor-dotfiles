---
name: acm-environment-finder
description: >-
  Finds, provisions, or destroys ACM QE test environments by combining Google Sheet
  inventory, Jenkins provisioning job history (ocp_deploy_and_acm_install), local
  cache at ~/.acm-env-inventory, and hub health checks by delegating to the
  acm-hub-health-check skill at ~/.cursor/skills/acm-hub-health-check/SKILL.md
  (symlinked from the ai_systems clone per CURSOR-SYMLINK-INTEGRATION.md).
  Use when the user asks to find an environment, usable cluster, ACM hub for a version
  (e.g. 2.15.2, 2.17), Azure/AWS/GCP/VMware platform, spokes or freshness, refresh
  environment inventory, provision or create a new ACM/OCP environment, destroy or
  tear down a cluster by URL name or Jenkins build, or match CI sheet rows to live hubs.
compatibility: >-
  Requires VPN; Jenkins MCP and ~/.jenkins/config.json; google-workspace MCP for sheet
  (optional Jenkins-only); oc CLI; optional acm-kubectl MCP. Hub checks: install
  ~/.cursor/skills/acm-hub-health-check and ~/.cursor/knowledge per
  ai_systems/.claude/skills/CURSOR-SYMLINK-INTEGRATION.md so delegation paths resolve.
metadata:
  author: acm-qe
  version: "1.3.0"
---

# ACM Environment Finder

Orchestrates **find**, **provision**, and **destroy** flows for ACM QE environments.

**Secrets in chat:** Never paste `jenkins_token`, kubeconfig contents, or other credentials into the transcript. Use file paths on disk and redacted summaries only.

## Cursor integration

Hub skill and knowledge symlinks must point into the `ai_systems` clone. If `~/.cursor/skills/acm-hub-health-check` is missing, run `ai_systems/.claude/skills/CURSOR-SYMLINK-INTEGRATION.md`. For sibling skill delegation paths, read `references/skill-paths.md`.

## Prerequisites

| Need | Detail |
|------|--------|
| VPN | Jenkins and many clusters are internal |
| Jenkins MCP + `~/.jenkins/config.json` | Read builds; `trigger_build` only after approval |
| Google Workspace MCP | `read_sheet_values` for team sheet (optional -- skill works without it) |
| `oc` CLI | Kubeconfig download + login for health checks |
| Hub skill + knowledge | `~/.cursor/skills/acm-hub-health-check/SKILL.md` and `~/.cursor/knowledge/` must resolve |

## Progressive disclosure

Load only when the task needs that depth:

- **Skill delegation paths:** [references/skill-paths.md](references/skill-paths.md)
- **Jenkins without MCP (REST fallback):** [references/jenkins-without-mcp.md](references/jenkins-without-mcp.md)
- **Hub preflight gate:** [references/hub-validation-gate.md](references/hub-validation-gate.md)
- **Sheet parsing and column layout:** [references/google-sheet.md](references/google-sheet.md)
- **Jenkins parameters and artifacts:** [references/pipeline-parameters.md](references/pipeline-parameters.md)
- **Job choice (provision vs destroy vs ROSA/ARO):** [references/provisioning-pipelines.md](references/provisioning-pipelines.md)
- **Defensive parsing of `output.json`:** [references/output-json.md](references/output-json.md)

## Inventory cache

| Path | Role |
|------|------|
| `~/.acm-env-inventory/inventory.json` | Last successful refresh output (`entries` array) |
| `~/.acm-env-inventory/last-refresh.txt` | Unix epoch seconds of last refresh |

**First run or empty cache:** If `inventory.json` is missing, unreadable, or `entries` is empty/missing, run a refresh **before** Mode 1 Step C, then re-read the file.

**Lazy refresh:** If `last-refresh.txt` is older than **2 hours**, run:

```bash
python3 ~/.cursor/skills/acm-environment-finder/scripts/refresh-inventory.py
```

(or pass `--dry-run` to inspect without writing). Re-read `inventory.json` after refresh.

**Expected output (refresh script):** Exit code 0; stdout ends with JSON containing `entries` (build metadata, `has_kubeconfig_artifact`, etc.). On failure, stderr explains auth or network; fix Jenkins config or VPN before retrying.

## MANDATORY: Gate enforcement

| Action | Gate |
|--------|------|
| Read sheet, read Jenkins, read cache, download artifacts | No user approval |
| `trigger_build` (provision or destroy) | **Explicit user approval** after showing full job path + parameters |
| `oc` against a cluster | Use **session-specific kubeconfig** path per workspace rules; read-only for find |

Todo pattern for provision/destroy:

```
discover-candidates | pending
prepare-jenkins-params | pending
GATE: user-approval | pending
trigger-build | pending
monitor-or-handoff | pending
```

Do not mark `GATE: user-approval` completed without user confirmation.

**CRITICAL:** Never call `trigger_build` until the user has explicitly approved the exact job path and parameter map shown in the session.

---

## Mode Dispatch (read EXACTLY ONE mode file)

| User intent keywords | Mode file |
|---------------------|-----------|
| find, looking for, need, available, running cluster, usable hub, which environment | `modes/find.md` |
| provision, create, deploy, install, spin up, set up new | `modes/provision.md` |
| destroy, tear down, deprovision, delete cluster, clean up | `modes/destroy.md` |

**Disambiguation:** If user says "I need an environment" without explicit create/provision verbs, default to **Find** first. Only escalate to **Provision** if Find returns no viable candidates.

**Rule:** Read EXACTLY ONE mode file based on user intent. Do not defensively load multiple files.

---

## Jenkins fallback

If Jenkins MCP is unavailable during **any** mode, read `references/jenkins-without-mcp.md` for REST API usage. This rule applies to all modes -- mode files do not repeat it.

## Output efficiency

When presenting candidates (Find) or build results (Provision/Destroy), use the compact table format specified in each mode file's Deliver section. Do not narrate each step you took. Target: under 200 words for the final delivery.

## Troubleshooting

| Symptom | What to do |
|---------|------------|
| Jenkins MCP errors | Confirm VPN; verify `~/.jenkins/config.json`; test `get_all_jobs` |
| No candidates / empty `entries` | Run `refresh-inventory.py`; confirm success JSON on stdout |
| Gate script exits non-zero | Read JSON `exit_reason` on stdout; see `references/hub-validation-gate.md` |

## Engram (optional, Cursor-only)

- Recall: `engram_recall("known good ACM QE hub")`
- After notable failures: `engram_remember("...")` with cluster id and reason

## Negative triggers (prefer other skills)

Do **not** use this skill as primary for: Jenkins-only test failure triage (`~/.cursor/skills/jenkins-expert/SKILL.md`), build tag on current login without search (`~/.cursor/skills/acm-operations/SKILL.md`), or deep hub diagnosis **without** find/provision/destroy flow -- for hub-only diagnosis use **`~/.cursor/skills/acm-hub-health-check/SKILL.md`** alone.

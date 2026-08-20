# Jenkins Tools and Paths Reference

Read this file when you need to look up a specific tool's parameters, CLI command syntax, or file path.

---

## MCP Tools (jenkins MCP)

### Core (read-only)

| Tool | Key Args | Purpose |
|------|----------|---------|
| `get_all_jobs` | (none) | List root-level jobs |
| `get_job` | `job_path` | Job details by slash-separated path |
| `get_build` | `job_path`, `build_number?` | Build info (omit for last build) |
| `get_build_log` | `job_path`, `build_number?`, `start?`, `max_lines?` | Console output |
| `get_build_status` | `build_url` | Quick status from full URL |
| `get_pipeline_stages` | `job_path`, `build_number?` | Stage names, statuses, durations |

### Analysis (read-only)

| Tool | Key Args | Purpose |
|------|----------|---------|
| `analyze_pipeline` | `build_url`, `max_depth?`, `console_lines?` | Root cause analysis |
| `get_downstream_tree` | `build_url`, `max_depth?`, `output_format?` | Downstream job tree |
| `get_test_results` | `job_path`, `build_number?`, `mode?` | Test results (summary/full/failures) |
| `analyze_test_results` | `job_path`, `build_number?`, `failures_only?` | Component/squad breakdown |

### State-changing (REQUIRES PERMISSION)

| Tool | Key Args | Purpose |
|------|----------|---------|
| `trigger_build` | `job_path`, `parameters?` | Trigger a build |

### Job Path Format
Slash-separated, auto-converted: `"CI-Jobs/virt_console_e2e_tests"` -> Jenkins API format.
For `build_url` args, use full Jenkins URL.

---

## CLI Tools (Fallback)

| Command | MCP Equivalent |
|---------|----------------|
| `jenkins-run analyzer --url <URL>` | `analyze_pipeline` |
| `jenkins-run tree --url <URL>` | `get_downstream_tree` |
| `jenkins-run results <URL>` | `get_test_results` |
| `jenkins-run fetch-results --job <PATH>` | `get_test_results` |
| `jenkins-run monitor <URL>` | (no MCP equivalent) |
| `jenkins-run trigger <URL> --dry-run` | `trigger_build` (no dry-run in MCP) |
| `jenkins-run params <URL> --list-params` | (no MCP equivalent) |

Setup: `source ~/Documents/work/ai/tools/integrations/jenkins/jenkins-env.sh`

---

## Key File Locations

| Item | Path |
|------|------|
| CI/CD repo | `/Users/ashafi/Documents/work/automation/qe-automation-repos/acmqe-autotest/` |
| Shared library | `ci/jenkinsfiles/vars/*.groovy` |
| Orchestrator Jenkinsfile | `ci/jenkinsfiles/e2e/e2e-common/Jenkinsfile` |
| Virt Jenkinsfile | `ci/jenkinsfiles/components/virt/Jenkinsfile_virt_e2e` |
| Polarion push scripts | `ci/polarion/polarion_helpers.py`, `ci/polarion/push_results_to_polarion.py` |
| Agent pod configs | `ci/jenkinsfiles/agent_pod_config/ciAgentPod_*.yaml` |
| CLC test repo | `/Users/ashafi/Documents/work/automation/qe-automation-repos/clc-ui/` |
| Playwright test repo | `/Users/ashafi/Documents/work/automation/qe-automation-repos/console-e2e/` |
| Jenkins MCP server | `/Users/ashafi/Documents/work/ai/tools/mcp/jenkins-mcp/jenkins_mcp_server.py` |
| CLI scripts | `/Users/ashafi/Documents/work/ai/tools/jenkins-tools/` |
| Credentials | `~/.jenkins/config.json` |
| Jenkins URL | `https://jenkins-csb-rhacm-tests.dno.corp.redhat.com` |

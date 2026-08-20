---
name: jenkins-expert
description: >
  ACM Jenkins CI/CD expert skill. Covers the full pipeline architecture
  (e2e_ui_test_pipeline orchestrator, console-e2e Playwright pipelines,
  virt_console_e2e_tests, cluster provisioning/destruction), shared library
  (45 vars/*.groovy), Polarion result push, JUnit XML chain, and Jenkins admin
  operations. Uses the jenkins MCP server (11 tools) with CLI fallback.
  Trigger on: Jenkins, pipeline, build failed, downstream, CI/CD, Polarion push,
  test results, trigger job, monitor build, shared library, orchestrator,
  add component to CI, JUnit XML, test report, provision cluster, destroy cluster.
---

# Jenkins Expert -- ACM CI/CD Skill

## Purpose

Make any AI agent an expert on the ACM Jenkins CI/CD ecosystem. Handles pipeline
analysis, triggering, monitoring, test result handling, Polarion push, shared library
architecture, and admin operations for all pipelines Atif works with.

## When to Use

- Pipeline failure investigation ("why did the build fail", "which stage failed")
- Build triggering with parameter validation
- Test result analysis (JUnit XML, pass/fail, component breakdown)
- Polarion result push debugging ("results not showing in Polarion")
- CI/CD architecture questions ("how does CLC push to Polarion", "what tests does VIRT run")
- Adding new components to the orchestrator pipeline
- Shared library modifications (new vars/*.groovy files)
- Jenkins job configuration and admin operations

## MANDATORY: Gate Enforcement

### Read operations (no permission needed)
All MCP tools except `trigger_build`. Safe to run: `get_job`, `get_build`, `get_build_log`,
`get_build_status`, `get_pipeline_stages`, `analyze_pipeline`, `get_downstream_tree`,
`get_test_results`, `analyze_test_results`.

### State-changing (MUST ask first)
- `trigger_build` (MCP) and `jenkins-run trigger` (CLI)
- Any shared library or Jenkinsfile modifications
- Before triggering, STOP and show: job path, all parameters, expected behavior
- Wait for explicit user approval

### Trigger gate TodoWrite pattern
```
analyze-job | pending
prepare-params | pending
GATE: user-approval | pending
trigger-build | pending
monitor-result | pending
```

## ASK QUESTIONS FIRST

Before any Jenkins operation, clarify:

| Need | Ask |
|------|-----|
| Build URL or job path | "Which Jenkins build/job?" |
| Scope | "Quick status, stage view, or full root cause analysis?" |
| For trigger | "Confirm parameters and preview (dry-run) first?" |
| For architecture | "Which pipeline? Orchestrator, virt, CLC, or Playwright?" |

## Core Knowledge

Load knowledge files based on the task:

| Task | Load |
|------|------|
| Architecture overview | `knowledge/architecture.md` |
| Orchestrator questions | `knowledge/orchestrator.md` |
| Virt pipeline questions | `knowledge/virt-pipeline.md` |
| Console-e2e Playwright pipelines | `knowledge/console-e2e-pipelines.md` |
| Cluster provisioning/destruction | `knowledge/cluster-provisioning.md` |
| Polarion push issues | `knowledge/polarion-integration.md` |
| Shared library changes | `knowledge/shared-library.md` |
| Container/pod issues | `knowledge/agent-pods.md` |
| Writing Jenkinsfiles | `framework/jenkinsfile-patterns.md` |
| Parameter mapping | `framework/parameter-mapping.md` |

## Engram Integration

Before investigating, check persistent knowledge:
- `engram_recall("Jenkins pipeline patterns ACM")`
- `engram_recall("Jenkins MCP tools pipeline")`

After discovering new patterns, store them:
- `engram_remember("New finding: ...")`

## Phases (Complex Operations)

For multi-step tasks like "add a new component to CI":

### Phase 1: Investigate
- Read `knowledge/shared-library.md` and `knowledge/orchestrator.md`
- Identify all files that need changes (5-file pattern)
- Check for naming collisions in `TEST_STAGES` (substring matching)

### Phase 2: Implement
1. Create `vars/<component>.groovy` (wrapper function)
2. Add stage to `e2e/e2e-common/Jenkinsfile`
3. Add component to `ciParams.getSupportedTestComponents()`
4. Add case to `ciUtils.getComponentInfo()` (name + Slack owners)
5. Add squad mapping in `polarion/polarion_helpers.py`

### Phase 3: Verify
- Trigger standalone pipeline to confirm JUnit XML
- After merge to main, trigger orchestrator with component stage + POLARION
- Verify artifacts archived, JUnit collected, Polarion updated

## Workflow Quick Reference

| Task | Sequence | Knowledge File |
|------|----------|---------------|
| Investigate failure | `get_build_status` → `get_pipeline_stages` → `get_build_log(start=-200)` → `analyze_pipeline(console_lines=200)` | — |
| Check test results | `get_test_results(mode="failures")` → `analyze_test_results(failures_only=True)` | — |
| Trigger pipeline (gated) | `get_job` → CLI `--dry-run` → show params → `trigger_build` → monitor | — |
| Add component to CI | Read `knowledge/orchestrator.md`. Files: vars/*.groovy, Jenkinsfile, ciParams, ciUtils, polarion_helpers | `orchestrator.md` |
| Debug Polarion push | Check: JUnit XML archived, results/<component>/ exists, squad mapping, RHACM4K IDs in test names | `polarion-integration.md` |
| Run Playwright on Jenkins | Identify Jenkinsfile, set CONSOLE_GIT_BRANCH + EXTRA_PLAYWRIGHT_ARGS (--project + spec path) | `console-e2e-pipelines.md` |
| Provision ACM cluster | `get_job("CI-Jobs/ocp_deploy_and_acm_install")` → set params → trigger (gated) | `cluster-provisioning.md` |
| Destroy cluster | `trigger CI-Jobs/pics_cloud_destroy` with PLATFORM + OCP_CLUSTER_NAME (InfraID) | `cluster-provisioning.md` |
| Monitor running build | CLI only: `jenkins-run monitor <URL> --interval 60 --timeout 120` | — |

**Default bounded reads:** Always use `start=-200` for logs and `mode="failures"` for test results. Widen only if error not found in last 200 lines.

## Tools and Paths

For full MCP tool parameters, CLI command syntax, and file locations, read `references/tools-and-paths.md`.

## Known Limitations

1. `analyze_pipeline` and `get_pipeline_stages` require Pipeline (wfapi); FreeStyle jobs limited
2. SSL verification disabled (Red Hat internal CA)
3. `get_build_log` returns last 500 lines by default; use `start`/`max_lines` for more
4. MCP `get_build_status` is single-poll; use CLI `jenkins-run monitor` for continuous
5. No dry-run in MCP `trigger_build`; use CLI `jenkins-run trigger --dry-run`
6. Shared library (`@Library('ci-shared-lib')`) loads from main only; new groovy files require merge before orchestrator can use them
7. `TEST_STAGES.contains()` uses substring matching -- avoid names that are substrings of existing stages (e.g., use VIRT_CONSOLE not VIRT to avoid matching HDRVIRT)
8. `get_all_jobs` returns root-level only, not full recursive tree

## Default Environment

When no environment is specified for test execution, read `~/Documents/work/notes/notes.md` first 3 lines for the current hub URL and password.

## Freshness Protocol

All knowledge files have a `Last verified` date comment. When acting on file paths, pod counts, parameter lists, or image names, verify against the live repo (`acmqe-autotest/`) or Jenkins MCP (`get_job`) before trusting static docs. Static docs are a starting point, not the source of truth.

## Permission Rules

- READ-ONLY (no permission needed): All tools except trigger
- STATE-CHANGING (MUST ask first): `trigger_build` (MCP), `jenkins-run trigger` (CLI)
- FILE CHANGES (MUST ask first): Any modification to Jenkinsfiles, groovy files, or Python scripts

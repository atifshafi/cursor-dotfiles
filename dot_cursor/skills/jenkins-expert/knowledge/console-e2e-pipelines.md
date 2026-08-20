<!-- Last verified: 2026-08-10 against acmqe-autotest components/console/ -->
<!-- Verify paths and counts against the live repo before acting on specifics -->

# Console-E2E Playwright Pipelines

6 Jenkinsfiles under `acmqe-autotest/ci/jenkinsfiles/components/console/` run Playwright E2E tests from `stolostron/console-e2e`.

## Pipeline Summary

| Jenkinsfile | Component | Entry Point | Timeout | Notes |
|-------------|-----------|-------------|---------|-------|
| Jenkinsfile_console_alc | ALC | `./start.sh alc --project alc` | 120 min | Has withCredentials for OBJECTSTORE, GITHUB_TOKEN; Ansible params; `fix-junit-polarion-names.sh` |
| Jenkinsfile_console_clc | CLC | `./start.sh alc --project alc` | 120 min | Copy of ALC template |
| Jenkinsfile_console_discovery | Discovery | `./start.sh alc --project alc` | 120 min | Copy of ALC template |
| Jenkinsfile_console_grc | GRC/Governance | `./start.sh alc --project alc` | 120 min | Copy of ALC template (should run `--project governance` but doesn't) |
| Jenkinsfile_console_search | Search | `./start.sh alc --project alc` | 120 min | Copy of ALC template |
| Jenkinsfile_console_virt_e2e | Virt/FG-RBAC | `./start.sh fg-rbac --project fg-rbac --project fleet-virt` | 8 hours | Fully customized (see dedicated section below) |

**Known issue:** CLC, Discovery, GRC, and Search Jenkinsfiles are copy-pasted from the ALC template. They all run `./start.sh alc --project alc` regardless of component name. Use `PLAYWRIGHT_GREP` or `EXTRA_PLAYWRIGHT_ARGS` to override which tests run.

## Common Parameters (all 6 pipelines)

| Parameter | Default | Purpose |
|-----------|---------|---------|
| OCP_API_URL | (required) | Hub API URL -> HUB_URL env |
| OCP_PASSWORD | (required) | Hub password -> HUB_PASSWORD env |
| OCP_USER | kubeadmin | Hub admin user -> CONSOLE_USERNAME env |
| CONSOLE_IDP | (empty) | Identity provider -> CONSOLE_IDP env |
| CONSOLE_GIT_BRANCH | main | Branch of stolostron/console-e2e to checkout |
| PLAYWRIGHT_GREP | (empty) | Tag filter (e.g. `@governance`, `@clusters`) |
| PLAYWRIGHT_GREP_INVERT | (empty) | Exclude filter (e.g. `@slow`) |
| EXTRA_PLAYWRIGHT_ARGS | (empty) | Extra args appended to start.sh (e.g. `--project governance src/tests/governance/my.spec.ts`) |
| PLAYWRIGHT_PROJECT | (empty) | Optional env override for --project |

## Agent Pod

All 6 use `ciAgentPod_console.yaml` with `ubi9-playwright` image (Node.js + Playwright browsers). Cloud: `ciUtils.getJenkinsCloud()`.

## Artifacts

| Type | Path |
|------|------|
| JUnit XML | `test-results/junit.xml` (archived under `console/test-results/`) |
| HTML Report | `playwright-report/` |
| Screenshots | `test-results/**/test-failed-*.png` (on failure) |
| Traces | `test-results/**/trace.zip` (on first retry) |

## How to Run a Specific Test

To run the governance wizard-review-show-changes spec via the GRC pipeline:
- `CONSOLE_GIT_BRANCH`: your branch name
- `EXTRA_PLAYWRIGHT_ARGS`: `--project governance src/tests/governance/wizard-review-show-changes.spec.ts`

Or override completely with:
- `PLAYWRIGHT_GREP`: `@governance`

---

## Virt Pipeline (Dedicated Section)

The virt pipeline (`Jenkinsfile_console_virt_e2e`) is the most complex of the 6. Full reference: `knowledge/virt-pipeline.md`.

### Key Differences from Other Console Pipelines

| Aspect | Other 5 | Virt |
|--------|---------|------|
| Timeout | 120 min | 8 hours |
| Entry point | `./start.sh alc --project alc` | `./start.sh fg-rbac --project fg-rbac --project fleet-virt` |
| Spoke provisioning | None | Azure UI + BM MIST (downstream jobs) |
| RBAC setup | None | gen-rbac.sh, install-glauth.sh, setup-test-roles.sh |
| Test selection | PLAYWRIGHT_GREP | Tier-based (full/vm/rbac-ui) based on platform detection |
| CNV dependency | None | Requires CNV on spoke for fleet-virt tests |

### Stages

1. Validate Params
2. Checkout console-e2e + acmqe-autotest
3. Install Dependencies (npm ci)
4. Azure Spoke Provisioning (if tier includes azure) -- calls `virt_cclm_tests` downstream
5. BM Spoke Provisioning (if tier includes bm) -- calls `clc_bm_spoke_provisioning` downstream
6. RBAC User Setup -- runs gen-rbac.sh, install-glauth.sh, setup-test-roles.sh
7. Platform Detection -- detects CNV version, determines tier
8. Test Execution -- `./start.sh fg-rbac --project fg-rbac --project fleet-virt` with tier tags
9. Post Actions -- archive artifacts, junit, fix-junit-polarion-names.sh

### Tier Table

| Tier | Tags | What Runs |
|------|------|-----------|
| full (Azure) | `@fg-rbac`, `@fleet-virt` | All FG-RBAC + Fleet Virt specs |
| vm | `@fleet-virt` | Fleet Virt specs only |
| rbac-ui | `@fg-rbac` | FG-RBAC specs only |
| custom | PLAYWRIGHT_GREP value | User-provided |

### Virt-Specific Parameters

| Parameter | Default | Purpose |
|-----------|---------|---------|
| VIRT_SPOKE_CLUSTER | (auto-discover) | Spoke cluster name |
| VIRT_TIER | full | Test tier |
| RBAC_TEST_PASSWORD | (required) | Password for clc-e2e-* test users |
| CNV_VERSION | (auto-detect) | CNV version on spoke |

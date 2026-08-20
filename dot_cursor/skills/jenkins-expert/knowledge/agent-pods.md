<!-- Last verified: 2026-08-10 against acmqe-autotest agent_pod_config/ -->
<!-- Verify paths and counts against the live repo before acting on specifics -->

# Jenkins Agent Pod Configurations

## Location
`acmqe-autotest/ci/jenkinsfiles/agent_pod_config/`

## Available Pod Configs (20 total)

| YAML File | Workload Image | Used By |
|-----------|---------------|---------|
| ciAgentPod_pics.yaml | pics:ubi9 | Orchestrator (e2e_ui_test_pipeline) |
| ciAgentPod_python.yaml | Python-based | Python test suites |
| ciOcpAgentPod_python.yaml | Python on OCP | OCP-specific Python tests |
| ciAgentPod_virt_e2e.yaml | centos9-nodejs22 | virt_console_e2e_tests (Cypress) |
| ciAgentPod_cclm.yaml | (CCLM setup) | virt_cclm_tests |
| ciAgentPod_discovery.yaml | centos9-nodejs22 | Discovery CLI/Cypress |
| ciAgentPod_console.yaml | ubi9-playwright | console-e2e (Playwright -- all 6 console pipelines) |
| ciAgentPod_alc_backend.yaml | (ALC backend) | alc_backend_tests |
| ciAgentPod_capz.yaml | (CAPZ) | capz_tests |
| ciAgentPod_install.yaml | (Install) | install_e2e_tests |
| ciAgentPod_clc.yaml | (CLC) | CLC pipeline |
| ciAgentPod_grc.yaml | (GRC) | GRC pipeline |
| ciAgentPod_globalhub.yaml | (Global Hub) | Global Hub tests |
| ciAgentPod_prodsec.yaml | (Prodsec) | Prodsec scans |
| ciAgentPod_observability.yaml | (Obs) | Observability tests |
| ciAgentPod_serverfoundation.yaml | (SF) | Server Foundation tests |
| ciAgentPod_bm_olm.yaml | (BareMetal) | BM OLM deployments |
| ciAgentPod_site-config.yaml | (Site config) | Site-config tests |
| ciAgentPod_ks.yaml | (K8s) | EKS/AKS/GKE tests |
| ciAgentPod_with-vcenter-trust.yaml | (vCenter) | VMware/vSphere tests |

All files use the `ciAgentPod_` prefix consistently.

## Pod Config Pattern

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: console-container           # workload container
      image: quay.io/vboulos/acmqe-automation/pics:ubi9-playwright
      command: ['sleep']
      args: ['infinity']
      resources:
        requests:
          cpu: "2"
          memory: "4Gi"
        limits:
          cpu: "4"
          memory: "8Gi"
    - name: jnlp                         # Jenkins agent sidecar
      image: images.paas.redhat.com/jenkins-csb/inbound-agent-sidecar:latest
      resources:
        requests:
          cpu: "500m"
          memory: "256Mi"
```

## Key Images

| Image | Node/Browser | Used For |
|-------|-------------|----------|
| `acm-qe:centos9-nodejs22` | Node.js 22, Chrome | Cypress tests (virt, discovery) |
| `pics:ubi9` | Generic | Orchestrator (artifact copy, coordination) |
| `pics:ubi9-playwright` | Node.js, Playwright browsers | console-e2e (Playwright) |
| `inbound-agent-sidecar:latest` | JNLP | Jenkins agent in every pod |

## Cloud Configuration

Console Playwright pipelines use dynamic cloud selection:
```groovy
cloud ciUtils.getJenkinsCloud()
```
This load-balances across available cloud pools. Older pipelines may hardcode a specific cloud name.

## Referencing in Jenkinsfile

```groovy
agent {
    kubernetes {
        defaultContainer 'console-container'
        yamlFile 'ci/jenkinsfiles/agent_pod_config/ciAgentPod_console.yaml'
        cloud ciUtils.getJenkinsCloud()
    }
}
```

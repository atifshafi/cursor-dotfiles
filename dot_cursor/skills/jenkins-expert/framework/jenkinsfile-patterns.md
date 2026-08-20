# Jenkinsfile Patterns and Conventions

## Declarative Pipeline Skeleton

```groovy
@Library('ci-shared-lib') _

def CI_Jobs_folder = ciUtils.getCIJobsFolder()

pipeline {
    options {
        buildDiscarder(logRotator(daysToKeepStr: '30'))
        skipDefaultCheckout()                        // optional
        timeout(time: 8, unit: 'HOURS')
    }
    agent {
        kubernetes {
            defaultContainer 'container-name'
            yamlFile 'ci/jenkinsfiles/agent_pod_config/ciAgentPod_xxx.yaml'
            cloud 'remote-ocp-cluster-itup-prod'
        }
    }

    parameters {
        string(name: 'PARAM', defaultValue: '', description: '...')
        booleanParam(name: 'FLAG', defaultValue: false, description: '...')
        choice(name: 'CHOICE', choices: ['a', 'b'], description: '...')
        password(name: 'SECRET', description: '...')
    }

    environment {
        CI = 'true'
    }

    stages {
        stage('Stage Name') {
            when {
                expression { return someCondition }
            }
            steps {
                script { ... }
            }
        }
    }

    post {
        always {
            script {
                archiveArtifacts artifacts: '**/reports/*', allowEmptyArchive: true
                junit allowEmptyResults: true, testResults: '**/reports/*.xml'
            }
        }
        failure {
            echo 'Pipeline failed.'
        }
    }
}
```

## Stage Gating Pattern (Orchestrator)

The orchestrator uses `TEST_STAGES.contains()` for stage gating:

```groovy
stage('Run Component Tests') {
    when {
        expression { params.TEST_STAGES.contains('COMPONENT_NAME') }
    }
    steps {
        script {
            def buildResult = component.callComponentE2E(params, API_URL)
            results["component_key"] = buildResult.getAbsoluteUrl()
            ciUtils.archArtifacts("${CI_Jobs_folder}/jenkins_job_name",
                "${buildResult.getNumber()}", "reports/*.xml", 'results/component_key')
        }
    }
}
```

### Substring Collision Avoidance

`String.contains()` is substring matching. This means:
- `"HDRVIRT,POLARION".contains("VIRT")` → TRUE (unintended!)
- `"ALC_CONSOLE,ALC_BACKEND".contains("ALC")` → TRUE (intentional parent gate)

Rules:
- Use unique prefixes: `VIRT_CONSOLE` not `VIRT`
- Check the full default TEST_STAGES string before naming
- Intentional parent gates (like ALC matching ALC_CONSOLE) are OK when documented

## Downstream Job Triggering

```groovy
def buildResult = build propagate: false,
    job: "${ciUtils.getCIJobsFolder()}/job_name",
    parameters: [
        string(name: 'PARAM', value: "${params.UPSTREAM_PARAM}"),
        booleanParam(name: 'FLAG', value: true),
        password(name: 'SECRET', value: "${params.PASSWORD}")]
```

- `propagate: false` -- don't fail parent if child fails (standard for orchestrator)
- `propagate: true` -- fail parent if child fails (used for critical setup stages)
- Return `buildResult` for `.getAbsoluteUrl()` and `.getNumber()`

## Artifact Archiving Patterns

### Component pipeline (archives its own results):
```groovy
archiveArtifacts artifacts: '**/reports/*', followSymlinks: false, allowEmptyArchive: true
junit allowEmptyResults: true, testResults: '**/reports/*.xml'
```

### Orchestrator (copies from downstream):
```groovy
ciUtils.archArtifacts(
    "${CI_Jobs_folder}/job_name",     // downstream job
    "${buildResult.getNumber()}",      // build number
    "reports/*.xml",                   // filter (what to copy)
    'results/component_key')           // target directory
```

### Orchestrator aggregate:
```groovy
archiveArtifacts artifacts: 'results/**/*', followSymlinks: false
junit 'results/**/*.xml'
```

## Error Handling

### try/catch in component wrappers (don't break orchestrator):
```groovy
try {
    def buildResult = build propagate: false, job: "..."
    return buildResult
} catch(ex) {
    echo 'Component failed: ' + ex.getMessage()
    echo '... Continuing with the pipeline'
}
```

### try/catch for artifact archiving (workspace may not exist):
```groovy
try {
    archiveArtifacts artifacts: '**/reports/*', allowEmptyArchive: true
    junit allowEmptyResults: true, testResults: '**/reports/*.xml'
} catch (e) {
    echo "Artifact archiving skipped: ${e.message}"
}
```

### Abort check in post block:
```groovy
post {
    always {
        script {
            if (currentBuild.result == 'ABORTED' || currentBuild.currentResult == 'ABORTED') {
                echo 'Aborted. Skipping post-config.'
            } else {
                // normal post-actions
            }
        }
    }
}
```

## Credential Handling

### withCredentials for files:
```groovy
withCredentials([file(credentialsId: 'clc-auto-options-file', variable: 'OPTIONS_FILE')]) {
    sh "cat \$OPTIONS_FILE > options.yaml"
}
```

### withCredentials for tokens:
```groovy
withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
    sh "git clone https://x-oauth-basic:${GITHUB_TOKEN}@github.com/..."
}
```

### Security warning suppression:
Jenkins warns about Groovy string interpolation with secrets. This is expected for
`password()` parameters passed to `build` steps.

## Git Clone Pattern (for test repos)

```groovy
stage('Checkout Test Code') {
    steps {
        retry(count: 3) {
            script {
                withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
                    sh """
                        rm -rf ./* ./.[!.]* 2>/dev/null || true
                        git -c http.https://github.com/.extraheader="AUTHORIZATION: basic \$(echo -n x-oauth-basic:${GITHUB_TOKEN} | base64)" \
                            -c http.sslVerify=false \
                            clone -b "${params.BRANCH}" \
                            "https://github.com/stolostron/repo.git" .
                    """
                }
            }
        }
    }
}
```

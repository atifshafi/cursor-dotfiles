# CI/SEM Environment-Specific Checks

Additional checks for CI/test environments (Jenkins pipelines, SEM clusters) beyond the standard 12-layer model. These catch issues specific to automated testing infrastructure.

---

## Route Accessibility

Test environments often fail because routes are unreachable, not because the backend is broken.

```bash
# Console route
oc get route multicloud-console -n $MCH_NS -o jsonpath='{.spec.host}'
# Verify: curl -sk https://<route-host>/multicloud/welcome -o /dev/null -w '%{http_code}'
# Expected: 200 or 302

# Search API route (if exposed)
oc get route search-api -n $MCH_NS -o jsonpath='{.spec.host}' 2>/dev/null

# OAuth server
oc get route oauth-openshift -n openshift-authentication -o jsonpath='{.spec.host}'
```

**Red flags:**
- 503 → router pod or backend pod down
- 502 → backend pod exists but isn't responding
- Connection timeout → DNS resolution failure or network issue
- Certificate error → route cert expired or doesn't match hostname

---

## Test User Authentication

CI tests authenticate as test users (not kubeadmin). Authentication failures are common.

```bash
# Check OAuth server health
oc get pods -n openshift-authentication --no-headers

# Check if HTPasswd IDP is configured (common for test users)
oc get oauth cluster -o jsonpath='{.spec.identityProviders[*].name}'

# Check if test users exist
oc get users --no-headers | grep -E '(user1|test-user|rbac)'

# Verify test user can authenticate
oc login --username=<test-user> --password=<password> --server=<api-url> --insecure-skip-tls-verify 2>&1
# IMPORTANT: switch back to admin kubeconfig after testing
```

**Common CI auth failures:**
- HTPasswd secret deleted or corrupted → all non-admin users can't login
- OAuth pods restarting → intermittent auth failures
- LDAP IDP unreachable → external dependency down
- User tokens expired → long-running CI sessions

---

## Jenkins Agent Pod Connectivity

When tests run in Jenkins agent pods (Kubernetes plugin), the agent needs cluster access.

```bash
# Check if the Jenkins agent pod can reach the API server
# (This is verified by the pre-flight check, but if tests fail with auth errors...)

# Verify ServiceAccount token is valid
oc whoami
oc auth can-i get pods -n $MCH_NS

# Check if the test kubeconfig has correct server URL
# Sometimes CI uses internal cluster URL vs external route
oc config view --minify -o jsonpath='{.clusters[0].cluster.server}'
```

**Common CI connectivity issues:**
- API server URL in kubeconfig uses internal DNS but agent is external
- ServiceAccount token expired (>24h CI run)
- Network policy blocking agent → API server communication
- Proxy settings incorrect in agent pod

---

## CatalogSource Health

Operator installs depend on CatalogSources being healthy. Unhealthy catalogs block upgrades and installs.

```bash
# Check all CatalogSources
oc get catalogsource -n openshift-marketplace --no-headers
oc get pods -n openshift-marketplace --no-headers

# Check ACM-specific catalog (if custom)
oc get catalogsource -A | grep -i acm

# Check if catalog pods are Running and READY
oc get pods -n openshift-marketplace -l olm.catalogSource=redhat-operators --no-headers
```

**Red flags:**
- CatalogSource pod in CrashLoopBackOff → index image unreachable or corrupted
- READY column shows 0/1 → gRPC server not responding
- Custom ACM catalog missing → nightly builds can't be installed

---

## Certificate and Token Expiry

CI environments often have short-lived certificates or tokens that expire during long test runs.

```bash
# Check API server certificate
oc get secret router-ca -n openshift-ingress-operator -o jsonpath='{.data.tls\.crt}' 2>/dev/null | base64 -d | openssl x509 -noout -enddate

# Check pending CSRs (nodes may need cert approval)
oc get csr | grep Pending

# Check if kubeconfig token is still valid
oc whoami 2>&1
# "Unauthorized" after successful earlier commands → token expired

# Check ingress certificate expiry
oc get secret router-certs-default -n openshift-ingress -o jsonpath='{.data.tls\.crt}' 2>/dev/null | base64 -d | openssl x509 -noout -enddate
```

**Rule:** If authentication worked at pipeline start but fails mid-run, token/cert expiry is the most likely cause.

---

## Test Infrastructure Readiness

CI pipelines may require specific ConfigMaps, Secrets, or resources to exist before tests run.

```bash
# Check for test-specific namespaces
oc get ns | grep -E '(e2e|test|automation)'

# Check for test ConfigMaps (common patterns)
oc get configmap -n $MCH_NS | grep -E '(test|e2e|automation)'

# Check if cluster has managed clusters (required for multi-cluster tests)
oc get managedclusters --no-headers | wc -l

# Check if specific addons are deployed (required for feature-specific tests)
oc get managedclusteraddons -A --no-headers | sort | uniq -c
```

---

## OCP Version Compatibility

Some ACM features require specific OCP versions. Version mismatches cause subtle failures.

```bash
# Get OCP version
oc get clusterversion -o jsonpath='{.items[0].status.desired.version}'

# Get ACM version
oc get mch -A -o jsonpath='{.items[0].status.currentVersion}'

# Known incompatibilities:
# - ACM 2.16 + OCP 4.18: Submariner gateway issues (ACM-22805)
# - ACM 2.15 + OCP 4.17: Some console features require PatternFly updates
```

---

## Pipeline-Specific Environment Variables

Jenkins pipelines pass configuration via environment variables. Missing or wrong values cause test failures.

Check for common patterns:
- `CYPRESS_BASE_URL` / `PLAYWRIGHT_BASE_URL` → must match console route
- `KUBECONFIG` → must point to valid kubeconfig with admin access
- `MANAGED_CLUSTER_NAME` → must be a cluster that exists and is Available
- `OC_CLUSTER_URL` → must be reachable from test pod
- `OC_CLUSTER_TOKEN` → must not be expired

# 10-Dimension Analysis Model

Derived from ACM's 8-subsystem architecture (hub-spoke ManifestWork delivery, console plugin proxy chain, search collector pipeline, addon framework, GRC compliance propagation, ALC channel/subscription deployment, observability metrics chain, cluster lifecycle). Validated against 77 Console/CLC Polarion test cases. Question templates adapt dynamically based on the detected feature area.

---

## Dimension 1: Specification Fidelity

Does the implementation match what was specified?

**Investigation focus:**
- Compare JIRA acceptance criteria to implemented behavior in the PR diff
- Compare API contracts (CRD schemas, webhook validations) to what the code enforces
- Check for spec drift: role names changed, field renames, deprecated APIs

**Tools:** JIRA MCP (`get_issue`), GitHub MCP (PR diff), ACM Source MCP (CRD schemas). **Skip when:** no JIRA reference (standalone/legacy case).

---

## Dimension 2: Resource Lifecycle

Are resources created, read, updated, and deleted correctly?

**Investigation focus:**
- Trace each resource: create with required fields? Update preserves untouched fields? Delete cleans up dependents (finalizers, owner references)?
- Check for orphaned resources, naming conflicts, label selector collisions, namespace scoping

**Tools:** ACM Source MCP (controller code, webhook code), `oc` CLI, GitHub MCP. **Skip when:** read-only/observational test.

---

## Dimension 3: Authorization Chain

Are permissions checked correctly at every hop in the request path?

**Investigation focus:**
- ACM auth chain: User token -> OCP Console -> ConsolePlugin proxy (UserToken forwarding) -> ACM console backend -> Kubernetes API -> controllers
- Multicluster: hub RBAC -> ManifestWork -> spoke RBAC -> ClusterPermission/MCRA
- Check positive and negative authorization paths
- Check `oc auth can-i` alignment with UI state (discrepancy = product bug)

**Tools:** ACM Source MCP (RBAC code), `oc auth can-i`, Neo4j RHACM

**Skip when:** Test uses cluster-admin and doesn't test permission boundaries

**Cross-area examples:**
- Console RBAC: UserToken -> ConsolePlugin proxy -> backend -> MCRA RBAC
- GRC: Admin vs viewer for policy creation vs status viewing
- ALC: Namespace-scoped subscription permissions, channel access
- Cluster LC: Cluster admin vs viewer for provisioning vs inspection

---

## Dimension 4: Multicluster Propagation

Does the hub-to-spoke delivery chain work correctly?

**Investigation focus:**
- Hub CR -> Controller -> ManifestWork -> klusterlet work-agent -> spoke resources -> status back to hub
- Addons: ClusterManagementAddOn + Placement -> ManagedClusterAddOn -> ManifestWork -> spoke agent
- Verify hub actions reach spoke, status propagation back, ManifestWork ordering, addon health

**Tools:** `acm-kubectl` MCP, `acm-search` MCP (`find_resources(kind="ManagedClusterAddon", name="<addon>", outputMode="list")` for fleet-wide addon status, `find_resources(kind="ManifestWork", namespace="<cluster-ns>", outputMode="count")` for work distribution), `oc get managedclusteraddons/manifestwork`, Neo4j RHACM

**Skip when:** Test is hub-only (no managed clusters involved)

**Cross-area examples:**
- Console RBAC: MCRA -> ClusterPermission -> spoke ServiceAccount
- GRC: Policy -> PlacementBinding -> ManifestWork -> spoke compliance
- ALC: Subscription -> ManifestWork -> spoke Deployable -> app pods
- Observability: ObservabilityAddon -> spoke metrics-collector -> hub Thanos
- Submariner: SubmarinerConfig -> ManifestWork -> spoke gateway/routeagent

---

## Dimension 5: Data Pipeline Integrity

Does data flow correctly across component boundaries?

**Investigation focus:**
- Search: collectors -> indexer -> postgres -> search-api -> console
- Metrics: spoke -> observability -> thanos -> grafana
- Policy: spoke compliance -> hub -> propagator -> console
- RBAC: MCRA -> controller -> ClusterPermission -> spoke SA

**Tools:** ACM Source MCP, `acm-search` MCP, `oc` CLI, Neo4j RHACM. **Skip when:** test doesn't cross component boundaries.

**Cross-area examples:**
- Console: Search collector -> indexer -> postgres -> search-api -> UI
- GRC: Spoke compliance -> policy-status-sync -> hub -> propagator -> UI
- Observability: Spoke metrics -> hub receiver -> Thanos -> Grafana
- Search: Collector -> indexer batching -> SQL -> GraphQL response

---

## Dimension 6: Integration Surface & Cross-Component Probing

The most thorough dimension. See [safety-protocol.md](safety-protocol.md) for probe creation rules.

**6.1 Dependency Mapping:** Neo4j dependency graph, classify REQUIRED/OPTIONAL/INFORMATIONAL

**6.2 Dependency Health Audit (read-only):** Verify REQUIRED dependencies exist and are healthy on live cluster. Use `acm-search` for fleet-wide checks: `find_resources(kind="ClusterServiceVersion", outputMode="health")` for operator health, `find_resources(kind="Pod", status="CrashLoopBackOff,Error", groupBy="cluster")` for failing pods by cluster.

**6.3 Data Workflow Trace (read-only):** Trace data path across component boundaries in source code

**6.4 Integration Probing (minimal resource creation):** Create probe resources per safety protocol. Skip if no cluster.

**6.5 Cleanup and Verification (mandatory):** Delete all probe resources, verify cleanup.

**Cross-area examples:**
- All: Addon dependencies, operator health, CRD prerequisites
- GRC: grc-policy-addon depends on framework CRDs on spoke
- ALC: Channel controller depends on Git/Helm/ObjectBucket backend
- Submariner: Depends on spoke node labels, OVN/OpenShiftSDN network plugin

---

## Dimension 7: State & Transition Logic

Does the feature handle state changes correctly?

**Investigation focus:**
- Map the state machine, check intermediate states the test case doesn't verify
- Check side effects of modifying one resource on another

**Tools:** ACM Source MCP (state management code), JIRA comments. **Skip when:** stateless test (single read operation).

**Cross-area examples:**
- Console RBAC: RA scope type transitions (Global -> ClusterSet -> Cluster)
- GRC: Policy compliance state machine (Compliant/NonCompliant/Pending)
- ALC: App deployment states (Propagated/Failed/Subscribed)
- Cluster LC: Cluster states (Creating/Ready/Destroying/Detaching)

---

## Dimension 8: Boundary & Edge Conditions

Does the feature handle limits and special cases?

**Investigation focus:**
- Zero items, one item, maximum items
- Special characters in names, labels, annotations
- Concurrent operations, permission boundaries, empty sets, boundary overlaps

**Tools:** ACM Source MCP (conditional branches, validation code), stolostron/rhacm-docs

**Always applies.**

---

## Dimension 9: Failure & Recovery Paths

What happens when things go wrong?

**Investigation focus:**
- Error handling for invalid input, network failures, API errors
- Partial failure scenarios, recovery to clean state, error message accuracy

**Tools:** ACM Source MCP (error handling code), JIRA (existing bugs). **Skip when:** purely happy-path with no known failure modes (rare).

---

## Dimension 10: Observable Output

Does what users/systems see match actual state?

**Investigation focus:**
- UI: reflects backend state? Buttons enabled/disabled correctly? Labels accurate?
- Non-UI: CR status conditions accurate? CLI output correct?
- All: observable output matches actual state verified by `oc` CLI? Discrepancy = product bug.

**Tools:** ACM Source MCP (rendering/status code), browser MCP (if live + UI), `oc` CLI

**Always applies.**

---

## Dimension Applicability Matrix

| Dimension | UI Test | CLI/API Test | Policy Test | Install Test |
|-----------|---------|--------------|-------------|-------------|
| 1. Specification Fidelity | YES | YES | YES | YES |
| 2. Resource Lifecycle | if CRUD | YES | YES | YES |
| 3. Authorization Chain | if RBAC | if non-admin | if non-admin | skip |
| 4. Multicluster Propagation | if spoke | YES | YES | skip |
| 5. Data Pipeline Integrity | if data | if cross-svc | if status | skip |
| 6. Integration Surface | depends | depends | depends | YES |
| 7. State & Transition Logic | if CRUD | if stateful | if status | if upgrade |
| 8. Boundary & Edge Cases | YES | YES | YES | YES |
| 9. Failure & Recovery | YES | YES | YES | YES |
| 10. Observable Output | YES | YES | YES | YES |

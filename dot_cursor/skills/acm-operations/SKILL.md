---
name: acm-operations
description: ACM cluster operations including build tag identification, operator refresh to latest nightly, fix/PR verification, and cloud cluster destruction. Use when user asks about ACM build tag, image tag, snapshot, downstream tag, what build is on the cluster, refresh/update/reinstall ACM, pick up latest nightly, check if a fix/PR is present on a cluster, or destroy/deprovision a cloud OCP cluster.
---

# ACM Operations

Cluster-level operations for ACM dev/downstream environments: identifying builds, refreshing to latest nightly, verifying fixes, and destroying clusters.

---

## Operation Dispatch (read EXACTLY ONE operation file)

| User intent keywords | Operation file |
|---------------------|----------------|
| build tag, image tag, snapshot, downstream tag, what build, version, build date | `operations/build-tag.md` |
| refresh, update, reinstall, pick up latest, nightly | `operations/refresh-acm.md` |
| fix present, PR included, commit, check if, is the fix, verify fix on cluster | `operations/fix-check.md` |
| destroy, tear down, deprovision, delete cluster, clean up | `operations/destroy-cluster.md` |

**Rule:** Read EXACTLY ONE operation file based on user intent. Do not defensively load multiple files.

---

## MANDATORY: Gate Enforcement

**Cluster-mutating operations require explicit user permission. This is NON-NEGOTIABLE.**

| Operation | Permission |
|-----------|-----------|
| Get build tag (read-only) | No permission needed |
| Refresh ACM (state-changing) | **MUST ask user first** |
| Check if fix present (read-only) | No permission needed |
| Destroy cluster (destructive) | **MUST ask user first** |

For Op 2 (refresh) and Op 4 (destroy), create a TodoWrite with a `GATE: user-approval` step that CANNOT be marked completed by the agent.

---

## Knowledge Sources

**ACM Knowledge DB (check FIRST)**: `search_knowledge(query=<operation area>)` or read from `/Users/ashafi/Documents/work/notes/knowledge/`:
- `architecture/<subsystem>/architecture.md` -- component names, namespaces, CRDs
- `baselines/` -- expected pod counts, operator statuses
- `health/<subsystem>/known-issues.md` -- known issues affecting operations

**Engram**: `engram_recall("ACM architecture components")`, `engram_recall("healthy ACM hub baseline")`

---

## ASK QUESTIONS FIRST

| Question | Why |
|----------|-----|
| Which cluster? | Need `oc` access (kubeconfig) |
| Which ACM namespace? | Usually `ocm` or `open-cluster-management` |
| (For fix check) Which PR/commit/JIRA? | Need to know what to look for |

If the user already has an active `oc` session in context, skip the cluster question.

---

## Prerequisites

- `oc` CLI logged in with a session-specific kubeconfig
- Cluster pull secret access (`multiclusterhub-operator-pull-secret` in ACM namespace)

---

## Integration with Other Skills

| Skill | Integration |
|-------|------------|
| `jira-operations` | Build tag for bug `h4. Version-Release number` and verification comments |
| `active-sprint-tasks` | Build tag identifies which env a sprint task was tested on |
| `jenkins-expert` | Jenkins builds produce catalog images; `pics_cloud_destroy` destroys clusters |

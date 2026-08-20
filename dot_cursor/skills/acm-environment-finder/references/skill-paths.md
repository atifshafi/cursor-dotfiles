# Skill delegation paths

## Cursor paths (this machine)

`acm-environment-finder` delegates to sibling skills via **absolute paths under `~/.cursor/skills/`** (symlinks into the `ai_systems` clone per `CURSOR-SYMLINK-INTEGRATION.md`).

| Role | Open this file |
|------|----------------|
| Hub health (Quick / Standard / Deep) | `~/.cursor/skills/acm-hub-health-check/SKILL.md` |
| Cluster methodology (12-layer) | `~/.cursor/skills/acm-cluster-health/SKILL.md` |
| Post-diagnosis remediation | `~/.cursor/skills/acm-cluster-remediation/SKILL.md` |
| Jenkins pipelines / shared library | `~/.cursor/skills/jenkins-expert/SKILL.md` |
| ACM build tags / destroy runbooks | `~/.cursor/skills/acm-operations/SKILL.md` |

If `acm-hub-health-check` is missing, run the symlink steps in `CURSOR-SYMLINK-INTEGRATION.md`; otherwise `KNOWLEDGE_DIR` will not resolve.

## Portable paths (repo-local, non-Cursor contexts)

Relative to this skill directory (`acm-environment-finder/`):

| Goal | Open |
|------|------|
| Hub health after kubeconfig works | `../acm-hub-health-check/SKILL.md` |
| Jenkins (MCP or REST) | `../acm-jenkins-client/SKILL.md` |

**Note:** `acm-operations` and `jenkins-expert` exist only in Cursor (`~/.cursor/skills/`). For portable contexts use `pipeline-parameters.md`, `provisioning-pipelines.md`, and `jenkins-without-mcp.md` instead.

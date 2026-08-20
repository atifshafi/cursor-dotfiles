# Cursor skill paths (this machine)

`acm-environment-finder` delegates to other skills by **absolute paths under `~/.cursor/skills/`**. Those entries should be **symlinks into the `ai_systems` clone** so behavior matches the portable pack (see `ai_systems/.claude/skills/CURSOR-SYMLINK-INTEGRATION.md`).

| Role | Open this file |
|------|----------------|
| Hub health (Quick / Standard / Deep) | `~/.cursor/skills/acm-hub-health-check/SKILL.md` |
| Cluster methodology (12-layer) | `~/.cursor/skills/acm-cluster-health/SKILL.md` |
| Post-diagnosis remediation | `~/.cursor/skills/acm-cluster-remediation/SKILL.md` |
| Jenkins pipelines / shared library | `~/.cursor/skills/jenkins-expert/SKILL.md` |
| ACM build tags / destroy runbooks | `~/.cursor/skills/acm-operations/SKILL.md` |

If `acm-hub-health-check` is missing, run the symlink steps in `CURSOR-SYMLINK-INTEGRATION.md` in the repo; otherwise `KNOWLEDGE_DIR` will not resolve and hub diagnostics will be incomplete.

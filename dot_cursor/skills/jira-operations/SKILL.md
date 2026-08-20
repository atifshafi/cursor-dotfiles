---
name: jira-operations
description: Handle JIRA operations including creating bugs, tasks, stories, comments, and linking tickets. Use when user wants to create JIRA tickets, file bugs, add comments, link issues, or update ticket status. CRITICAL - never push JIRA changes without explicit user permission.
---

# JIRA Operations

JIRA write operations using the JIRA MCP server. Complements `active-sprint-tasks` (discovery) with write operations.

## MANDATORY: Gate Enforcement

**All JIRA write operations require explicit user permission. NON-NEGOTIABLE.**

1. **NEVER execute a JIRA write (create, update, comment, link, transition) without showing the user exactly what will be written and receiving explicit approval.**
2. **On skill start, create a TodoWrite** tracking: `gather-info | pending`, `propose-changes | pending`, `GATE: user-approval | pending`, `execute-writes | pending`.
3. **The `user-approval` todo CANNOT be marked completed by the agent.** Only when user explicitly approves.
4. **If user says "just do it"**, still show the proposal first.

## User Identity

- **JIRA Username:** rhn-support-ashafi
- **Display Name:** Atif Shafi
- **Primary Components:** Console, Container Native Virtualization
- **Work Type:** Always `10608` (Quality / Stability / Reliability)

## Ask Questions First

Before creating or modifying JIRA tickets, ask for missing information. Don't assume.

| Category | Ask |
|----------|-----|
| Issue Type | Bug, Task, Story, or Sub-task? |
| ACM Version | Which version? (e.g., 2.15.1, 2.16) |
| Component | Console, Search, CNV, etc.? |
| Priority | Minor, Major, Critical? |
| Assignee | Specific person or unassigned? |
| Related Tickets | Any related tickets to link? |
| Description | Steps to reproduce? (for bugs) |

When user describes the issue clearly, propose with defaults. When vague, ask first.

## Operation Dispatch

| Operation | Action |
|-----------|--------|
| Create Bug/Task/Story/Sub-task | Read `templates/issue-templates.md`, then propose using gate enforcement |
| Add Comment | Use `add_comment` (param is `comment`, NOT `body`). For comment templates, read `reference.md` |
| Link Issues | Use `link_issue`. Common types: Depend, Blocks, Related, Duplicate. For full link type IDs, read `reference.md` |
| Update Issue | Use `update_issue`. MUST include `priority`, `activity_type`, `due_date`, `components` (all required by MCP schema even for single-field updates) |
| Transition Status | Use `transition_issue`. Ensure `fix_version` set for transitions beyond In Progress |
| Search/Read | No permission needed. Use `get_issue`, `search_issues`, `search_users` |

## Shared Rules

**Time Tracking:** We do NOT use time-based tracking. Effort is measured ONLY via story points. The `create_issue` tool may default `original_estimate` to "1h" -- MUST pass `original_estimate=null` on every create to prevent bogus time tracking.

**Component Rules:**
- Bugs: single component only where bug manifests (UI bug in Search → `Console`)
- Features: can have multiple components (Fleet Virt → `Console`, `Container Native Virtualization`)

**Common Labels:** `QE` (QE work), `QE-Required` (story needs QE verification), `acmrbac` (RBAC UI)

## Story Points Sizing Guide

Source: [ACM QE Estimation Guide](https://docs.google.com/presentation/d/1mtUrS6gmuIIuAhZIASWkFCIAgzjstdx-BiTKUqka5h4/edit#slide=id.g26c770d619a_0_132)

| Points | Size | Complexity | Risk | Uncertainty | Effort |
|--------|------|------------|------|-------------|--------|
| **1** | XS | Extremely simple, minimal work | Low | None | Very little effort |
| **2** | S | Extremely simple, short AC | Low | None | Little effort |
| **3** | M | Simple, clear and manageable AC | Low | May consult peers | Some time |
| **5** | L | A few difficult aspects, mostly clear AC | Medium | May consult sources | Significant sprint time |
| **8** | XL | Difficult, lots of AC | High, needs mitigation | Borderline spike | Whole sprint |
| **13** | XXL | Too big -- break into sub-tasks | High | Team unsure, spike needed | More than one sprint |

- Stories and tasks: always assign story points
- Bugs and QE Bot-style tasks: do NOT assign story points
- Sub-tasks: do NOT assign story points (effort tracked on parent)
- 13+ points: recommend breaking into sub-tasks

## MCP Tools

| Tool | Purpose | Key Gotchas |
|------|---------|-------------|
| `create_issue` | Create bug/task/story | `original_estimate=null` always; `activity_type` by label or ID |
| `update_issue` | Update fields | `priority`, `activity_type`, `due_date`, `components` ALL required even for single-field updates |
| `add_comment` | Add comment | Parameter is `comment`, NOT `body` |
| `link_issue` | Link issues | `link_type` by name; `inward_issue` = from, `outward_issue` = to |
| `transition_issue` | Change status | `fix_version` must be set for transitions beyond In Progress |
| `log_time` | Log work | `time_spent` + `comment` |

Read ops (no permission): `get_issue`, `search_issues`, `search_users`, `get_link_types`, `get_project_components`. For full parameter details, read `reference.md`.

## Integration

| Skill | What it provides |
|-------|-----------------|
| `acm-operations` | Build tag for bug description `h4. Version-Release number` |
| `active-sprint-tasks` | Sprint name, discovery JQL, team roster, release milestones |
| `write-testcase-console` | Polarion test case IDs for QE task comments |

## Output Efficiency

When proposing a JIRA operation, use a compact `field: value` list. After executing, report only: ticket key, URL, and status.

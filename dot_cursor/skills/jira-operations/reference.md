# JIRA Operations Reference

Extended reference for JIRA operations.

## All Link Types

| ID | Name | Inward | Outward |
|----|------|--------|---------|
| 12311220 | Depend | is depended on by | depends on |
| 12310720 | Blocks | is blocked by | blocks |
| 12310001 | Related | is related to | relates to |
| 12310000 | Duplicate | is duplicated by | duplicates |
| 12310120 | Cloners | is cloned by | clones |
| 12310220 | Causality | is caused by | causes |
| 12310420 | Document | is documented by | documents |
| 10011 | Incorporates | is incorporated by | incorporates |
| 12311920 | Informs | is Informed by | informs |
| 12311720 | Issue split | split from | split to |
| 12310723 | Triggers | is triggered by | is triggering |

## Work Type IDs (Cloud - verified via MCP schema)

| ID | Name | When to Use |
|----|------|-------------|
| `10608` | Quality / Stability / Reliability | ALL QE work, bugs, testing, automation |
| `10610` | Product / Portfolio Work | New features (dev stories) |
| `10607` | Incidents & Support | Support cases |
| `10609` | Security & Compliance | Security issues |
| `10604` | Associate Wellness & Development | Training, personal development |
| `10605` | BU Features | Business unit feature work |
| `10606` | Future Sustainability | Long-term improvements |
| `-1` | None | |

## Priority Levels

| Priority | When to Use |
|----------|-------------|
| Blocker | Blocks release, no workaround |
| Critical | Severe issue, needs immediate attention |
| Major | Significant issue, high priority |
| Normal | Standard priority |
| Minor | Low impact, can wait |
| Undefined | Not yet triaged |

## ACM Project Components

Common components for ACM project:

- `Console` - Frontend UI
- `Search` - Search functionality
- `Container Native Virtualization` - CNV/MTV/Fleet Virt
- `Cluster Lifecycle` - Cluster management
- `Applications` - Application lifecycle
- `GRC` - Governance, Risk, Compliance
- `Observability` - Monitoring, metrics
- `Infrastructure` - Backend infrastructure

## Issue Status Transitions

Common transitions:

| From | To | Transition Name |
|------|-----|-----------------|
| New | In Progress | Start Progress |
| In Progress | Review | Submit for Review |
| Review | Closed | Close |
| Any | Closed | Close |
| Closed | Reopened | Reopen |

## JQL Quick Reference

**Find my open tasks:**
```jql
assignee = rhn-support-ashafi AND status NOT IN (Closed, Cancelled)
```

**Find current sprint tasks:**
```jql
assignee = rhn-support-ashafi AND sprint = "ACM Console Train XX - Y"
```

**Find QE tasks for a story:**
```jql
summary ~ "[QE] --- ACM-XXXXX"
```

**Find bugs I reported:**
```jql
reporter = rhn-support-ashafi AND type = Bug
```

**Find Console bugs:**
```jql
project = ACM AND type = Bug AND component = Console AND status != Closed
```

## Comment Formatting

JIRA uses wiki-style formatting:

| Format | Syntax |
|--------|--------|
| Bold | `*bold*` |
| Italic | `_italic_` |
| Header | `h1.`, `h2.`, `h3.`, `h4.` |
| Link | `[text\|url]` |
| User mention | `[~username]` |
| Code | `{code}...{code}` |
| Table | `\|\|header\|\|` and `\|cell\|` |
| Bullet list | `*` or `-` |
| Numbered list | `#` |
| Image | `!image.png!` or `!image.png\|width=500!` |

## QE Verification Comment Template

```
*QE Manual Verification - PASSED*

_Environment:_
- ACM: X.Y.Z-NNN (createdAt: YYYY-MM-DDTHH:MM:SSZ)
- OCP: X.Y.Z
- Hub: [cluster-name]

_Polarion Test Cases:_

||Polarion ID||Scope||Result||
|[RHACM4K-XXXXX|https://polarion.engineering.redhat.com/polarion/#/project/RHACM4K/workitem?id=RHACM4K-XXXXX]|[Description]|PASSED|

_Summary:_ [Brief summary of what was verified]
```

## Sprint Progress Comment Template

```
Automation work for this feature is in progress on *ACM Console Train XX - Y* sprint.
```

## Test Case Coverage Comment Template

```
Test case added here: [RHACM4K-XXXXX - [Title]|https://polarion.engineering.redhat.com/polarion/redirect/project/RHACM4K/workitem?id=RHACM4K-XXXXX]

[Additional notes if any]
```

## MCP Tool Gotchas

Non-obvious behavior not in the MCP schema (use `GetMcpTools` for full parameter details):

- **`update_issue`**: `priority`, `activity_type`, `due_date`, `components` are ALL required by MCP schema even for single-field updates
- **`add_comment`**: parameter is `comment`, NOT `body`; `security_level` defaults to "Red Hat Employee"
- **`link_issue`**: for "depends on" relationship, `inward_issue` = dependent, `outward_issue` = dependency
- **`transition_issue`**: transitions beyond 'New', 'Backlog', 'In Progress' require `fix_version` to be set first via `update_issue`
- **`search_users`**: use `name` field (not `account_id`) for assignee operations in self-hosted Jira
- **`create_issue`**: pass `original_estimate=null` to prevent bogus time tracking; `due_date` is optional

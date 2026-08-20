---
name: active-sprint-tasks
description: Manage active sprint work, scrum leader duties, team visibility, and release milestones. Use when user asks about sprint work, test cases, Polarion IDs, QE tasks, scrum leader prep, daily duties, team status, release milestones, or what they're working on.
---

# Active Sprint Tasks Intelligence

Multi-mode skill for sprint management across JIRA, Polarion, Google Workspace, and team coordination.

---

## Gate Enforcement

Read operations (sprint queries, coverage analysis, team status) are ungated. JIRA writes (comments, status changes) and Polarion writes (updates, creates) require explicit user permission. For bulk operations, show the full list and template before proceeding.

## Engram Integration

Recall before starting: `engram_recall("JIRA MCP usage patterns")`, `engram_recall("user profile sprint focus")`, `engram_recall("scrum leader duties ACM Console")`. After completing work, store findings with `engram_remember`.

## Ask Questions First

| # | Question |
|---|----------|
| 1 | Which ACM version/release? (e.g., 2.14, 2.15, 2.17) |
| 2 | Which sprint? Current, or a specific one? |
| 3 | Scope: your assigned tickets, or all Console/RBAC tickets? |
| 4 | Coverage type: QE task status, Polarion coverage, or both? |
| 5 | Ticket types: all, or specific (bugs, stories, tasks)? |

When user says "what am I working on?" or "my sprint tasks", calculate current sprint and proceed without asking. Only ask when intent is ambiguous.

---

## Mode Detection

Detect the mode from the user's query and load the appropriate reference files.

| User Intent | Mode | Files to Load |
|-------------|------|---------------|
| "What am I working on?", "my sprint tasks", "my tickets" | **IC Mode** | [reference.md](reference.md) |
| "Prep me for today's scrum", "scrum leader duties", "daily standup" | **Scrum Leader** | [scrum-leader.md](scrum-leader.md) + [team-roster.md](team-roster.md) |
| "QE coverage for 2.17", "which stories need test cases?", "coverage report" | **Coverage Analysis** | [reference.md](reference.md) + [release-tracker.md](release-tracker.md) |
| "Who's working on RBAC?", "team status", "who's out today?" | **Team View** | [team-roster.md](team-roster.md) |
| "Days until feature freeze?", "release status", "at-risk stories" | **Milestone View** | [release-tracker.md](release-tracker.md) |
| "Sprint retro prep", "sprint closure", "sprint statistics" | **Sprint Lifecycle** | [scrum-leader.md](scrum-leader.md) + [release-tracker.md](release-tracker.md) |

Default: IC Mode when intent is unclear. Multi-mode queries may need multiple files.

---

## User Identity

- **JIRA Username:** rhn-support-ashafi | **Display Name:** Atif Shafi
- **Polarion Project:** RHACM4K
- **Focus Areas:** ACM RBAC UI, Virtualization (CNV/MTV), Fleet Virtualization

## Work Area Filtering

**Component:** `Console` (frontend). Stories can have multiple components; if `Console` is NOT present, skip.

**Labels:** `acmrbac` (RBAC UI stories), `QE-Required` (on Stories/Epics -- requires QE verification), `QE` (on QE tracking tasks, NOT on Stories).

**Issue Hierarchy:** Epic (QE-Required, but NO direct QE tasks) → Story (QE-Required, spawns QE tasks) → [QE] Task / [QE Automation] Task (QE label). Focus QE coverage checks on Stories, not Epics.

**QE Task Naming:** `[QE] --- ACM-XXXXX: <Title>` (manual) or `[QE Automation] --- ACM-XXXXX: <Title>` (automation).

**Ignore:** type=Epic (no direct QE tasks), labels=QE-not-required or QE-NotApplicable, resolution="Won't Do", Console NOT in components.

## Relevance Check (Priority Order)

| Priority | Check | Applies To |
|----------|-------|------------|
| 1 | Assignee = rhn-support-ashafi | QE Tasks, Stories |
| 2 | QA Contact = rhn-support-ashafi | Stories |
| 3 | QE-Required label + Console or CNV component | Stories |
| 4 | Summary keywords: rbac, virtualization, fleet, cluster-proxy, vm | Fallback |

---

## Google Workspace Resources

| Resource | ID | Type |
|----------|-----|------|
| Console Scrum Doc | `19eucZSrN6-pAP2r2x9v-45-chZQAGE3eifvp6XSn55Q` | Doc |
| Scrum Doc Archive (pre-Mar 2026) | `19xagZUdVa8-vNtu5o-bbYUYyiP30ym2__y90apQ4Bgo` | Doc |
| Sprint Statistics | `1EVzerUYGh5RuaF982lM6GCAcZDgPhITbLYz3lV-8oPw` | Sheet |

Read docs via `get_doc_as_markdown`, sheets via `read_sheet_values`, calendar via `get_events`. User email: `ashafi@redhat.com`. Cursor indexed doc alternative: `@Docs Console scrum`.

**Key Meetings:** Daily Scrum 11:30 AM ET | Refinement Tue 11:30 AM ET (replaces daily) | Release Scrum Mon 9 AM ET | Sprint Planning last day 11:30 AM ET | Demo+Retro first day 11:30 AM ET | Dev Playback Tue 9 AM ET.

---

## Sprint Calculation

**Cadence:** 3-week sprints (changed from 2-week "Train" cadence on Mar 12, 2026).
**Anchor:** ACM Console 2.17 - 1 started Mar 12, 2026. Each sprint = 21 days.
**Formula:** `sprint_number = floor((today - Mar 12, 2026).days / 21) + 1`
**Sprint name:** `ACM Console {release} - {sprint_number}` (used in JIRA sprint field).
Sprint start = anchor + (sprint_number - 1) * 21 days. Sprint end = start + 20 days.

For milestone dates and countdown, load [release-tracker.md](release-tracker.md). For historical Train sprints (pre-Mar 2026), see [reference.md](reference.md).

---

## Output Efficiency

Present results as compact tables. Group tickets by type (Stories, QE Tasks, Automation Tasks). Use one-line summaries per ticket. For coverage reports, use the format in reference.md.

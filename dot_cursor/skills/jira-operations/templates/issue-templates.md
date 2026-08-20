# JIRA Issue Templates

All CREATE operation templates. Always pass `original_estimate=null`.

## Bugs

| Field | Value | Notes |
|-------|-------|-------|
| `issue_type` | "Bug" | |
| `project_key` | "ACM" | |
| `components` | Single component only | e.g., `["Console"]` -- don't add multiple |
| `assignee` | "Kevin Cormier" | Default for Console UI bugs |
| `activity_type` | "Quality / Stability / Reliability" | Label or ID "10608" |
| `priority` | "Minor" / "Major" / "Critical" | Based on severity |
| `due_date` | Optional | e.g., "2026-03-31" |
| `story_points` | OMIT | Bugs don't get story points |
| `original_estimate` | **null** | NEVER set |
| `labels` | `[]` | Usually empty |
| `fix_versions` | `[]` | Usually empty for new bugs |

**Bug Description Template:**
```
h4. Description of problem:
[Clear description of the issue]

h4. Version-Release number of selected component (if applicable):
ACM <version>-DOWNSTREAM-<YYYY-MM-DD-HH-MM-SS> (e.g., 2.16.0-DOWNSTREAM-2026-02-17-23-50-31)
[Get this from the cluster -- use the `acm-operations` skill, Operation 1]

h4. How reproducible:
Always / Sometimes / Rarely

h4. Steps to Reproduce:
# Step 1
# Step 2
# Step 3

h4. Actual results:
[What happens]

h4. Expected results:
[What should happen]

h4. Additional info:
[Related bugs, PRs, context]
```

## Regular Tasks

| Field | Value | Notes |
|-------|-------|-------|
| `issue_type` | "Task" | |
| `project_key` | "ACM" | |
| `summary` | Plain descriptive title | No prefix |
| `labels` | `["QE"]` | |
| `components` | `["Console"]` | Single or multiple |
| `fix_versions` | `["ACM 2.16.0"]` | Target release |
| `activity_type` | "Quality / Stability / Reliability" | Label or ID "10608" |
| `story_points` | Required | 1, 2, 3, 5 (see sizing guide) |
| `original_estimate` | **null** | NEVER set |
| `assignee` | "rhn-support-ashafi" | Self-assign |

## QE Bot-Style Tasks

| Field | Value | Notes |
|-------|-------|-------|
| `issue_type` | "Task" | |
| `summary` | `[QE Automation] --- ACM-XXXXX: Story Title` | Include parent story ID |
| `labels` | `["QE"]` | |
| `activity_type` | "Quality / Stability / Reliability" | Label or ID "10608" |
| `fix_versions` | Same as parent story | |
| `story_points` | OMIT | QE Bot tasks don't have points |
| `assignee` | "rhn-support-ashafi" | Self-assign |

## Stories

| Field | Value | Notes |
|-------|-------|-------|
| `issue_type` | "Story" | |
| `project_key` | "ACM" | |
| `summary` | Feature description | |
| `labels` | `["QE"]` | |
| `components` | `["Console"]` | Single or multiple |
| `fix_versions` | `["ACM 2.16.0"]` | Target release |
| `activity_type` | "Quality / Stability / Reliability" | Label or ID "10608" |
| `story_points` | Required | 1, 2, 3, 5, 8, 13 (see sizing guide) |
| `original_estimate` | **null** | NEVER set |

**Story Description Template:**
```
h2. *Value Statement*
[Explain WHY this story matters]

h2. *Definition of Done*
* [ ] [Deliverable 1]
* [ ] [Deliverable 2]

h3. *Development Complete*
* The code is complete.
* Functionality is working.
```

## Sub-tasks

| Field | Value | Notes |
|-------|-------|-------|
| `issue_type` | "Sub-task" | |
| `parent` | Parent task/story key | Required |
| `activity_type` | "Quality / Stability / Reliability" | |
| `components` | Match parent story | e.g., `["Console", "Container Native Virtualization"]` |
| `fix_versions` | Match parent story | |
| `priority` | Match parent story | |
| `story_points` | **OMIT** | Sub-tasks do NOT get story points (effort tracked on parent) |
| `original_estimate` | **null** | NEVER set |
| `assignee` | "rhn-support-ashafi" | Self-assign |

## Default Assignees

| Area | Default Assignee | API value |
|------|-----------------|-----------|
| Console UI bugs | Kevin Cormier | display name |
| QE tasks (self) | rhn-support-ashafi | username |

# Reference: Active Sprint Tasks Skill

---

## Sprint Structure

**Current cadence (since Mar 12, 2026):** 3-week release-based sprints. Each release cycle = 3 sprints (e.g., ACM Console 2.17 - 1/2/3). Feature Freeze at end of Sprint 2, Code Freeze at end of Sprint 3.

**Previous cadence (before Mar 12, 2026):** 2-week Train sprints (Train XX Sprint 1/2). Last train: Train-37 Sprint-2 ended Mar 11, 2026.

---

## JIRA Ticket Hierarchy

- **Epic** (Feature Container) -- Labels: QE-Required. NO direct QE tasks; only stories within epics have QE tasks.
- **Story** (Dev Work) -- Labels: QE-Required, Eng-Status:*. Components: Console, CNV, etc. Assignee: developer. QA Contact: QE engineer.
  - **[QE] Task** (Manual Testing) -- Title: `[QE] --- ACM-XXXXX: <Story Title>`. Labels: QE (NOT QE-Required). Reporter: ACM Bot (auto-created). Assignee: QA Contact from parent. Post QE verification comments and Polarion IDs here.
  - **[QE Automation] Task** (Automation) -- Title: `[QE Automation] --- ACM-XXXXX: <Story Title>`. Labels: QE. Link Polarion IDs when test cases are automated.

**Key Label Distinction:** `QE-Required` → on Stories/Epics (indicates QE work needed). `QE` → on QE Tasks (tracking label).

---

## JIRA Label Meanings

| Label | Applies To | Meaning | AI Action |
|-------|------------|---------|-----------|
| `Train-XX` | Stories, Tasks | Work belongs to Train XX (legacy, pre-Mar 2026) | Historical reference only |
| `QE` | Tasks only | QE tracking ticket | Post verification comments here |
| `QE-Required` | Stories, Epics | Story/Epic requires QE verification | Search for linked [QE] tasks |
| `QE-not-required` | Stories | Explicitly no QE needed | Skip when checking for gaps |
| `QE-NotApplicable` | Stories | QE not applicable | Skip when checking for gaps |
| `acmrbac` | Stories | RBAC-related UI work | User's primary focus area |
| `Eng-Status:Green` | Stories | Dev work on track | Informational only |
| `doc-not-required` | Stories | No doc changes needed | Informational only |

---

## Component Filtering (User: ashafi)

**Primary Component:** `Console` (frontend/UI). Component field can have MULTIPLE values.

| Components | Relevance |
|------------|-----------|
| `Console` only | Core frontend work |
| `Console` + `Container Native Virtualization` | Fleet Virt UI work |
| `Console` + `Search` | Search UI work |
| `Container Native Virtualization` only | Backend virt work (skip) |
| `Cluster Lifecycle` only | CLC backend work (skip) |

**Rule:** If `Console` is in components, it's relevant. Otherwise skip.

---

## JIRA MCP Tool Notes

### update_issue tool

**`activity_type` accepts labels (preferred) or numeric IDs:**
| Label | ID |
|-------|-----|
| Quality / Stability / Reliability | `10608` |
| Product / Portfolio Work | `10610` |
| Incidents & Support | `10607` |
| Security & Compliance | `10609` |
| BU Features | `10605` |
| Future Sustainability | `10606` |
| Associate Wellness & Development | `10604` |
| None | `-1` |

### add_comment tool

- Parameter is `comment`, NOT `body`
- Example: `{"issue_key": "ACM-29073", "comment": "Comment text here"}`

### get_issue and search_issues -- Issue Links

Both return an `issue_links` array. Each link has `type`, `direction`, `key`, and `summary` fields.

```json
"issue_links": [
  {"type": "Depend", "direction": "outward", "key": "ACM-30856", "summary": "[QE] --- ACM-30854: Remove PlacementRule from UI"},
  {"type": "Depend", "direction": "outward", "key": "ACM-30857", "summary": "[QE Automation] --- ACM-30854: Remove PlacementRule from UI"}
]
```

Find linked QE tasks directly from story response. Fallback (if links empty): `summary ~ "[QE] --- ACM-XXXXX"`.

---

## Polarion MCP Tool Reference

### User Permissions

Access: READ + WRITE. Project: RHACM4K only. Token expires: Jan 31, 2027. Cannot list all projects (403). Always use `project_id="RHACM4K"`.

### Available Tools (`user-polarion` MCP server)

**Read Tools:**

| Tool | Purpose | Key Parameters |
|------|---------|----------------|
| `check_polarion_status` | Verify authentication | None |
| `set_polarion_token` | Set/refresh auth token | `token` |
| `get_polarion_project` | Get project details | `project_id` |
| `get_polarion_work_items` | Search test cases | `project_id`, `query`, `limit` |
| `get_polarion_work_item` | Fetch single test case | `project_id`, `work_item_id`, `fields` |
| `get_polarion_work_items_details` | Batch fetch multiple | `project_id`, `work_item_ids` |
| `get_polarion_work_item_revisions` | Get revision history | `project_id`, `work_item_id` |
| `get_polarion_test_steps` | Fetch step text + expected results HTML | `project_id`, `work_item_id` |
| `get_polarion_test_case_summary` | Quick overview: title, setup, step count | `project_id`, `work_item_id` |
| `get_polarion_setup_html` | Get raw Setup section HTML | `project_id`, `work_item_id` |
| `list_polarion_test_runs` | List/filter test runs | `project_id` |
| `get_polarion_test_run_info` | Test run details + pass/fail/blocked stats | `project_id`, `test_run_id` |
| `list_polarion_plans` | List/search test plans | `project_id` |

**Write Tools (REQUIRE PERMISSION):**

| Tool | Purpose | Key Parameters |
|------|---------|----------------|
| `update_polarion_work_item` | Update title, description, status, setup, custom fields | `project_id`, `work_item_id` |
| `update_polarion_setup` | Push setup section HTML | `project_id`, `work_item_id` |
| `update_polarion_test_steps` | Create or PATCH test steps in-place | `project_id`, `work_item_id` |
| `create_polarion_test_run` | Create test run + associate with plan | `project_id` |
| `upload_polarion_test_results` | Upload passed/failed/blocked results | `project_id`, `test_run_id` |

**Tools with Issues:** `get_polarion_projects` (403), `get_polarion_work_item_text` (returns empty), `get_polarion_document` (needs space_id).

### Searchable Fields (Lucene query syntax)

| UI Label | Query Field | Example Values |
|----------|-------------|----------------|
| Type | `type` | `testcase`, `requirement` |
| Status | `status` | `proposed`, `approved`, `inactive` |
| Level | `caselevel` | `system`, `integration`, `component` |
| Component | `casecomponent` | `virtualization`, `Cluster Lifecycle` |
| Test Type | `testtype` | `functional`, `nonfunctional` |
| Subtype 1 | `subtype1` | `system`, `-` |
| Pos/Neg | `caseposneg` | `positive`, `negative` |
| Importance | `caseimportance` | `critical`, `high`, `medium`, `low` |
| Automation | `caseautomation` | `notautomated`, `automated`, `manualonly` |
| Author | `author.id` | `ashafi` |
| Title | `title` | `"RBAC UI"`, `"[FG-RBAC-2.16]"` |
| Description | `description` | `RBAC`, `migration` |
| Product | `product` | `rhacm2-16`, `rhacm2-15` |

**Non-searchable:** `subcomponent`, `tags`.

**Default Filters:** `author.id:ashafi`, `casecomponent:virtualization` (or `"Cluster Lifecycle"`), `type:testcase`.

**Query Examples:**
```lucene
type:testcase AND author.id:ashafi AND casecomponent:virtualization
type:testcase AND author.id:ashafi AND caseautomation:notautomated
type:testcase AND title:"[FG-RBAC-2.16]"
type:testcase AND product:rhacm2-16 AND status:proposed
```

### Batch Fetch

`get_polarion_work_items_details` -- `work_item_ids` is a **comma-separated STRING**, not an array.
Correct: `"RHACM4K-61726,RHACM4K-61727"`. Wrong: `["RHACM4K-61726", "RHACM4K-61727"]`.

---

## Polarion Integration Patterns

### Extracting Polarion IDs from JIRA Comments

Scan JIRA ticket comments for regex pattern `RHACM4K-\d+`. Collect all matches as a set. If IDs found, use `get_polarion_work_items_details` to verify they exist. If no IDs found, flag as "needs test cases".

### Completed Polarion Test Cases (RBAC UI)

| Polarion ID | Scope Type |
|-------------|------------|
| RHACM4K-61726 | Global Access |
| RHACM4K-61727 | Single Cluster Set - Full Access |
| RHACM4K-61728 | Single Cluster Set - Project Access |
| RHACM4K-61729 | Multiple Cluster Sets - Full Access |
| RHACM4K-61730 | Multiple Cluster Sets - Project Access |
| RHACM4K-61731 | Single Cluster - Full Access |
| RHACM4K-61732 | Single Cluster - Project Access |
| RHACM4K-61733 | Multiple Clusters - Full Access |
| RHACM4K-61734 | Multiple Clusters - Project Access |
| RHACM4K-61735 | Empty Cluster Set (Edge Case) |
| RHACM4K-61736 | Common Projects (Edge Case) |
| RHACM4K-61779 | Validate Roles Page |
| RHACM4K-61797 | Pre-Authorized User |

---

## Historical Sprint Dates (Pre-Mar 2026)

For historical queries against pre-March 2026 sprints:
- Train-36 Sprint-1: Jan 15 - Jan 28, 2026
- Train-36 Sprint-2: Jan 29 - Feb 11, 2026
- Train-37 Sprint-1: Feb 12 - Feb 25, 2026
- Train-37 Sprint-2: Feb 26 - Mar 11, 2026

---

## JQL Query Templates

All templates use release-based sprint naming. Replace `{N}` with the sprint number from the SKILL.md calculation formula.

### My Assigned Work

**My Current Sprint Work:**
```
assignee = rhn-support-ashafi AND sprint = "ACM Console 2.17 - {N}"
```

**All My QE Tasks:**
```
labels = QE AND assignee = rhn-support-ashafi
```

**QE Tasks for Current Release:**
```
labels = QE AND assignee = rhn-support-ashafi AND fixVersion = "ACM 2.17.0"
```

**My Next Sprint Backlog:**
```
assignee = rhn-support-ashafi AND sprint = "ACM Console 2.17 - {N+1}"
```

**All Issues Assigned to Me (current release, open):**
```
project = ACM AND fixVersion = "ACM 2.17.0"
AND assignee = rhn-support-ashafi
AND status NOT IN (Cancelled, "Won't Do", Closed)
```

**Stories Where I'm QA Contact:**
```
project = ACM AND fixVersion = "ACM 2.17.0" AND type = Story
AND "QA Contact" = "rhn-support-ashafi" AND labels = "QE-Required"
AND status NOT IN (Cancelled, "Won't Do")
```

**Combined (Assignee OR QA Contact):**
```
project = ACM AND fixVersion = "ACM 2.17.0"
AND (assignee = rhn-support-ashafi OR "QA Contact" = "rhn-support-ashafi")
AND status NOT IN (Cancelled, "Won't Do")
```

### Discovering Potential Work (Console Component)

**Console Stories with QE-Required (User's Area):**
```
project = ACM AND fixVersion = "ACM 2.17.0" AND type = Story
AND component = Console AND labels = "QE-Required"
AND status NOT IN (Cancelled, "Won't Do")
```

**RBAC UI Stories Specifically:**
```
project = ACM AND fixVersion = "ACM 2.17.0" AND type = Story
AND component = Console AND labels = acmrbac
AND status NOT IN (Cancelled, "Won't Do")
```

**Console Stories that Might Need QE (Not Yet Labeled):**
```
project = ACM AND fixVersion = "ACM 2.17.0" AND type = Story
AND component = Console
AND (summary ~ "RBAC" OR summary ~ "virtualization" OR summary ~ "Fleet")
AND NOT labels = "QE-NotApplicable"
AND status NOT IN (Cancelled, "Won't Do")
```

### Finding Linked QE Tasks

**Find QE Task for Specific Story:**
```
summary ~ "[QE] --- ACM-XXXXX"
```

**Find Automation Task for Specific Story:**
```
summary ~ "[QE Automation] --- ACM-XXXXX"
```

**Find All QE Tasks for Multiple Stories (batch):**
```
summary ~ "[QE] --- ACM-29078" OR summary ~ "[QE] --- ACM-28836" OR summary ~ "[QE] --- ACM-28819"
```

### Gap Analysis

**Unassigned QE Tasks for Current Release:**
```
labels = QE AND fixVersion = "ACM 2.17.0" AND assignee is EMPTY AND component = Console
```

**QE Tasks in New Status (Not Started):**
```
labels = QE AND fixVersion = "ACM 2.17.0" AND status = New AND component = Console
```

**Stories with QE-Required -- Check if QE Task Exists:**
Step 1: Get stories with `project = ACM AND fixVersion = "ACM 2.17.0" AND type = Story AND component = Console AND labels = "QE-Required"`.
Step 2: For each story ACM-XXXXX, search `summary ~ "[QE] --- ACM-XXXXX"`. If no results, story is missing QE task.

---

## Discovery Steps: Finding and Checking QE Tasks

### Step 1: Find Linked QE Task for a Story

Try issue links first: check `issue_links` array from `get_issue` for `[QE]` or `[QE Automation]` prefixed summaries.

Fallback (if links empty): search `summary ~ "[QE] --- ACM-XXXXX"`. Filter results by checking if summary starts with `[QE]` or `[QE Automation]` prefix.

### Step 2: Check Polarion Coverage in QE Task

1. Fetch QE task with `get_issue`
2. Scan comments for `RHACM4K-\d+` pattern
3. If Polarion IDs found → has test case coverage
4. If no Polarion IDs → may need test cases

### Output Categories

- **COVERED:** Story has QE task + Polarion test cases linked → no action needed
- **IN PROGRESS:** Story has QE task, work ongoing → monitor
- **NEEDS TEST CASES:** Story has QE task but no Polarion IDs → create test cases
- **MISSING QE TASK:** Story has QE-Required but no [QE] task → investigate gap

---

## Coverage Report Format

Report test case coverage as a table: Sprint name, Assignee, then sections for "Has Test Cases" (JIRA Ticket | Title | Polarion IDs), "Needs Test Cases" (JIRA Ticket | Title | Type), and Summary (total QE tasks, count with/without test cases, percentage).

---

## Workflow Recipes

### "What am I working on?"
1. Calculate current sprint → run JQL: `assignee = rhn-support-ashafi AND sprint = "ACM Console {ver} - {N}"`
2. Also check QE backlog: `labels = QE AND assignee = rhn-support-ashafi`
3. Group results by: Stories, QE Tasks, Automation Tasks. Present with ticket links.

### "Which tickets need test cases?"
1. Get QE/Automation tasks for user → fetch each with `get_issue`
2. Scan comments for `RHACM4K-\d+` pattern → categorize "has" vs "needs" → generate coverage report

### "Find test cases for ACM-XXXXX"
1. Fetch ticket with `get_issue` → extract Polarion IDs from comments → optionally verify in Polarion with `get_polarion_work_items_details`

### "Verify test case RHACM4K-XXXXX"
Use `get_polarion_work_item(project_id="RHACM4K", work_item_id="RHACM4K-XXXXX")`. Returns title, type, status.

### "Add QE verification comment"
Identify the `[QE]` prefixed task (not parent story). Use `add_comment` with parameter `comment`. Include Polarion test case IDs if available.

---

## Troubleshooting

### Polarion Authentication

| Error | Fix |
|-------|-----|
| 401 Unauthorized | Run `set_polarion_token` with new PAT |
| 403 on `get_polarion_projects` | Normal -- use `project_id="RHACM4K"` directly |
| 403 on work item | Request project access or use RHACM4K |
| Empty from `get_polarion_work_item_text` | Use `get_polarion_work_item` with `fields="@all"` instead |
| Connection timeout | Verify Red Hat VPN is connected |

**Token refresh:** 1. `check_polarion_status` → 2. If invalid, `set_polarion_token(token=NEW_PAT)` → 3. Verify with `get_polarion_project(project_id="RHACM4K")`.

### JIRA Authentication

| Error | Fix |
|-------|-----|
| 401 Unauthorized | User must regenerate API token |
| 403 Forbidden | Request project access |
| "Issue not found" | Verify ticket key exists |

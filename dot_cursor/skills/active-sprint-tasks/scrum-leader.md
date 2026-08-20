# Scrum Leader Reference -- ACM Console Squad

---

## Daily Duty Map

Each day of the week has specific scrum leader responsibilities. Use the day of the week to determine what to prepare.

### Monday

| Duty | Details |
|------|---------|
| **ACM Release Scrum** | 9:00 AM ET. Report overall squad color status. Bring back announcements. |
| **Status Updates** | Facilitate updates on the Console scrum Google Doc. Each member posts what they're working on. |
| **ACM New Issue Triage** | Open the Kanban board, filter by type = Bug. Review Untriaged items, assign or move to correct status. |

### Tuesday

| Duty | Details |
|------|---------|
| **Board Review** | Navigate to the Scrum board. Walk through in-progress stories, ask for blockers, seek updated status. |
| **Console Refinement** | Facilitate planning poker for unpointed stories/tasks. Prepare unpointed items filter beforehand. |

### Wednesday

| Duty | Details |
|------|---------|
| **Status Updates** | Facilitate updates on the Console scrum Google Doc. |
| **ACM New Issue Triage** | Kanban board triage (same as Monday). |

### Thursday

| Duty | Details |
|------|---------|
| **Board Review with Icebreaker** | Start with an icebreaker, then walk through the Scrum board. |
| **Color Status Review** | Go through every in-flight story and parent epic. Ensure Eng-Status, QE-Confidence, and Color Status labels are added/updated. |
| **Demos** | Ask if anyone has work to demo. Allocate time during the meeting. |

### Friday

| Duty | Details |
|------|---------|
| **Virtual Status Updates** | Lighter day. Async updates on Slack or a brief sync call. |

---

## Key Links

### Jira Boards

| Board | URL | Use |
|-------|-----|-----|
| **Scrum Board** | https://redhat.atlassian.net/jira/software/c/projects/ACM/boards/2706 | Board Review (Tue/Thu), Sprint Planning |
| **Scrum Board Backlog** | https://redhat.atlassian.net/jira/software/c/projects/ACM/boards/2706/backlog | Sprint Planning (last day) |
| **Kanban Board** | https://redhat.atlassian.net/jira/software/c/projects/ACM/boards/2694 | New Issue Triage (Mon/Wed), filter by Bug |

### Google Documents

| Document | ID | Use |
|----------|-----|-----|
| **ACM Console Team Scrum** | `19eucZSrN6-pAP2r2x9v-45-chZQAGE3eifvp6XSn55Q` | Daily status updates, announcements, parking lot |
| **Scrum Leader Duties** | `1Zas296Ph83o2okcly3-DyqaSUQ4Tov-4xwPdaiyrL6Y` | Reference for scrum leader responsibilities |
| **Sprint Retrospectives** | `1-kTpHyAG7rgTlqd-wYJ282-3ITdmDkdmhe2g5akpN5o` | Velocity history, demos, retro boards |
| **Long-Term Roles** | `1RUNZTEc9zOPvIbjIadQ73tJAxsBKTeFYtqgu3l66FzM` | Feature leads, focal roles, team structure |
| **Sprint Statistics** | `1EVzerUYGh5RuaF982lM6GCAcZDgPhITbLYz3lV-8oPw` | Velocity tracking spreadsheet (Google Sheets) |

---

## Scrum Facilitation -- Pre-Scrum Context

Before each scrum, gather context from these sources:
1. Read the Console Scrum Doc via `get_doc_as_markdown` (doc ID in SKILL.md Google Workspace Resources table)
2. Check today's calendar via `get_events` for the current day
3. Check team member availability in [team-roster.md](team-roster.md) -- PTO, country holidays

---

## Board Review Protocol (Tuesdays, Thursdays)

1. Navigate to the Scrum board in Jira
2. Walk through stories in order of status columns (typically: In Progress -> In Review -> Done)
3. For each in-progress story, ask:
   - "Any blockers?"
   - "Expected completion date?"
   - "Does the color status need updating?"
4. When a story crosses into a new sprint, request an updated Eng-Status label
5. Flag stories that have been in the same status for more than a week

---

## New Issue Triage Protocol (Mondays, Wednesdays)

1. Navigate to the Kanban board in Jira
2. Filter by `type = Bug`
3. For each Untriaged bug:
   - Read the summary and description
   - Determine if it's a Console team issue (check component field)
   - Ask team for triage input if needed
   - Move to appropriate status: Triaged, Backlog, or assign to sprint
4. Check for bugs that have been Untriaged for more than 3 days

---

## Color Status Review (Thursdays)

Check every Console story in the current release for required labels.

**JQL to find Console stories for current release:**
```jql
project = ACM AND fixVersion = "ACM 2.17.0" AND type = Story 
AND component = Console AND status NOT IN (Cancelled, "Won't Do", Closed)
```

**For each story, verify:**
- `Eng-Status:Green` / `Eng-Status:Yellow` / `Eng-Status:Red` label exists
- `QE-Confidence:Green` / `QE-Confidence:Yellow` / `QE-Confidence:Red` label exists (for stories with QE-Required)

**For each parent epic, verify:**
- Color Status label is updated to reflect child story statuses
- If any child is Red, epic should reflect that

**JQL for stories missing Eng-Status:**
```jql
project = ACM AND fixVersion = "ACM 2.17.0" AND type = Story AND component = Console
AND status NOT IN (Cancelled, "Won't Do", Closed)
AND NOT labels IN ("Eng-Status:Green", "Eng-Status:Yellow", "Eng-Status:Red")
```

---

## Refinement Facilitation (Tuesdays)

**Before the meeting:**

1. Filter Jira for unpointed stories:
```jql
project = ACM AND fixVersion = "ACM 2.17.0" AND type IN (Story, Task) 
AND component = Console AND "Story Points" IS EMPTY 
AND status NOT IN (Cancelled, "Won't Do")
```

2. Review incoming epics/stories from product management
3. Prepare the list of items for planning poker

**During the meeting:**
- Present each story for discussion
- Run planning poker (everyone votes, discuss outliers, converge)
- Assign agreed story points
- Confirm prioritization with squad leader (Kevin)

---

## Release Scrum Reporting (Mondays, 9 AM ET)

The ACM Release Scrum is a cross-team meeting. As Console scrum leader, report:

**Template:**
```
Console Squad Status:
- Overall: [Green/Yellow/Red]
- Stories in flight: [count]
- At-risk stories: [list any Yellow/Red stories with brief reason]
- Blockers: [any cross-team blockers]
- Days until Feature Freeze: [count]
```

**Preparation:**
1. Run the color status JQL queries (see release-tracker.md)
2. Count stories by Eng-Status color
3. Note any blockers raised in daily scrums during the week
4. Check milestone countdown

---

## Sprint Lifecycle

### Sprint Day 1 (Thursday) -- Retrospective

The **previous sprint's scrum leader** runs the retrospective. If you are the new scrum leader:
- Attend and participate
- Note action items from the retro
- Take over facilitation duties after the retro meeting ends

The retrospective includes:
1. Review sprint statistics (velocity, completion %)
2. Demos from team members
3. Retrospective brainstorming (what went well, what didn't, action items)

### Mid-Sprint Checkpoint

Around the midpoint of the sprint (end of week 1 or start of week 2 in a 3-week sprint):
- Review at-risk stories (use release-tracker.md JQL queries)
- Verify color statuses are current
- Flag any stories that need attention to Kevin/PM
- Remind team of upcoming milestone deadlines

### Sprint Last Day (Wednesday) -- Sprint Planning

**Kevin (squad leader) facilitates sprint planning.** As scrum leader, assist by:
1. Navigate to the backlog in Jira
2. Help assign stories to the new sprint based on priorities
3. Ensure all Eng-Status and QE-Confidence labels are finalized
4. Confirm the sprint scope with Kevin

### Post-Sprint -- Retrospective Preparation

As the scrum leader for the ending sprint, **you run the retrospective** on the first day of the next sprint. Prepare:

**Checklist:**
- [ ] Move unfinished items from current sprint to next sprint in Jira
- [ ] Close the sprint in Jira (move non-Closed items to Backlog)
- [ ] Record statistics in the Sprint Statistics spreadsheet (use "Sprint Stats > Add Sprint Data" menu)
- [ ] Prepare retrospective board (what went well, what didn't, action items)
- [ ] Collect demos -- ask team the day before if anyone wants to demo
- [ ] Prepare an icebreaker for the retro meeting
- [ ] Review sprint statistics to present to the team

**Sprint Statistics:** Read via `read_sheet_values` (spreadsheet ID in SKILL.md Google Workspace Resources table, range `A1:Z50`).
**Sprint Retrospectives doc:** Read via `get_doc_as_markdown` (doc ID: `1-kTpHyAG7rgTlqd-wYJ282-3ITdmDkdmhe2g5akpN5o`).

---

## Icebreaker Management (Thursdays)

Prepare an icebreaker for each Thursday scrum. Keep them light and quick (1-2 minutes).

**Past icebreakers from the team (for inspiration):**
- "What is the most useless piece of information you have stored in your brain?"
- Library barcode memories, Spongebob meme palaces, Sims cheat codes, local business jingles, floppy disk memories

**Good icebreaker categories:**
- "What's the most [adjective] thing you [verb]?"
- "If you could [hypothetical], what would you choose?"
- Would-you-rather questions
- This-or-that quick picks
- "What's your go-to [category]?" (snack, song, movie, etc.)

---

## Cross-Team Meetings

Meetings the scrum leader should be aware of (not all require attendance):

| Meeting | Day/Time | Attendance | Purpose |
|---------|----------|------------|---------|
| ACM Release Scrum | Monday, 9 AM ET | **Required** (scrum leader) | Report squad color status |
| ACM Console Team Scrum | Daily, 11:30 AM ET | **Required** | Daily standup |
| ACM Console Refinement | Tuesday, 11:30 AM ET | **Required** (facilitator) | Planning poker, story pointing |
| ACM Console Sprint Planning | Last Wed, 11:30 AM ET | **Required** | Kevin facilitates, assist |
| ACM Console Sprint Demo + Retro | First Thu, 11:30 AM ET | **Required** | Outgoing leader runs retro |
| ACM Development Playback | Tuesday, 9 AM ET | Recommended | Cross-team updates |
| ACM Console Interlock | Periodic | Recommended | Cross-team alignment |
| ACM Quality Guild | Bi-weekly Tuesday | Optional (QE focal) | Quality discussions |
| ACM UI Guild | Periodic Wednesday | Optional | UI patterns, components |
| ACM Security Guild | Bi-weekly Wednesday | Optional (Kevin's focal) | Security updates |
| Doc Guild | Last Wed of month | Optional (Feng's focal) | Documentation coordination |

**Calendar check:** Use `get_events` with week's date range to verify meeting schedule.

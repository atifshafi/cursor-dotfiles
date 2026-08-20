# Release Tracker -- ACM Console

Read this file for release milestone tracking, countdown calculations, at-risk story detection, and color status rollup queries.

---

## ACM 2.17 Timeline

| Milestone | Date | Sprint | Status |
|-----------|------|--------|--------|
| Sprint 1 Start | Mar 12, 2026 | ACM Console 2.17 - 1 | Completed |
| Sprint 1 End | Apr 1, 2026 | ACM Console 2.17 - 1 | Completed |
| Sprint 2 Start | Apr 2, 2026 | ACM Console 2.17 - 2 | |
| **Feature Freeze** | **Apr 22, 2026** | End of Sprint 2 | |
| Sprint 3 Start | Apr 23, 2026 | ACM Console 2.17 - 3 | |
| **Code Freeze** | **May 13, 2026** | End of Sprint 3 | |
| MCE 2.17 GA | May 27, 2026 | Post-sprint | |
| **ACM 2.17 GA** | **Jun 3, 2026** | Post-sprint | |

---

## Dynamic Milestone Countdown

Calculate days until each milestone from the current date.

```python
from datetime import date

today = date.today()

milestones = {
    "Feature Freeze": date(2026, 4, 22),
    "Code Freeze": date(2026, 5, 13),
    "MCE 2.17 GA": date(2026, 5, 27),
    "ACM 2.17 GA": date(2026, 6, 3),
}

for name, target in milestones.items():
    days_until = (target - today).days
    if days_until > 0:
        print(f"{name}: {days_until} days remaining")
    elif days_until == 0:
        print(f"{name}: TODAY")
    else:
        print(f"{name}: passed {abs(days_until)} days ago")
```

**Milestone urgency thresholds:**
- 14+ days: Normal -- no special action needed
- 7-13 days: Attention -- actively track at-risk stories
- 1-6 days: Urgent -- all stories must have final status, flag any not on track
- 0 days: Deadline -- all feature work must be code-complete (for FF) or all bugs fixed (for CF)

---

## Sprint-to-Milestone Mapping

| Sprint | Dates | Milestones During Sprint | Scrum Leader Focus |
|--------|-------|--------------------------|-------------------|
| 2.17 - 1 | Mar 12 - Apr 1 | None | Normal sprint work |
| 2.17 - 2 | Apr 2 - Apr 22 | Feature Freeze (last day) | Push for code completion, finalize labels |
| 2.17 - 3 | Apr 23 - May 13 | Code Freeze (last day) | Bug fixes only, no new features |

---

## At-Risk Story Detection

### Stories Missing Green Eng-Status (approaching FF/CF)

```jql
project = ACM AND fixVersion = "ACM 2.17.0" AND type = Story 
AND component = Console 
AND status NOT IN (Closed, Cancelled, "Won't Do")
AND NOT labels = "Eng-Status:Green"
```

### Stories Still In Progress Past Feature Freeze

```jql
project = ACM AND fixVersion = "ACM 2.17.0" AND type = Story 
AND component = Console 
AND status IN ("In Progress", "To Do", New)
```

### Stories Without Any Eng-Status Label

```jql
project = ACM AND fixVersion = "ACM 2.17.0" AND type = Story 
AND component = Console 
AND status NOT IN (Closed, Cancelled, "Won't Do")
AND NOT labels IN ("Eng-Status:Green", "Eng-Status:Yellow", "Eng-Status:Red")
```

---

## Color Status Rollup Queries

Use these to generate a summary report of story statuses for release scrum reporting.

### Eng-Status Distribution

**Green (on track):**
```jql
project = ACM AND fixVersion = "ACM 2.17.0" AND type = Story 
AND component = Console AND labels = "Eng-Status:Green"
AND status NOT IN (Cancelled, "Won't Do")
```

**Yellow (at risk):**
```jql
project = ACM AND fixVersion = "ACM 2.17.0" AND type = Story 
AND component = Console AND labels = "Eng-Status:Yellow"
AND status NOT IN (Cancelled, "Won't Do")
```

**Red (blocked/behind):**
```jql
project = ACM AND fixVersion = "ACM 2.17.0" AND type = Story 
AND component = Console AND labels = "Eng-Status:Red"
AND status NOT IN (Cancelled, "Won't Do")
```

**Missing (no label):**
```jql
project = ACM AND fixVersion = "ACM 2.17.0" AND type = Story 
AND component = Console 
AND status NOT IN (Closed, Cancelled, "Won't Do")
AND NOT labels IN ("Eng-Status:Green", "Eng-Status:Yellow", "Eng-Status:Red")
```

### QE-Confidence Distribution

**Green (QE on track):**
```jql
project = ACM AND fixVersion = "ACM 2.17.0" AND type = Story 
AND component = Console AND labels = "QE-Required" AND labels = "QE-Confidence:Green"
AND status NOT IN (Cancelled, "Won't Do")
```

**Yellow (QE at risk):**
```jql
project = ACM AND fixVersion = "ACM 2.17.0" AND type = Story 
AND component = Console AND labels = "QE-Required" AND labels = "QE-Confidence:Yellow"
AND status NOT IN (Cancelled, "Won't Do")
```

**Red (QE behind):**
```jql
project = ACM AND fixVersion = "ACM 2.17.0" AND type = Story 
AND component = Console AND labels = "QE-Required" AND labels = "QE-Confidence:Red"
AND status NOT IN (Cancelled, "Won't Do")
```

---

## Release Scrum Report Template

Generate this report for the Monday ACM Release Scrum:

```
## ACM Console Squad - Release Status

**Sprint:** ACM Console 2.17 - {N}
**Days until Feature Freeze:** {countdown}

### Eng-Status Summary
- Green: {count} stories
- Yellow: {count} stories
- Red: {count} stories
- Missing status: {count} stories

### QE-Confidence Summary
- Green: {count} stories
- Yellow: {count} stories  
- Red: {count} stories

### At-Risk Stories
| Story | Summary | Status | Issue |
|-------|---------|--------|-------|
| ACM-XXXXX | ... | Yellow | PR review pending |

### Blockers
- [list any cross-team blockers]

### Notes
- [any important updates for the release team]
```

---

## Previous Releases (Reference)

### ACM 2.16 (Completed)

| Milestone | Date | Status |
|-----------|------|--------|
| Feature Freeze | Jan 28, 2026 | Completed |
| Code Freeze | Feb 11, 2026 | Completed |
| Docs Freeze | Feb 13, 2026 | Completed |
| GA | Mar 11, 2026 | Completed |

---

## Updating for Future Releases

When ACM 2.18 begins, update this file:

1. Move ACM 2.17 to the "Previous Releases" section
2. Add ACM 2.18 Timeline with new milestone dates
3. Update the Python countdown formula with new dates
4. Update Sprint-to-Milestone mapping with new sprint numbers
5. Update all JQL queries from `"ACM 2.17.0"` to `"ACM 2.18.0"`
6. Update the sprint calculation anchor in SKILL.md if the cadence changes

# Team Roster -- ACM Console Squad

Read this file for team member details, roles, focus areas, availability, and holiday awareness.

---

## Team Members

| Name | Role | Country | Timezone |
|------|------|---------|----------|
| Kevin Cormier | Team Lead / Architect, Dev | Canada | ET |
| Randy | Dev | US | ET |
| Zack | Dev | US | ET |
| Feng | Dev | -- | -- |
| John | Dev | US | ET |
| Oksana Bazylieva | Dev | Spain | CET |
| Kike | Dev | Spain | CET |
| David Huynh | QE | -- | -- |
| Almen Ng | QE | Canada | ET |
| Atif Shafi | QE (SDET) | Canada | ET |

---

## Feature Leads

Feature leads are the subject matter experts for specific areas of console functionality.

| Feature Lead | Focus Areas | Jira Components | Backend Team | Backend PM | Backend Lead |
|-------------|-------------|-----------------|--------------|------------|-------------|
| Kevin | RBAC, multicluster SDK, other | Console, Console-CNV | Workloads, CNV, OCP | Christian Stark | Roke Jung (Virt), Yang Le (SF) |
| Randy | Governance, Hypershift | Console-GRC, Console-HCP | Governance, Hypershift | Christian Stark | Justin Kulikauskas (Gov), Roke Jung (HCP) |
| Zack | Search | Console-Search | Applications | Sho Weimer | Jorge Padilla |
| Feng | Application Lifecycle, Cluster Lifecycle, Discovery | Console-ALC, Console-CLC | Applications, Installer | Christian Stark, Bradd Weidenbenner | Xiangjing Li |

---

## QE Focals

| QE Focal | Focus Areas | Jira Components | Feature Leads |
|----------|-------------|-----------------|---------------|
| Atif Shafi | RBAC UI, Virtualization (CNV/MTV), Fleet Virt | Console, Console-CNV | Kevin |
| David Huynh | GRC, Hypershift, Topology, Column Management | Console-GRC, Console-HCP, Console-CLC | Randy, Kevin |
| Almen Ng | ALC, CLC, Wizard stories | Console-ALC, Console-CLC | Feng |

---

## Focal Roles (Cross-Cutting)

| Role | Owner | Cadence | Key Duties |
|------|-------|---------|------------|
| Infrastructure | Zack | Variable (5 min - 4 hrs/week) | Weekly cluster health, ClusterPools, troubleshooting |
| Security | Kevin | ~30 min/week + end of release | ACM Security Guild (bi-weekly Wed), CVE handling |
| Build and Release | Randy | ~30 min/week + ~2 days at release end | Konflux update PRs, pipeline failures, release cutover |
| Translation | John | ~1 day spread over last few weeks of release | Submit strings for translation, review translated strings |
| Documentation | Feng | 45 min/month + 2 days at release end | Doc Guild (last Wed of month), broken link checks |
| Quality | Vacant | -- | Quality Guild attendance, testing improvements |

---

## Documentation Focals (External)

| Area | Documentation Focal |
|------|-------------------|
| RBAC, Virtualization | Mikela Jackson |
| Governance | Jake Berger (TBD) |
| Search | Mikela Jackson |
| Application | Jake Berger (TBD) |
| Cluster | Oliver Fischer |

---

## Known Long-Term Absences

| Person | Type | Period | Coverage |
|--------|------|--------|----------|
| Kike | Paternity leave | Mar 30, 2026 - Jul 22, 2026 | Oksana covering some RBAC dev work; ticket ACM-30854 needs coverage |

Update this table as team member availability changes.

---

## Country Holiday Reference

Use this to anticipate reduced attendance during scrums.

### Canada

| Holiday | Typical Date |
|---------|-------------|
| Good Friday | Friday before Easter |
| Easter Monday | Monday after Easter |
| Victoria Day | Monday before May 25 |
| Canada Day | Jul 1 |
| Civic Holiday | First Monday of August |
| Labour Day | First Monday of September |
| Thanksgiving | Second Monday of October |
| Christmas Day | Dec 25 |
| Boxing Day | Dec 26 |

**Canadian team members:** Kevin, Almen, Atif

### United States

| Holiday | Typical Date |
|---------|-------------|
| MLK Day | Third Monday of January |
| Presidents Day | Third Monday of February |
| Memorial Day | Last Monday of May |
| Independence Day | Jul 4 |
| Labor Day | First Monday of September |
| Thanksgiving | Fourth Thursday of November |
| Christmas Day | Dec 25 |

**US team members:** Randy, Zack, John

### Spain

| Holiday | Typical Date |
|---------|-------------|
| Maundy Thursday (Madrid) | Thursday before Easter |
| Good Friday | Friday before Easter |
| Labour Day | May 1 |
| Assumption of Mary | Aug 15 |
| National Day | Oct 12 |
| All Saints' Day | Nov 1 |
| Constitution Day | Dec 6 |
| Immaculate Conception | Dec 8 |
| Christmas Day | Dec 25 |

**Spanish team members:** Kike (on leave), Oksana

---

## Using Calendar to Check Holidays

To check if team members might be off, query the calendar for the relevant date range and look for reduced meeting attendance or "Out of Office" events:

```json
CallMcpTool(server="user-google-workspace", toolName="get_events", arguments={
  "user_google_email": "ashafi@redhat.com",
  "time_min": "<date>T00:00:00-04:00",
  "time_max": "<date+1>T00:00:00-04:00",
  "max_results": 20
})
```

Also check the scrum Google Doc -- team members typically note PTO and holidays in the announcements section.

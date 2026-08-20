---
name: job-search
description: AI-powered job search pipeline with career-ops integration, resume tailoring, portal scanning, and application tracking.
triggers:
  - job search
  - job hunt
  - find jobs
  - apply to jobs
  - career-ops
  - scan portals
  - tailor resume
  - job pipeline
  - application tracker
---

# Job Search Skill

AI-powered job search pipeline integrating career-ops, Playwright MCP for portal scanning, and Google Workspace for document management.

## Working Directory

All job-search artifacts live at: `/Users/ashafi/Documents/work/automation/job-search/`

```
job-search/
  cv.md                          -- Master resume (source of truth)
  config/                        -- Target roles, salary, preferences
  tracker/pipeline.md            -- Application status tracker
  resumes/                       -- Generated per-job tailored resumes
  cover-letters/                 -- Generated per-job cover letters
  career-ops/                    -- Career-ops clone (scanner, PDF gen, evaluation)
    config/profile.yml           -- Candidate profile for AI evaluation
    portals.yml                  -- Portal scanner configuration
    data/pipeline.md             -- Career-ops internal tracker
    output/                      -- Generated PDFs and reports
```

## ASK QUESTIONS FIRST

Before proceeding with any mode, gather:
1. **Mode** -- Which operation? (scan, evaluate, tailor, apply, track, summary)
2. **Target** -- Specific job URL, company name, or role title (if applicable)
3. **Constraints** -- Location, salary, remote preference (if not already in profile.yml)

## Available Modes

### 1. SCAN — Discover New Jobs

Scans configured portals and job boards for new listings matching the profile.

**Trigger:** "scan for jobs", "find new listings", "check portals"

**Steps:**
1. Read `portals.yml` for configured search queries and tracked companies
2. Execute search queries via WebSearch tool
3. For each result, extract: title, company, URL, location, salary (if visible)
4. **Liveness check:** Verify each posting is still active — look for "expired", "closed", "no longer accepting", deadline passed signals. Discard dead listings.
5. Score each listing 0-100 against `cv.md` + `config/profile.yml`
6. Filter: only present jobs scoring >= 75
7. Update `tracker/pipeline.md` with new discoveries (status: `discovered`)
8. Report findings with fit analysis

**Output format:**
```markdown
## Scan Results — [DATE]

### Score 90+ (Apply immediately)
| # | Company | Role | Score | URL |
|---|---------|------|-------|-----|

### Score 80-89 (Strong fit)
| # | Company | Role | Score | URL |
|---|---------|------|-------|-----|

### Score 75-79 (Worth reviewing)
| # | Company | Role | Score | URL |
|---|---------|------|-------|-----|
```

### 2. EVALUATE — Score a Specific Job

Deep evaluation of a single job posting against the candidate profile.

**Trigger:** "evaluate this job", "score this listing", paste a job URL

**Steps:**
1. Fetch the full job description (WebFetch or WebSearch)
2. Parse requirements: must-have skills, nice-to-haves, experience level, salary
3. Score against cv.md using 10 dimensions:
   - Technical skill match (0-10)
   - Experience level alignment (0-10)
   - Domain relevance (0-10)
   - Location/remote compatibility (0-10)
   - Compensation alignment (0-10)
   - Growth opportunity (0-10)
   - Company culture fit (0-10)
   - AI/platform intersection (0-10)
   - Seniority match (0-10)
   - Long-term career value (0-10)
4. Identify skill gaps and how to position around them
5. Provide apply/skip recommendation with reasoning

**Output format:**
```markdown
## Evaluation: [ROLE] at [COMPANY]

**Overall Score:** XX/100
**Recommendation:** APPLY / SKIP / STRETCH

### Dimension Breakdown
| Dimension | Score | Notes |
|-----------|-------|-------|

### Key Matches
- ...

### Gaps to Address
- ...

### Positioning Strategy
- ...
```

### 3. TAILOR — Generate Application Materials

Creates a tailored resume and cover letter for a specific job.

**Trigger:** "tailor resume for", "prepare application for", "generate materials"

**Steps:**
1. Read the full job description
2. Read `cv.md` (master resume)
3. Identify the best-fit archetype from profile.yml
4. Generate tailored resume:
   - Reorder experience bullets by relevance to this role
   - Emphasize matching keywords from the JD
   - Adjust professional summary for this specific role
   - Never fabricate — only reorganize and emphasize existing facts
5. Generate cover letter:
   - Opening: specific connection to company/role
   - Body: 2-3 strongest proof points mapped to their requirements
   - Close: enthusiasm + availability
6. Save to `resumes/[company]-[role].md` and `cover-letters/[company]-[role].md`
7. Offer to upload to Google Drive as formatted doc

**Resume tailoring rules:**
- NEVER fabricate experience or skills
- Reorder bullets to front-load most relevant experience
- Mirror keywords from the JD naturally in bullet text
- Adjust professional summary to match target role language
- Include full keyword spelling (e.g., "Kubernetes" not just "K8s")

### 4. APPLY — Assist with Application Submission

Helps navigate application forms using Playwright MCP.

**Trigger:** "help me apply", "fill application", "submit to"

**Steps:**
1. Confirm the target URL and that tailored materials exist
2. Open the application page via Playwright MCP (browser_navigate)
3. Take a snapshot (browser_snapshot) to understand the form
4. Fill standard fields from profile.yml (name, email, phone, location)
5. Upload resume PDF when upload field is detected
6. For screening questions, draft answers based on cv.md context
7. STOP before final submit — always require human confirmation
8. Update tracker status to `applied`

**CRITICAL:** Never submit without explicit user approval. Always pause at the final submit button.

### 5. TRACK — Pipeline Management

View and update the application pipeline.

**Trigger:** "show pipeline", "tracker", "application status", "what's pending"

**Steps:**
1. Read `tracker/pipeline.md`
2. Present current pipeline state grouped by status
3. Flag overdue follow-ups (> 7 days since application with no response)
4. Suggest next actions for each stage

**Pipeline statuses:**
- `discovered` — Found but not yet evaluated
- `evaluating` — Under review
- `preparing` — Materials being tailored
- `ready` — Materials ready, not yet submitted
- `applied` — Application submitted
- `interviewing` — In interview process
- `offered` — Received offer
- `rejected` — Rejected or ghosted
- `withdrawn` — Withdrew application
- `accepted` — Accepted offer

### 6. SUMMARY — Daily/Weekly Report

Generates a summary of job search activity.

**Trigger:** "job search summary", "weekly report", "what's happening with my search"

**Steps:**
1. Read tracker/pipeline.md
2. Count applications by status
3. Calculate response rates
4. Identify top opportunities requiring action
5. Summarize findings and present to user

## Integration Points

### Playwright MCP
- Portal scanning (browser_navigate + browser_snapshot)
- Application form filling (browser_fill, browser_click, browser_type)
- Screenshot evidence of submissions

### Google Workspace MCP
- Upload tailored resumes to Drive (import_to_google_doc)
- Export as PDF (export_doc_to_pdf)
- Calendar integration for interviews (create_calendar event)


### Engram
- Remember which companies have been applied to
- Track interview feedback and salary data points
- Store company-specific insights for future reference

## Tracker Format

The file `tracker/pipeline.md` uses this format:

```markdown
# Job Search Pipeline

## Active Applications

| Date | Company | Role | Score | Status | URL | Notes |
|------|---------|------|-------|--------|-----|-------|
| 2026-06-01 | RBC Borealis | AI Platform Engineer | 92 | discovered | [link] | K8s + AI agents |

## Archive (Closed)

| Date | Company | Role | Outcome | Notes |
|------|---------|------|---------|-------|
```

## Quality Gates

- Never apply to roles scoring below 70 without explicit user override
- Never submit applications without human review of all materials
- Never fabricate skills, experience, or metrics in tailored resumes
- Always preserve the user's authentic voice and real achievements
- Log every application in the tracker for pipeline visibility

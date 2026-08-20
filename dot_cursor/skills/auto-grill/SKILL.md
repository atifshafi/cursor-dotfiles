---
name: auto-grill
description: >-
  Autonomous grill-and-fix loop. Finds issues in code, plans, or documents using
  a griller agent, evaluates fixes via an analyst agent, and applies approved fixes
  via an implementer agent -- all orchestrated by a state machine with circuit
  breakers. Use when user says "auto grill", "grill and fix", "find and fix",
  "grill the code", "grill this implementation", "self-improve", or wants
  autonomous issue detection and resolution on a target.
---

# Auto-Grill -- Autonomous Issue Detection and Resolution

Find issues, evaluate fixes, apply them -- in an agent-to-agent loop with no human in the middle until completion.

## Ask Questions First

| # | Question |
|---|----------|
| 1 | **What is the target?** File path(s), directory, PR, plan document, or feature area. |
| 2 | **What scope of fixes?** Code changes, documentation updates, or both. |
| 3 | **Any constraints?** Files to avoid, patterns to preserve, max issue count. |
| 4 | **Max issues?** Default is 10. |

Do NOT proceed until all four are answered (user may answer implicitly from context).

---

## Phase Gate Enforcement

On skill start, create TodoWrite with phases: `ag-phase-0` (Load context, in_progress), `ag-phase-1` (Spawn griller, pending), `ag-phase-2` (Evaluation loop, pending), `ag-phase-3` (Summary, pending).

- A phase CANNOT be marked complete without executing it.
- Phase 2 stays `in_progress` until griller signals NO_MORE_ISSUES or circuit breaker trips.
- Phase 3 MUST present the full summary before the skill is done.

---

## Phase 0: Load Context

Engram recall for target area patterns/issues. Read all target files (sample if >10). Determine target type: Code (bugs, patterns, coverage), Plan/doc (gaps, inconsistencies), or PR/diff (change-specific). Prepare context summary for the griller.

Mark `ag-phase-0` complete. Mark `ag-phase-1` in_progress.

---

## Phase 1: Spawn Griller

Spawn griller: `generalPurpose`, `run_in_background: false`. Use GRILLER_INITIAL template from [references/prompt-templates.md](references/prompt-templates.md).

**Critical:** Save the returned agent ID -- you will resume this agent for every subsequent iteration.

Parse response:
- `NO_MORE_ISSUES` → skip to Phase 3 (nothing to fix).
- `ISSUE:` → extract structured fields, transition to Phase 2.

Mark `ag-phase-1` complete. Mark `ag-phase-2` in_progress.

---

## Phase 2: Evaluation Loop (State Machine)

Counters: `issues_processed` (0, max = configured limit, default 10), `challenge_count` (0, max = 2, resets per issue).
All subagents: `generalPurpose`, `run_in_background: false`. Griller: resume saved ID. Analyst/Implementer: spawn fresh each time.
Use exact string markers for routing (`ISSUE:`, `NO_MORE_ISSUES`, `VERDICT:`, `FIX_APPLIED:`, `FIX_FAILED:`) -- never interpret intent.

**EVALUATING:** Spawn analyst with ANALYST template. Parse: `VERDICT: APPROVE` → IMPLEMENTING. `VERDICT: CHALLENGE` → CHALLENGING.

**IMPLEMENTING:** Spawn implementer with IMPLEMENTER template. Parse: `FIX_APPLIED:` → log fix, increment `issues_processed` → GRILLING_NEXT. `FIX_FAILED:` → log unresolved, increment `issues_processed` → GRILLING_NEXT.

**CHALLENGING:** Increment `challenge_count`. If >= 2: log issue as UNRESOLVED → GRILLING_NEXT. Else: resume griller with GRILLER_CHALLENGE template → parse refined response → EVALUATING.

**GRILLING_NEXT:** If `issues_processed` >= max → DONE. Resume griller: use GRILLER_UNRESOLVED template if previous issue was unresolved (FIX_FAILED or challenge cap hit), else GRILLER_NEXT template. Parse: `NO_MORE_ISSUES` → DONE. `ISSUE:` → reset `challenge_count` to 0 → EVALUATING.

**DONE:** Mark `ag-phase-2` complete → Phase 3.

---

## Phase 3: Summary

Present report to user with: (1) Target description, (2) Fixes Applied table (# | Issue | Fix | Files), (3) Unresolved Issues table (# | Issue | Reason), (4) Statistics (issues found, fixes applied, challenges made, unresolved, circuit breaker hit).

Store in Engram: `engram_remember("auto-grill session on <target>: found X issues, fixed Y, unresolved Z. Key patterns: ...")`.

Mark `ag-phase-3` complete.

---

## Anti-Patterns (MUST avoid)

| Anti-Pattern | Mitigation |
|-------------|-----------|
| Skipping the analyst | ALWAYS evaluate before implementing |
| Infinite challenge loops | Hard cap at 2 challenges per issue |
| Implementer expanding scope | Implementer prompt forbids scope creep |
| Orchestrator interpreting output | Use exact string markers, not LLM judgment |
| Spawning analyst/implementer in background | Always `run_in_background: false` |

---

## Configuration

Max issues: 10 (user-configurable). Max challenges/issue: 2 (fixed). All models: inherit. Prompt templates: [references/prompt-templates.md](references/prompt-templates.md).

## Output Efficiency

Subagent output should be concise. Analyst: 2-3 sentence reasoning. Implementer: 1-3 bullet point changes. Orchestrator: log issues as one-line summaries in resolved/unresolved lists. Do not echo full subagent responses to user.

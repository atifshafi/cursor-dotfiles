# Prompt Templates -- Auto-Grill Agents

Placeholders marked with `{PLACEHOLDER}` are filled by the orchestrator from its state.

## GRILLER_INITIAL

```
You are analyzing a target for issues, gaps, and defects.

TARGET TYPE: {target_type}
TARGET DESCRIPTION: {target_description}

FILES IN SCOPE:
{file_list_with_paths}

CONTEXT:
{context_summary}

SCOPE OF FIXES ALLOWED: {fix_scope}

CONSTRAINTS:
{constraints_or_none}

---

Your job: Find ONE issue at a time (most severe first). For each issue, respond with EXACTLY this format:

ISSUE: [Clear description of the problem]
LOCATION: [File path + line range, or section name, or "General"]
SEVERITY: [CRITICAL | HIGH | MEDIUM | LOW]
RECOMMENDED_FIX: [Concrete, implementable fix]
RATIONALE: [Why this matters]

When you have no more issues, respond with EXACTLY: NO_MORE_ISSUES

Read the target files now. Start with your first (most critical) issue.
```

## GRILLER_NEXT

```
Your previous issue has been addressed:

ISSUE RESOLVED: {previous_issue_summary}
FIX APPLIED: {fix_applied_summary}
FILES MODIFIED: {files_modified}

Issues resolved so far (do NOT repeat these):
{resolved_issues_list}

Continue with your next issue (most severe remaining), or respond NO_MORE_ISSUES if you have found all issues worth raising.
```

## GRILLER_CHALLENGE

```
Your recommended fix was evaluated and found to have problems.

YOUR ORIGINAL ISSUE: {issue_description}
YOUR RECOMMENDED FIX: {recommended_fix}

ANALYST'S CHALLENGE:
- Objection: {analyst_specific_objection}
- Reasoning: {analyst_reasoning}
- Suggestion: {analyst_suggestion_or_none}

Refine your recommendation for this SAME issue, addressing the analyst's objection: improve the fix, defend it with code evidence, or propose a better approach.

Respond with the same ISSUE/LOCATION/SEVERITY/RECOMMENDED_FIX/RATIONALE format.
```

## GRILLER_UNRESOLVED

```
The previous issue could not be resolved automatically after multiple attempts:

UNRESOLVED ISSUE: {issue_description}
REASON: Could not converge on an acceptable fix after {challenge_count} refinement attempts.

This issue has been logged for manual user review.

Issues resolved so far (do NOT repeat these):
{resolved_issues_list}

Issues unresolved (also do NOT repeat):
{unresolved_issues_list}

Continue with your next issue, or respond NO_MORE_ISSUES if done.
```

## ANALYST

```
You are evaluating a recommended fix for correctness and safety.

ISSUE IDENTIFIED:
{issue_description}

LOCATION: {location}
SEVERITY: {severity}

RECOMMENDED FIX:
{recommended_fix}

RATIONALE PROVIDED:
{rationale}

TARGET FILES (read these to verify the fix makes sense):
{relevant_file_paths}

Verify: (a) issue is real (not false positive), (b) fix is correct, complete, and safe, (c) no regressions to other functionality, (d) fix is minimal and targeted.

Respond with EXACTLY one of:

VERDICT: APPROVE
REASONING: [Why this fix is sound -- 2-3 sentences max]

OR:

VERDICT: CHALLENGE
REASONING: [What is wrong -- 2-3 sentences max]
SPECIFIC_OBJECTION: [The exact flaw]
SUGGESTION: [How to improve, or "No fix needed" if the issue is a false positive]
```

## IMPLEMENTER

```
You are applying an approved fix. Make minimal, targeted changes.

ISSUE:
{issue_description}

LOCATION: {location}

APPROVED FIX:
{recommended_fix}

WHY THIS WAS APPROVED:
{analyst_reasoning}

FILES TO MODIFY:
{file_paths}

SCOPE: {fix_scope}

Apply the fix exactly as described. Remove associated dead imports if removing code. Do NOT refactor beyond scope, fix other issues, or git commit/push.

After applying, respond with:

FIX_APPLIED: [One-line summary]
FILES_MODIFIED: [Comma-separated paths]
CHANGES_MADE: [1-3 bullet points]
VERIFICATION: [How you confirmed correctness]

If you cannot apply the fix:

FIX_FAILED: [Why]
BLOCKING_REASON: [What is missing or ambiguous]
```

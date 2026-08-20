---
name: grill-with-docs
description: Interview the user relentlessly about a plan, design, or idea until reaching shared understanding. Sharpens domain language against existing glossaries (Engram, Knowledge DB, context.md), persists agreed-upon terms, and captures durable decisions in context.md or repo docs (or ADR files only when the repo maintains adr/). Use when user wants to stress-test a plan, get grilled on a design, thinks through an approach, or mentions "grill me".
---

# Grill with Docs -- Structured Decision Interrogation with Shared Language

Interview the user relentlessly about every aspect of their plan until reaching shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. **Sharpen language as you go** -- challenge fuzzy terms, cross-reference against existing glossaries, and persist agreed-upon vocabulary so future sessions start aligned.

## ASK QUESTIONS FIRST

Always ask these before starting the interrogation. No shortcuts -- the grilling only works when both sides are fully aligned on what's being discussed.

1. **What is the plan?** If the user hasn't described it yet, ask: "What's the plan or design you want me to grill you on?"
2. **What scope?** Code change, architecture proposal, test strategy, product decision, or something else?
3. **Any constraints?** Timeline, existing decisions already locked in, areas explicitly out of scope?

## Session Initialization -- Load Shared Language

Before asking the first grilling question, load existing domain context:

1. **Engram recall** -- Call `engram_recall` with the topic/domain area to pull in any existing shared vocabulary, past decisions, and known patterns. This is the primary persistent knowledge source.
2. **Knowledge DB scan** -- If the topic maps to an ACM subsystem, read the relevant file under `.claude/knowledge/` (architecture, UI, health, failures) to ground yourself in documented domain language.
3. **`context.md` lookup** -- Check the repo root (if working in a codebase) for a `context.md` glossary file. If found, read it. This contains the bounded context: entity definitions, relationships, status enums, and terms of art.
4. **Decision log scan (optional)** -- If an `adr/` or `decisions/` directory exists at the repo root, skim titles. Many repos instead fold “why” into `context.md` (e.g. a **Repo design** blurb) and `CLAUDE.md`; treat those as authoritative when present.

Surface what you found: "I loaded context from [sources]. Here's what I already know about the domain: [brief summary]. Let me verify -- is this still accurate?"

## Core Behavior

1. **Ask one question at a time.** Wait for the user's answer before moving to the next question.
2. **Provide your recommended answer** with each question. If the recommendation is obviously right, the user can just say "yes" instead of explaining.
3. **If a question can be answered by exploring the codebase, explore the codebase instead.** Don't ask what you can look up.
4. **Walk the decision tree systematically.** Start from the highest-level decisions, then branch into dependent sub-decisions as each parent is resolved.
5. **Challenge vague or hand-wavy answers.** If the user says "it should handle errors properly," push back: "What specific errors? What does 'properly' mean here -- retry, fail fast, degrade gracefully?"

## Language Sharpening -- The Key Differentiator

Throughout the session, actively work on the shared vocabulary:

### Challenge Language Against the Glossary

- When the user introduces a term, check if it already exists in the loaded context (Engram, Knowledge DB, `context.md`). If it does, use the established definition. If the user's usage differs, surface the conflict: "In our glossary, 'standalone video' means X. You seem to be using it to mean Y. Which is it, or do we need a new term?"
- When the user uses a vague or overloaded term, push for precision: "'Resource' is too broad here. Are we talking about a ManagedCluster, a ClusterSet, or a Policy?"

### Sharpen Fuzzy Language

- When you catch yourself or the user being verbose about something that should have a name, stop and name it: "We keep saying 'a cluster that's in a cluster set but the user only has project-level access to.' Should we call that a 'project-scoped cluster'?"
- When a concept is repeated across multiple questions, it deserves a term. Propose one.

### Discuss Concrete Scenarios

- Anchor abstract terms in concrete examples: "When you say 'full access,' does that mean the user can see VMs on all clusters in the set, or just the clusters they have RBAC bindings for?"
- Use scenarios to test whether the language holds: "If a user has project access to cluster-set-A and full access to cluster-set-B, and a VM exists on a cluster in both sets, what do we call that user's access level?"

### Cross-Reference with Code

- When a term is agreed upon, verify it matches the code (variable names, file names, route paths, test IDs). If there's a mismatch, surface it: "We're calling this 'scope type' but the code uses `accessLevel`. Should we align?"
- This prevents the glossary from diverging from reality.

## Session Flow

### Opening

When the user invokes this skill (explicitly or by describing a plan to stress-test):

1. **Load shared language** (see Session Initialization above).
2. Read any context the user has provided (plan description, ticket, feature spec).
3. If working in a codebase, scan relevant files to ground the interrogation in reality.
4. Surface any terminology conflicts or gaps you noticed during initialization.
5. Start with the broadest, highest-stakes question first.

### During the Session

- Pursue each decision branch to its leaf before backtracking.
- When you hit a resolved branch (user is confident, answer is clear), acknowledge it briefly and move to the next unresolved branch.
- Surface contradictions immediately: "Earlier you said X, but now you're describing Y -- which is it?"
- When the user's answer reveals a new decision branch you hadn't considered, add it to the tree and pursue it.
- **When new shared language is agreed upon, note it for persistence.** Don't interrupt the flow to document it -- batch updates for natural pauses or the end of the session.

### Closing

When all branches are resolved (or the user signals they're done):

1. Present a **Decision Summary** -- a concise list of every resolved decision, grouped by topic.
2. Present a **Language Updates** section -- any new or refined terms that were agreed upon during the session.
3. Flag any **open questions** that remain unresolved.
4. **Persist the shared language:**
   - Store new terms and decisions in Engram via `engram_remember` so they survive across sessions.
   - If a `context.md` exists in the repo, offer to update it with new entity definitions, glossary entries, and (when relevant) a short **Repo design** bullet for non-obvious architecture choices.
   - If a decision is non-obvious (hard to reverse, surprising without context, result of a real trade-off) **and** the repo maintains `adr/`, offer to add an ADR there; otherwise offer to extend `CLAUDE.md` or the appropriate `docs/` page instead.
5. Ask: "Should I proceed with implementation based on these decisions?"

## Decision Summary Format

```
## Decisions Resolved

### [Topic Area 1]
- Decision: [what was decided]
- Decision: [what was decided]

### [Topic Area 2]
- Decision: [what was decided]

## Language Updates

### New Terms
- **[term]**: [definition agreed upon during this session]

### Refined Terms
- **[term]**: [previous definition] → [updated definition]

### Conflicts Resolved
- **[term]**: [how the ambiguity was resolved]

## Open Questions
- [anything still unresolved]

## Next Steps
- [concrete actions based on resolved decisions]
```

## Optional: ADR format (repos that maintain `adr/`)

Skip this section if the repo has no `adr/` directory. When it does, create an ADR only when the decision meets ALL three criteria:
- **Hard to reverse** -- changing this later has significant cost
- **Surprising without context** -- a future reader would ask "why?"
- **Result of a real trade-off** -- there were genuine alternatives considered

```markdown
# ADR-NNN: [Short Decision Title]

**Status:** Accepted
**Date:** [YYYY-MM-DD]
**Context:** [Why this decision was needed -- the problem or question]
**Decision:** [What was decided]
**Alternatives Considered:**
- [Option A]: [why rejected]
- [Option B]: [why rejected]
**Consequences:**
- [What follows from this decision -- both positive and negative]
```

## Modes

### Code Mode (default when working in a codebase)

Grounds questions in actual code, files, and architecture. Cross-references the user's answers against what the codebase actually does. When the user states how something works, verify it by reading the code -- surface contradictions. Actively checks that agreed-upon language matches variable names, file names, and code structure.

### General Mode (for non-code plans)

Works for any decision-making: product planning, test strategy, process design, architecture proposals. Focuses on logical consistency, completeness, and edge cases without codebase exploration. Language sharpening still applies -- even non-code plans benefit from precise vocabulary. Engram is still used for persistence, but `context.md` and code cross-referencing are skipped.

## What Makes a Good Grilling Question

- **Forces a concrete decision**, not a vague aspiration
- **Reveals hidden assumptions** the user hasn't thought about
- **Exposes edge cases** and failure modes
- **Identifies dependencies** between decisions
- **Challenges scope** -- "Do you really need this, or is it gold-plating?"
- **Sharpens language** -- "What exactly do you mean by [term]?"

## Anti-Patterns to Avoid

- Don't ask multiple questions at once -- one at a time only.
- Don't accept "we'll figure it out later" for critical-path decisions. Push back: "This blocks everything downstream. Let's resolve it now, even if the answer is provisional."
- Don't turn the session into a lecture. Keep questions short and pointed.
- Don't ask questions you can answer by reading the codebase.
- Don't summarize after every question -- save the summary for the end.
- Don't invent jargon when a simple word works. The goal is clarity, not complexity.
- Don't skip the glossary check. If a term exists in Engram or the Knowledge DB, use it -- don't reinvent it.
- Don't update `context.md`, repo decision docs, or ADRs mid-session without asking. Batch language persistence for natural pauses or session close.

---
name: skill-authoring-standards
description: >-
  Enforce Anthropic skill authoring standards when creating, editing, or
  reviewing agent skills. Covers file structure, YAML frontmatter, progressive
  disclosure, description writing, instruction quality, patterns, testing, and
  anti-patterns. Use when authoring a new skill, editing SKILL.md, reviewing
  skill quality, or when the user mentions "create a skill", "skill guidelines",
  "skill standards", or "SKILL.md".
---

# Skill Authoring Standards

Enforce the Anthropic Agent Skills standard when creating or editing skills.
This skill is the quality gate -- it defines WHAT makes a good skill.
The built-in `create-skill` handles the HOW (workflow, file creation).

For the full detailed Anthropic reference, see [references/anthropic-skill-guide.md](references/anthropic-skill-guide.md).

---

## File Structure (Mandatory)

```
skill-name/
├── SKILL.md              # Required -- must be exactly SKILL.md (case-sensitive)
├── scripts/              # Optional -- executable tools (Python, Bash, etc.)
├── references/           # Optional -- detailed documentation loaded on demand
└── assets/               # Optional -- templates, fonts, icons used in output
```

**Naming rules:**
- Folder: kebab-case only (`notion-project-setup`, not `Notion_Project_Setup`)
- No README.md inside the skill folder -- all docs go in SKILL.md or references/
- No spaces, no underscores, no capitals in folder name

---

## YAML Frontmatter (Mandatory)

Every SKILL.md starts with YAML frontmatter between `---` delimiters:

```yaml
---
name: skill-name-in-kebab-case
description: >-
  What it does. When to use it. Specific trigger phrases.
---
```

### Field Rules

| Field | Constraint | Notes |
|-------|-----------|-------|
| `name` | Required. Max 64 chars. Lowercase, numbers, hyphens only. | Must match folder name. No "claude" or "anthropic" prefix (reserved). |
| `description` | Required. Max 1024 chars. Non-empty. | Must contain WHAT + WHEN + trigger phrases. No XML angle brackets. |
| `disable-model-invocation` | Optional boolean. | Set `true` for explicit-only invocation. Omit for auto-invoke. |
| `license` | Optional. | Use for open-source skills (MIT, Apache-2.0). |
| `metadata` | Optional object. | Custom fields: author, version, mcp-server, tags. |

### Forbidden in Frontmatter
- XML angle brackets (`<` `>`) -- security restriction (frontmatter appears in system prompt)
- Skills named with "claude" or "anthropic" prefix (reserved by Anthropic)

---

## The Description: Most Critical Field

The description is the FIRST level of progressive disclosure. It's always loaded in the system prompt. Claude uses it to decide whether to load the skill. Get this wrong and the skill never triggers.

### Formula

```
[What it does] + [When to use it] + [Key trigger phrases]
```

### Good Descriptions

```yaml
# Specific, actionable, includes triggers
description: >-
  Analyzes Figma design files and generates developer handoff documentation.
  Use when user uploads .fig files, asks for "design specs", "component
  documentation", or "design-to-code handoff".

# Clear value, multiple trigger phrases
description: >-
  End-to-end customer onboarding workflow for PayFlow. Handles account
  creation, payment setup, and subscription management. Use when user says
  "onboard new customer", "set up subscription", or "create PayFlow account".
```

### Bad Descriptions

```yaml
# Too vague -- won't trigger
description: Helps with projects.

# Missing triggers -- Claude won't know WHEN to use it
description: Creates sophisticated multi-page documentation systems.

# Too technical, no user-facing triggers
description: Implements the Project entity model with hierarchical relationships.
```

### Negative Triggers (Prevent Over-Triggering)

When a skill triggers too broadly, add negative triggers:

```yaml
description: >-
  Advanced data analysis for CSV files. Use for statistical modeling,
  regression, clustering. Do NOT use for simple data exploration
  (use data-viz skill instead).
```

---

## Progressive Disclosure (Three Levels)

Skills use a three-level system to minimize token usage:

| Level | What | When Loaded | Size Target |
|-------|------|-------------|-------------|
| **Level 1**: YAML frontmatter | Skill identity + triggers | Always (in system prompt) | Under 1024 chars (description) |
| **Level 2**: SKILL.md body | Core instructions, workflow steps | When Claude decides the skill is relevant | Under 500 lines |
| **Level 3**: Linked files | Detailed docs, examples, API refs | Only when Claude needs specific detail | No hard limit |

**Rules:**
- Keep SKILL.md body under 500 lines. Move detailed content to `references/`.
- Keep references one level deep -- link directly from SKILL.md. Deeply nested refs may be partially read.
- The agent is smart. Only add context it doesn't already have. Challenge every paragraph: "Does this justify its token cost?"

---

## Writing Instructions

Instructions in a skill define what the agent does. The quality of the output is directly proportional to how well the instructions frame the thinking BEFORE the doing. An agent follows what it reads -- if the instruction says "create," it creates. If the instruction says "investigate whether you need to create, then create only what's missing," it reasons first.

### The Instruction Spectrum: Investigation → Decision → Action

Every instruction in a skill falls somewhere on this spectrum. The mistake most skill authors make is jumping straight to ACTION without the preceding steps.

| Level | What the agent does | When to use | Example |
|-------|--------------------|----|---------|
| **Investigation** | Reads existing code, checks current state, maps requirements to what exists | Always before creation. Skip only for truly mechanical steps (run a command, format a file). | "Read `src/config/index.ts`. List every getter. Map each to the fields you need." |
| **Decision** | Evaluates whether action is needed, chooses between alternatives based on criteria | When multiple valid paths exist, or when the obvious path might be wrong | "If existing getters cover 80%+ of needed fields, extend them. Only create new if genuinely missing." |
| **Action** | Creates, modifies, deletes, runs | After investigation and decision confirm the action is correct | "Add the missing field to `getVirtConfig()` in index.ts." |

**Rule**: If an instruction jumps directly to ACTION without Investigation or Decision, ask: "Could a reasonable agent follow this instruction and produce the wrong result?" If yes, add the preceding steps.

### Be Specific and Actionable (for Action-level instructions)

When the investigation and decision are done and the agent needs to ACT, be precise:

```markdown
<!-- GOOD -- precise action after decision is made -->
Run `python scripts/validate.py --input {filename}` to check data format.
If validation fails, common issues include:
- Missing required fields (add them to the CSV)
- Invalid date formats (use YYYY-MM-DD)

<!-- BAD -- vague, no path to follow -->
Validate the data before proceeding.
```

### Frame Investigation Before Creation

When the instruction involves creating something (a file, function, interface, component), ALWAYS precede it with what the agent should investigate:

```markdown
<!-- DANGEROUS -- pure generation, no investigation -->
Create a config getter for RBAC tests in src/config/index.ts.

<!-- SAFE -- investigation → decision → conditional action -->
The test needs these data fields: [user, password, idp, spoke cluster].
1. Read src/config/index.ts -- list all exported getters and their return fields.
2. Read src/config/presets.ts -- check if user identity data is already there.
3. For each needed field, check: is it already returned by an existing getter?
4. Only create a NEW getter for fields that have NO existing source.
5. If all fields are available: compose from existing functions. No new getter.
```

### Clarify Semantics When a Term Has Multiple Valid Interpretations

A single phrase like "fixtures wire page objects" can mean:
- "Fixtures create same-domain page objects for DI" (correct for most cases)
- "Fixtures bundle cross-domain page objects into a convenience wrapper" (creates coupling)

Both are reasonable interpretations. The instruction MUST disambiguate:

```markdown
<!-- AMBIGUOUS -- agent could interpret either way -->
Area fixtures attach page objects to the session.

<!-- CLEAR -- semantic boundary explicitly drawn -->
Area fixtures wire SAME-DOMAIN page objects only (e.g., FG-RBAC fixture wires
UserDetailsPage, RoleAssignmentWizardPage). Cross-domain page objects (e.g.,
Fleet Virt pages needed by an RBAC test) are constructed INLINE in the test
file, not wired through the fixture. This prevents compile-time coupling
between unrelated areas.
```

### Provide Decision Criteria, Not Just the Pattern

When a pattern has exceptions or boundaries, the agent needs to know HOW to decide, not just WHAT to do:

```markdown
<!-- INSUFFICIENT -- tells WHAT but not WHEN/WHY -->
Use .catch() for cleanup operations.

<!-- COMPLETE -- tells WHAT, WHEN, WHY, and WHEN NOT -->
Error handling in cleanup:
- Multi-step cleanup (loop over items, partial failure acceptable): wrap in
  try/catch. Reason: deleting 3 of 5 MCRAs is better than deleting 0.
- Single atomic command with --ignore-not-found: do NOT add .catch().
  Reason: --ignore-not-found handles the expected case (resource already gone).
  Adding .catch() hides real errors (permission denied, API server down).
- Never use BOTH --ignore-not-found AND .catch() on the same call.
```

### Include Error Handling

```markdown
## Common Issues

### MCP Connection Failed
If you see "Connection refused":
1. Verify MCP server is running: Check Settings > Extensions
2. Confirm API key is valid
3. Try reconnecting: Settings > Extensions > [Service] > Reconnect
```

### Reference Bundled Resources Clearly

```markdown
Before writing queries, consult `references/api-patterns.md` for:
- Rate limiting guidance
- Pagination patterns
- Error codes and handling
```

### Set Degrees of Freedom by Task Fragility

| Freedom | When | Example |
|---------|------|---------|
| **High** (text instructions) | Multiple valid approaches, low risk | Code review guidelines |
| **Medium** (pseudocode/templates) | Preferred pattern with acceptable variation | Report generation |
| **Low** (specific scripts) | Fragile operations, consistency critical | Database migrations |
| **Zero** (investigation required) | Creation that could duplicate or conflict with existing code | Config getters, service methods, fixture wiring |

### The "Could a Smart Developer Get This Wrong?" Test

Before finalizing any instruction, ask: "If a smart developer read ONLY this instruction (without broader context), could they reasonably do the wrong thing while feeling they're following it correctly?"

If yes, the instruction lacks:
- **Scope boundaries** (where the pattern stops applying)
- **Decision criteria** (when to use A vs B)
- **Negative examples** (what NOT to do, and why)
- **Investigation step** (what to check before acting)

Add whichever is missing until the answer is "no."

---

## Scripts as Tools

Scripts inside `scripts/` are tools for the agent's future self. They are more reliable
than generated code, save tokens, save time, and ensure consistency.

When you see Claude writing the same code repeatedly during skill development,
extract it into a script inside the skill folder.

```markdown
## Utility scripts

**validate.py**: Check output for errors
\`\`\`bash
python scripts/validate.py output/
# Returns: "OK" or lists issues
\`\`\`
```

Make clear whether the agent should **execute** the script or **read** it as reference.

---

## Skill Patterns

Choose the pattern that best fits the workflow:

| Pattern | When to Use | Key Technique |
|---------|-------------|---------------|
| **Sequential Workflow** | Multi-step process in specific order | Explicit step ordering, dependencies, validation at each stage |
| **Multi-MCP Coordination** | Workflows spanning multiple services | Clear phase separation, data passing between MCPs, centralized error handling |
| **Iterative Refinement** | Output quality improves with iteration | Explicit quality criteria, validation scripts, know when to stop |
| **Context-Aware Selection** | Same outcome, different tools per context | Decision criteria, fallback options, transparency about choices |
| **Domain-Specific Intelligence** | Specialized knowledge beyond tool access | Domain expertise in logic, compliance before action, audit trail |

For detailed pattern examples, see [references/anthropic-skill-guide.md](references/anthropic-skill-guide.md).

---

## Composability

Skills must work alongside other skills. Never assume your skill is the only one loaded.
Design for composability:
- Don't claim exclusive ownership of broad domains
- Use specific trigger phrases, not generic ones
- Avoid instructions that conflict with common agent behavior

---

## Anti-Patterns (Must Avoid)

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| Vague skill names (`helper`, `utils`, `tools`) | Won't trigger, unclear purpose | Use descriptive names (`processing-pdfs`, `sprint-planning`) |
| Windows-style paths (`scripts\helper.py`) | Cross-platform breakage | Use forward slashes (`scripts/helper.py`) |
| Too many options without a default | Confuses the agent | Provide a default with escape hatch |
| Time-sensitive information | Becomes stale | Use "Current method" / "Deprecated" sections |
| Inconsistent terminology | Confuses the agent | Pick one term, use it throughout |
| Verbose explanations of obvious concepts | Wastes tokens | The agent is smart -- only add what it doesn't know |
| Missing error handling | Agent gets stuck on failures | Include troubleshooting for common failures |
| All content in SKILL.md (no progressive disclosure) | Bloats context window | Move detailed docs to `references/` |
| **Bare generative instructions** | Agent creates without checking if existing code covers the need | See "Instruction Nuance" section below |
| **Omitting "why" from constraints** | Agent can't reason about edge cases the instruction doesn't cover | Always explain the reasoning behind a constraint |

---

## Instruction Nuance: Preventing Mechanical Execution

The most dangerous instructions in a skill are **bare generative commands** -- instructions that tell the agent to CREATE something without first verifying the creation is necessary. LLMs have an inherent **generation bias**: creating new code is a single creative step, while reusing existing code requires multi-step reasoning (read -> understand -> map -> compose). Skills must actively counteract this bias.

### The Problem: Bare Generative Instructions

```markdown
<!-- DANGEROUS -- agent will mechanically create without checking -->
| Config | `src/config/schema.ts` (add interface), `src/config/index.ts` (add getter) |

<!-- The agent reads this as: "I need config → create a getter." -->
<!-- It never asks: "Does an existing getter already return this data?" -->
```

This led to an agent creating `getRbacConfig()` with 6 fields, 4 of which were already available through the existing `getRbacUsers()`. The agent followed the instruction perfectly -- and produced redundant code.

### The Fix: Reuse-First Checkpoints

Every instruction that can lead to code creation must include a **checkpoint that requires reasoning before acting**:

```markdown
<!-- GOOD -- forces the agent to prove necessity before creating -->
| Config | **STOP.** List every field you need. For each field, check: does an
  existing getter already return it? Only add to schema.ts + index.ts if the
  field is genuinely new. User identity data belongs in existing presets, NOT
  in a new getter. |
```

### When to Add Nuance vs Keep Simple

| Instruction Type | Risk of Misinterpretation | Guidance |
|-----------------|--------------------------|----------|
| **Direct action, no alternatives** (e.g., "use path aliases") | LOW | Keep simple. One-line instruction is fine. |
| **Creation that could duplicate existing code** (e.g., "add config getter") | HIGH | Add reuse-first checkpoint. Require the agent to list what exists and prove the gap. |
| **Pattern with domain-specific boundaries** (e.g., "fixtures wire page objects") | HIGH | Add scope boundaries and examples of what NOT to do. E.g., "same-domain POs only, cross-domain POs constructed inline." |
| **Cleanup/error handling** (e.g., "use .catch for cleanup") | MEDIUM | Distinguish cases. "Multi-step → catch OK. Single command with --ignore-not-found → no catch." |

### Rules for Writing Non-Ambiguous Instructions

1. **If an instruction says "create X", it must also say "but first check if Y already does this."** Every generative instruction needs its reuse-first counterpart.

2. **If an instruction describes a pattern, provide the boundary where the pattern stops applying.** "Fixtures wire page objects" is incomplete. "Fixtures wire same-domain page objects; cross-domain POs are constructed inline in the test" is complete.

3. **If an instruction involves a choice (when to use A vs B), provide the decision criteria explicitly.** Don't say "use .catch for cleanup." Say "use .catch only for multi-step cleanup where partial completion is acceptable. For single atomic commands, let errors propagate."

4. **If multiple reasonable interpretations exist, the instruction is too vague.** Test by asking: "Could a smart developer reading this instruction choose to do the wrong thing while feeling they're following it correctly?" If yes, add more context.

5. **Include concrete examples of the WRONG interpretation alongside the RIGHT one.** The agent learns boundaries fastest from negative examples.

### Example: Converting a Bare Instruction to a Nuanced One

**Before (dangerous):**
```markdown
## Phase 3: Code Generation
Write code in this order: Service → Page Object → Fixture → Test
```

**After (safe):**
```markdown
## Phase 3: Code Generation
For each artifact in this order (Service → Page Object → Fixture → Test):
1. Check if an existing file already provides what you need (read it, map its methods to your requirements)
2. If it does: extend or compose it. Do NOT create a parallel implementation.
3. If it partially does (80%+): add the missing methods to the existing file.
4. If nothing exists: create the new file following the patterns found in Phase 1.
```

### Data-Level vs Function-Level Duplication

Skills often catch function-level duplication ("don't recreate a function that exists"). But **data-level duplication** is subtler and equally harmful:

- Two getters returning the same user data from the same env vars/presets (different names, same values)
- A new interface whose fields are a subset of an existing interface
- A config object that hardcodes values already available through a function call

Skills that involve data access (config, services, APIs) must explicitly instruct agents to check for data-level overlap, not just function-name collisions.

---

### Structure
- [ ] Folder named in kebab-case, matches `name` field
- [ ] SKILL.md exists (exact spelling, case-sensitive)
- [ ] YAML frontmatter has `---` delimiters
- [ ] `name`: kebab-case, no spaces, no capitals, max 64 chars
- [ ] `description`: includes WHAT + WHEN + trigger phrases, under 1024 chars
- [ ] No XML tags anywhere in frontmatter
- [ ] SKILL.md body under 500 lines
- [ ] References one level deep (no nested chains)

### Content
- [ ] Instructions are specific and actionable (not vague)
- [ ] Error handling included for common failures
- [ ] Examples provided for key workflows
- [ ] Consistent terminology throughout
- [ ] No time-sensitive information
- [ ] Progressive disclosure used (detail in references/, core in SKILL.md)
- [ ] Scripts documented with execution instructions

### Instruction Quality (Nuance Check)
- [ ] No bare generative instructions ("create X") without a reuse-first checkpoint ("but first check if Y exists")
- [ ] Pattern instructions include scope boundaries (where the pattern stops applying)
- [ ] Choice instructions include explicit decision criteria (when A vs B)
- [ ] Instructions with multiple valid interpretations are disambiguated with examples
- [ ] Negative examples provided for instructions that commonly lead to misinterpretation
- [ ] Data-access instructions (config, services, APIs) explicitly address data-level duplication

### Testing
- [ ] Triggers on obvious task descriptions
- [ ] Triggers on paraphrased requests
- [ ] Does NOT trigger on unrelated topics
- [ ] Workflow completes without user correction
- [ ] Consistent results across sessions

---

## Cursor-Specific Conventions

When building skills for this workspace, also follow these established patterns:

### Phase Gate Enforcement
Complex skills use TodoWrite to track phases. Each phase must execute before marking complete.
Gate phases (quality reviews, test execution) are HARD STOPS.

### ASK QUESTIONS FIRST
Every skill includes an "ASK QUESTIONS FIRST" section. Always ask for missing
information before proceeding. No shortcuts.

### MCP Integration
When a skill uses MCP servers, document which servers and tools are needed.
Follow the MCP server priority order from the workspace rules.

### Engram Integration
Use `engram_recall` before starting (check for existing knowledge).
Use `engram_remember` after completing (store discoveries).

### Clean Up Dead Code
When updating skills, remove orphaned files, stale references, and unused scripts
in the same action. Never leave dead code.

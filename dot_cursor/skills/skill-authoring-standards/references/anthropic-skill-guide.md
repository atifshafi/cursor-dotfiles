# Anthropic Agent Skills -- Full Reference Guide

Source: "The Complete Guide to Building Skills for Claude" (Anthropic, 2026)
and "Why We Stopped Building Agents and Started Building Skills Instead"
(Barry Zhang & Mahesh Murag, Anthropic talk, 2026).

This reference is loaded on-demand when the agent needs detailed guidance
beyond what SKILL.md covers.

---

## What is a Skill?

A skill is a set of instructions -- packaged as a simple folder -- that teaches
an agent how to handle specific tasks or workflows. Instead of re-explaining
preferences, processes, and domain expertise in every conversation, skills let
you teach once and benefit every time.

Skills are powerful when you have repeatable workflows: generating frontend
designs from specs, conducting research with consistent methodology, creating
documents following a style guide, or orchestrating multi-step processes.

### Core Design Principles

**Progressive Disclosure**: Skills use a three-level system:
- Level 1 (YAML frontmatter): Always loaded in the system prompt. Enough
  for the agent to know when the skill should be used.
- Level 2 (SKILL.md body): Loaded when the agent thinks the skill is relevant.
  Contains full instructions and guidance.
- Level 3 (Linked files): Additional files the agent discovers only as needed.

**Composability**: The agent can load multiple skills simultaneously. Each skill
should work well alongside others, not assume it's the only capability.

**Portability**: Skills work identically across Claude.ai, Claude Code, and API.
Create once, works everywhere (provided the environment supports dependencies).

---

## Skills + MCP Servers

MCP provides connectivity (what the agent CAN do). Skills provide expertise
(how the agent SHOULD do it).

| MCP (Connectivity) | Skills (Knowledge) |
|---------------------|--------------------|
| Connects the agent to your service | Teaches the agent how to use it well |
| Real-time data access and tool invocation | Captures workflows and best practices |
| What the agent can do | How the agent should do it |

Without skills: users connect MCP but don't know what to do next, each
conversation starts from scratch, inconsistent results.

With skills: pre-built workflows activate automatically, consistent tool usage,
best practices embedded in every interaction, lower learning curve.

---

## Planning and Design

### Start with Use Cases

Before writing any code, identify 2-3 concrete use cases:

```
Use Case: Project Sprint Planning
Trigger: User says "help me plan this sprint"
Steps:
1. Fetch current project status (via MCP)
2. Analyze team velocity and capacity
3. Suggest task prioritization
4. Create tasks with proper labels and estimates
Result: Fully planned sprint with tasks created
```

Ask yourself:
- What does a user want to accomplish?
- What multi-step workflows does this require?
- Which tools are needed (built-in or MCP)?
- What domain knowledge should be embedded?

### Skill Use Case Categories

**Category 1: Document & Asset Creation**
Creating consistent, high-quality output (documents, presentations, code, designs).
Key techniques: embedded style guides, template structures, quality checklists.
No external tools required.

**Category 2: Workflow Automation**
Multi-step processes that benefit from consistent methodology.
Key techniques: step-by-step workflow with validation gates, templates,
built-in review and improvement suggestions, iterative refinement loops.

**Category 3: MCP Enhancement**
Workflow guidance to enhance tool access an MCP server provides.
Key techniques: coordinates multiple MCP calls in sequence, embeds domain
expertise, provides context users would otherwise need to specify.

---

## Success Criteria

### Quantitative Metrics
- **Skill triggers on 90% of relevant queries**: Run 10-20 test queries.
  Track how many trigger automatically vs. require explicit invocation.
- **Completes workflow in target tool calls**: Compare with and without skill.
  Count tool calls and tokens consumed.
- **0 failed API calls per workflow**: Monitor MCP server logs during tests.

### Qualitative Metrics
- Users don't need to prompt about next steps
- Workflows complete without user correction
- Consistent results across sessions
- New user can accomplish the task on first try

---

## File Structure Details

```
your-skill-name/
├── SKILL.md           # Required -- main skill file
├── scripts/           # Optional -- executable code
│   ├── process_data.py
│   └── validate.sh
├── references/        # Optional -- documentation
│   ├── api-guide.md
│   └── examples/
└── assets/            # Optional -- templates, etc.
    └── report-template.md
```

### Critical Rules
- SKILL.md naming: Must be exactly `SKILL.md` (case-sensitive). No variations.
- Folder naming: kebab-case only. No spaces, underscores, or capitals.
- No README.md inside the skill folder.

### YAML Frontmatter Fields

**Required:**
```yaml
---
name: skill-name-in-kebab-case
description: What it does and when to use it. Include trigger phrases.
---
```

**All Optional Fields:**
```yaml
license: MIT
allowed-tools: "Bash(python:*) Bash(npm:*) WebFetch"
compatibility: "Requires Python 3.10+, network access for API calls"
metadata:
  author: Company Name
  version: 1.0.0
  mcp-server: server-name
  category: productivity
  tags: [project-management, automation]
  documentation: https://example.com/docs
  support: support@example.com
```

**Security Restrictions:**
- No XML angle brackets in frontmatter (could inject instructions)
- No "claude" or "anthropic" in skill names (reserved)
- Uses safe YAML parsing (no code execution)

---

## Description Writing -- Deep Dive

The description field is the most important part of a skill. It determines
whether the skill ever gets loaded.

### Structure
`[What it does] + [When to use it] + [Key capabilities]`

### Write in Third Person
The description is injected into the system prompt:
- Good: "Processes Excel files and generates reports"
- Bad: "I can help you process Excel files"

### Include Trigger Terms
Users say things in different ways. Include variations:
- "sprint", "Linear tasks", "project planning", "create tickets"
- "design specs", "component documentation", "design-to-code handoff"

### Include File Types if Relevant
- "Use when working with PDF files or .fig files"

### Add Negative Triggers if Needed
- "Do NOT use for simple data exploration (use data-viz skill instead)"

---

## Instruction Writing -- Deep Dive

### Recommended Structure

```markdown
# Your Skill Name

## Instructions

### Step 1: [First Major Step]
Clear explanation of what happens.

Example:
\`\`\`bash
python scripts/fetch_data.py --project-id PROJECT_ID
\`\`\`
Expected output: [describe what success looks like]

(Add more steps as needed)

## Examples

### Example 1: [common scenario]
User says: "Set up a new marketing campaign"
Actions:
1. Fetch existing campaigns via MCP
2. Create new campaign with provided parameters
Result: Campaign created with confirmation link

## Troubleshooting

### Error: [Common error message]
Cause: [Why it happens]
Solution: [How to fix]
```

### Key Principles

1. **Be specific and actionable**: "Run `python scripts/validate.py --input {filename}`"
   not "Validate the data before proceeding."

2. **Include error handling**: Document common failures with causes and solutions.

3. **Reference bundled resources clearly**: "Consult `references/api-patterns.md` for
   rate limiting guidance."

4. **Use progressive disclosure**: Keep SKILL.md focused on core instructions.
   Move detailed documentation to `references/`.

5. **For critical validations**: Consider bundling a script that performs checks
   programmatically. Code is deterministic; language interpretation isn't.

6. **Avoid "model laziness"**: For quality-critical tasks, add explicit encouragement:
   "Take your time to do this thoroughly. Quality is more important than speed.
   Do not skip validation steps." (More effective in user prompts than in SKILL.md.)

---

## Skill Patterns -- Detailed Examples

### Pattern 1: Sequential Workflow Orchestration

Use when users need multi-step processes in a specific order.

```markdown
## Workflow: Onboard New Customer

### Step 1: Create Account
Call MCP tool: `create_customer`
Parameters: name, email, company

### Step 2: Setup Payment
Call MCP tool: `setup_payment_method`
Wait for: payment method verification

### Step 3: Create Subscription
Call MCP tool: `create_subscription`
Parameters: plan_id, customer_id (from Step 1)

### Step 4: Send Welcome Email
Call MCP tool: `send_email`
Template: welcome_email_template
```

Key techniques: explicit step ordering, dependencies between steps,
validation at each stage, rollback instructions for failures.

### Pattern 2: Multi-MCP Coordination

Use when workflows span multiple services.

```markdown
## Phase 1: Design Export (Figma MCP)
1. Export design assets from Figma
2. Generate design specifications
3. Create asset manifest

## Phase 2: Asset Storage (Drive MCP)
1. Create project folder in Drive
2. Upload all assets
3. Generate shareable links

## Phase 3: Task Creation (Linear MCP)
1. Create development tasks
2. Attach asset links to tasks
3. Assign to engineering team

## Phase 4: Notification (Slack MCP)
1. Post handoff summary to #engineering
2. Include asset links and task references
```

Key techniques: clear phase separation, data passing between MCPs,
validation before moving to next phase, centralized error handling.

### Pattern 3: Iterative Refinement

Use when output quality improves with iteration.

```markdown
## Initial Draft
1. Fetch data via MCP
2. Generate first draft report
3. Save to temporary file

## Quality Check
1. Run validation script: `scripts/check_report.py`
2. Identify issues (missing sections, formatting, data errors)

## Refinement Loop
1. Address each identified issue
2. Regenerate affected sections
3. Re-validate
4. Repeat until quality threshold met

## Finalization
1. Apply final formatting
2. Generate summary
3. Save final version
```

Key techniques: explicit quality criteria, iterative improvement,
validation scripts, know when to stop iterating.

### Pattern 4: Context-Aware Tool Selection

Use when same outcome requires different tools depending on context.

```markdown
## Decision Tree
1. Check file type and size
2. Determine best storage location:
   - Large files (>10MB): Use cloud storage MCP
   - Collaborative docs: Use Notion/Docs MCP
   - Code files: Use GitHub MCP
   - Temporary files: Use local storage

## Execute Storage
Based on decision:
- Call appropriate MCP tool
- Apply service-specific metadata
- Generate access link

## Provide Context to User
Explain why that storage was chosen
```

Key techniques: clear decision criteria, fallback options,
transparency about choices.

### Pattern 5: Domain-Specific Intelligence

Use when the skill adds specialized knowledge beyond tool access.

```markdown
## Before Processing (Compliance Check)
1. Fetch transaction details via MCP
2. Apply compliance rules:
   - Check sanctions lists
   - Verify jurisdiction allowances
   - Assess risk level
3. Document compliance decision

## Processing
IF compliance passed:
- Call payment processing MCP tool
- Apply appropriate fraud checks
ELSE:
- Flag for review
- Create compliance case

## Audit Trail
- Log all compliance checks
- Record processing decisions
- Generate audit report
```

Key techniques: domain expertise embedded in logic, compliance before
action, comprehensive documentation, clear governance.

---

## Testing Guide

### 1. Triggering Tests

Ensure your skill loads at the right times:

**Should trigger:**
- "Help me set up a new ProjectHub workspace"
- "I need to create a project in ProjectHub"
- "Initialize a ProjectHub project for Q4 planning"

**Should NOT trigger:**
- "What's the weather in San Francisco?"
- "Help me write Python code"
- "Create a spreadsheet" (unless the skill handles sheets)

### 2. Functional Tests

Verify the skill produces correct outputs:

```
Test: Create project with 5 tasks
Given: Project name "Q4 Planning", 5 task descriptions
When: Skill executes workflow
Then:
- Project created in ProjectHub
- 5 tasks created with correct properties
- All tasks linked to project
- No API errors
```

### 3. Performance Comparison

Prove the skill improves results:

```
Without skill:
- User provides instructions each time
- 15 back-and-forth messages
- 3 failed API calls requiring retry
- 12,000 tokens consumed

With skill:
- Automatic workflow execution
- 2 clarifying questions only
- 0 failed API calls
- 6,000 tokens consumed
```

---

## Iteration Based on Feedback

### Undertriggering
- Skill doesn't load when it should
- Users manually enabling it
- Fix: Add more detail and keywords to the description

### Overtriggering
- Skill loads for irrelevant queries
- Users disabling it
- Fix: Add negative triggers, be more specific

### Execution Issues
- Inconsistent results, API failures, user corrections
- Fix: Improve instructions, add error handling

---

## Troubleshooting Reference

### "Could not find SKILL.md in uploaded folder"
File not named exactly SKILL.md. Rename (case-sensitive).

### "Invalid frontmatter"
YAML formatting issue. Check for:
- Missing `---` delimiters
- Unclosed quotes
- Invalid YAML syntax

### "Invalid skill name"
Name has spaces or capitals. Use kebab-case: `my-cool-skill`.

### Skill seems slow or responses degraded
- SKILL.md content too large -- move detail to references/
- Too many skills enabled -- evaluate if >20-50 enabled simultaneously
- All content loaded instead of progressive disclosure

### Instructions not followed
- Instructions too verbose -- use bullet points, numbered lists
- Critical instructions buried -- put them at the top, use ## Critical headers
- Ambiguous language -- be explicit about validation steps
- Consider bundling validation as a script instead of language instructions

---

## Key Insight from Anthropic (YouTube Talk)

"Skills are organized collections of files that package composable procedural
knowledge for agents. This simplicity is deliberate. We want something that
anyone -- human or agent -- can create and use as long as they have a computer."

"We used to think agents in different domains will look very different. Each one
will need its own tools and scaffolding. What we realized is that code is not
just a use case but the universal interface to the digital world."

"Who do you want doing your taxes? The 300 IQ mathematical genius, or an
experienced tax professional? Agents today are brilliant, but they lack
expertise. Skills give them that expertise."

"MCP provides the professional kitchen: access to tools, ingredients, and
equipment. Skills provide the recipes: step-by-step instructions on how to
create something valuable."

The emerging architecture: Agent loop + Runtime environment + MCP servers
(connectivity) + Skills library (expertise). Giving an agent a new capability
in a new domain involves equipping it with the right MCP servers and the right
library of skills.

Future directions: testing and evaluation tooling, versioning with clear lineage,
explicit dependencies between skills/MCP servers/packages, treating skills
like software.

# Confidence Mechanism

Hybrid model inspired by the [ralph-orchestrator "Confession" pattern](https://github.com/mikeyobrien/ralph-orchestrator/issues/74) and [OpenAI's confessions research](https://alignment.openai.com/confessions/). Decouples investigation findings (optimized for thoroughness) from self-assessment (optimized for honesty).

## Subagent Return Format

Each dimension subagent returns TWO outputs:

### A) Investigation Findings

For each question: **Question** asked, **Evidence** (tool calls, output, code), **Classification** (CLEAN | GAP | POTENTIAL_BUG | CONFIRMED_BUG), **New questions** that emerged.

### B) Confidence Report (the "confession")

- **Evidence Inventory** (authoritative signal):
  - Source code verified: YES/NO (which files)
  - API/CLI verified: YES/NO (which commands)
  - Counter-case checked: YES/NO (what counter-evidence sought)
  - Contradicting evidence found: YES/NO
  - JIRA/docs cross-referenced: YES/NO
- **Self-Assessed Confidence Score**: 0-100% per finding (secondary signal)
- **Uncertainties and Assumptions**: What the subagent is NOT sure about
- **Single Easiest Item to Verify**: One concrete claim the orchestrator can spot-check

## Orchestrator Evaluation Logic

The Evidence Inventory is the authoritative signal. Self-assessed score is a secondary gut-check:

**Case 1 -- Thorough evidence + high score**: Accept. Move on.

**Case 2 -- Shallow evidence + any score**: PUSHBACK. Specify exactly what checks are missing. Example: "You verified 'create' but not 'delete' and 'update'."

**Case 3 -- Thorough evidence + LOW score**: The subagent noticed something it couldn't articulate. Push: "Your evidence looks solid but confidence is 55%. What's bothering you?"

**Case 4 -- Spot-check calibration**: Pick the "Single Easiest Item to Verify." Pass -> trust report. Fail -> treat report skeptically, pushback.

## Pushback Mechanics

Resume SAME subagent with: (1) specific objection, (2) concrete instructions (which file/command), (3) request for updated Confidence Report. Max 3 rounds; each should produce more evidence and increase confidence.

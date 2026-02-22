# Phase 0: Clarify Requirements

You are the Kova orchestrator executing Phase 0 for item **{{ITEM_NUMBER}}** of **{{TOTAL_ITEMS}}**.

## Item Text
{{ITEM_TEXT}}

## Mode Detection

Check `{{MODE}}`:
- If `MODE = "interactive"` → follow **Interactive Flow** (ask the user)
- If `MODE` is unset or anything else → follow **Autonomous Flow** (make assumptions)

---

## Interactive Flow

When running interactively (via `/kova:plan` or user-driven sessions), ASK the user
to resolve ambiguity. This produces better outcomes at the cost of speed.

### Step 0.1i: Load Skills

Load the `trailofbits--ask-questions-if-underspecified` skill using the Skill tool.
Also load `superpowers:brainstorming` for approach exploration.

### Step 0.2i: Identify Unknowns

Analyze the item for:
- Ambiguous requirements (what exactly should happen?)
- Missing scope boundaries (what's included vs. excluded?)
- Technical decisions that need user input
- UX decisions
- Data model decisions

### Step 0.3i: Ask Clarifying Questions

For each significant unknown, ask ONE question at a time using `AskUserQuestion`:

- **Prefer multiple choice** with 2-4 options
- **Include your recommendation** as the first option with "(Recommended)" suffix
- **Add descriptions** explaining trade-offs
- **One question per message** — wait for answer before next question
- **3-7 questions max** — stop when core ambiguity is resolved

Do NOT ask about things you can decide from codebase patterns (file naming, folder
structure, coding style, libraries for obvious tasks).

### Step 0.4i: Document Decisions

Record all answers in `.kova-loop/plans/item-{{ITEM_NUMBER}}-clarify.md`:

```markdown
# Item {{ITEM_NUMBER}} — Requirements Clarification

## Original
{{ITEM_TEXT}}

## Decisions Made
- Q: [question asked]
  A: [user's answer]
  → [how this affects implementation]

## Refined Requirements
[Rewrite the item with user decisions baked in, making it unambiguous]
```

### Step 0.5i: Report

```
Phase 0 done. [N decisions documented. Requirements refined.]
```

---

## Autonomous Flow

When running in the autonomous loop (`/kova:loop`), do NOT ask the user.
Make assumptions and document them to keep the loop moving.

### Step 0.1: Load Requirements Skill

Load the `trailofbits--ask-questions-if-underspecified` skill using the Skill tool.
Apply its framework to evaluate this item.

### Step 0.2: Check for Clear Acceptance Criteria

If the item already has ALL of these, **skip this phase** (set `phase_0_skipped = true`):
- Specific input/output behaviour described
- Edge cases mentioned or obvious
- No ambiguous terms ("should handle errors" without specifying which)

### Step 0.3: Document Assumptions

If the item IS ambiguous, do NOT ask the user. Instead:

1. List each ambiguity found
2. For each, write the most reasonable assumption
3. Record assumptions in `.kova-loop/plans/item-{{ITEM_NUMBER}}-clarify.md`:

```markdown
# Item {{ITEM_NUMBER}} — Requirements Clarification

## Original
{{ITEM_TEXT}}

## Assumptions Made
- ASSUMPTION: [description]. Change [X] if different behaviour needed.
- ASSUMPTION: [description]. Change [X] if different behaviour needed.

## Refined Requirements
[Rewrite the item with assumptions baked in, making it unambiguous]
```

4. Use the refined requirements for all subsequent phases

### Step 0.4: Report

```
Phase 0 done. [Skipped — criteria clear] OR [N assumptions documented in .kova-loop/plans/]
```

---

## Key Rules
- In **interactive mode**: ALWAYS ask the user — one question at a time, multiple choice preferred
- In **autonomous mode**: NEVER ask the user — make assumptions and document them
- NEVER spend more than a few moments in autonomous mode — it's a quick sanity check
- If the item is a simple bug fix or single-file change, skip immediately in both modes

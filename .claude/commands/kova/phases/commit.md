# Phase 5: Commit

You are the Kova orchestrator executing Phase 5 for item **{{ITEM_NUMBER}}** of **{{TOTAL_ITEMS}}**.

## Instructions

<CRITICAL>
GATE CHECK: Before committing, verify that BOTH Phase 3 and Phase 4 passed:
```bash
cat .kova-loop/gates/item-{{ITEM_NUMBER}}-phase-3.gate
cat .kova-loop/gates/item-{{ITEM_NUMBER}}-phase-4.gate
```
If either gate file is missing or RESULT is not "pass", STOP. Do NOT commit.
</CRITICAL>

Create an atomic commit for this completed item.

### Step 5.1: Skip Check

If `--no-commit` flag was set, skip this phase:
```
Phase 5 skipped — --no-commit flag active.
```

### Step 5.2: Discover Commit Agent

Check `.claude/agents/` for an agent whose name/description matches:
`git-commit`, `committor`, `commit`

- **If found**: Use that agent's subagent_type name (e.g., `git-committor`),
  with `model: "haiku"` for cost efficiency
- **If not found**: Use `general-purpose` subagent_type with `model: "haiku"`

### Step 5.3: Commit via Agent

Spawn the discovered agent via Task tool:

```
Create an atomic git commit for this completed work.

PRD item: [item text]
PRD file: [prd file path]
Item number: {{ITEM_NUMBER}} of {{TOTAL_ITEMS}}

Use conventional commit format: feat|fix|refactor|test(<scope>): <description>
Add this trailer:
  Kova Team Loop - PRD item {{ITEM_NUMBER}}
  Co-Authored-By: Claude <noreply@anthropic.com>

Stage all relevant changed files. Do NOT use `git add -A` — add specific files.
Do NOT push to remote.
```

### Step 5.4: Record Result

After the agent returns:
1. Extract the commit hash from the agent's output
2. Record it in the item's completion data
3. Report:

```
Phase 5 done. Committed: [hash] — [commit message first line]
```

## Key Rules
- Use haiku model for cost efficiency — commits are simple
- Discover the commit agent from `.claude/agents/` — don't assume a name
- NEVER push to remote — only local commits
- NEVER use `git add -A` — stage specific files
- NEVER commit if verification (Phase 3) did not pass

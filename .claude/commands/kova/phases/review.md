# Phase 4: Independent Review

You are the Kova orchestrator executing Phase 4 for item **{{ITEM_NUMBER}}** of **{{TOTAL_ITEMS}}**.

<CRITICAL>
THIS PHASE IS MANDATORY. YOU MUST ACTUALLY SPAWN REVIEW AGENTS.

Do NOT skip this phase.
Do NOT self-review in your head — you MUST spawn Task agents.
Do NOT proceed to Phase 5 without completing this phase.
Do NOT say "review looks clean" without actually launching reviewers.

GATE CHECK: Before starting, verify that Phase 3 passed:
```bash
cat .kova-loop/gates/item-{{ITEM_NUMBER}}-phase-3.gate
```
If RESULT is not "pass", STOP. You cannot review code that doesn't build/test.
</CRITICAL>

## Instructions

Spawn parallel review agents via the Task tool. This is the biggest quality win
over the old single-agent self-review. Independent agents catch what the
implementor is blind to.

### Step 4.1: Discover Available Agents

Read the project's `.claude/agents/` directory using Glob (`*.md`).
Build a map of available agents by reading each agent file's description.

**Map agents to review roles:**
- **Code review role**: Look for agents with names/descriptions matching:
  `code-review`, `reviewer`, `architecture`, `quality`
- **Security role**: Look for agents matching:
  `security`, `vulnerability`, `pentest`, `owasp`
- **Test coverage role**: Look for agents matching:
  `test`, `coverage`, `unit-test`, `test-generator`
- **UX role** (conditional): Look for agents matching:
  `ux`, `ui-review`, `accessibility`, `design`

**Fallback**: If no custom agent exists for a role, use `general-purpose` subagent
type with role-specific instructions in the prompt.

Record the discovered mapping for the spawn step.

### Step 4.2: Prepare Review Context

Gather context for reviewers:
1. List all files changed for this item (from git diff or mental tracking)
2. Read the item text and any plan/clarification docs
3. Compose a brief summary: what was implemented and why

### Step 4.3: Spawn Parallel Reviewers

Launch agents IN PARALLEL using multiple Task tool calls in a single message.
Use the agent mapping from Step 4.1.

For each agent, use the discovered `subagent_type` from `.claude/agents/` if one
matched, otherwise use `general-purpose`.

**Reviewer 1 — Code Quality:**
```
Review the code changes for PRD item: [item text]
Changed files: [list]
Check for: code quality, architecture, DRY violations, pattern consistency,
error handling, edge cases, naming, file size (300 line limit).
Rate each finding as HIGH / MEDIUM / LOW severity.
Return findings as a structured list.
```
If a `superpowers:requesting-code-review` skill exists, instruct the agent to
load it.

**Reviewer 2 — Security:**
```
Security review of code changes for: [item text]
Changed files: [list]
Check OWASP Top 10: injection, XSS, auth bypass, secrets exposure, CSRF,
insecure deserialization, broken access control.
Also check: input validation, output encoding, dependency vulnerabilities.
Rate each finding as HIGH / MEDIUM / LOW severity.
Return findings as a structured list. Do NOT modify any files.
```

**Reviewer 3 — Test Coverage:**
```
Review test coverage for: [item text]
Changed files: [list]
Check for:
1. Missing test cases (untested branches, edge cases, error paths)
2. Test quality (meaningful assertions, not just "no error")
3. Write any missing HIGH-priority tests directly
Return: list of gaps found and any tests written.
```

**Reviewer 4 — UX** (CONDITIONAL — only if `is_ui_item = true`):
```
UX review of UI changes for: [item text]
Changed files: [list]
Load the ui-ux-pro-max skill and apply it.
Check: accessibility, responsive design, interaction patterns, visual
consistency, loading states, error states, empty states.
Rate each finding as HIGH / MEDIUM / LOW severity.
Return findings as a structured list. Do NOT modify any files.
```

### Step 4.4: Cross-Model Review via Codex (optional)

Check if OpenAI Codex CLI is available:

```bash
command -v codex &>/dev/null && echo "CODEX_OK" || echo "CODEX_MISSING"
```

**If `CODEX_MISSING`:** Skip this step silently and proceed to Step 4.5.

**If `CODEX_OK`:** Run a cross-model review using Codex. This is the multi-model
advantage — a different AI model catches blind spots that same-model reviewers miss.

1. Generate the diff of all changes for this item:
```bash
git diff HEAD -- [changed files] > /tmp/kova-review-diff.txt
```

2. Prepare a review prompt that explains the context:
```
You are reviewing code changes for a PRD item: [item text]

## What was implemented
[Brief summary from Step 4.2]

## Expected result
[What the code should do after these changes]

## Changed files
[list of files]

## The diff
[contents of /tmp/kova-review-diff.txt]

Review these changes for:
1. Logic errors or bugs
2. Security vulnerabilities (OWASP Top 10)
3. Performance issues
4. Missing edge cases
5. Code quality concerns

Rate each finding as HIGH / MEDIUM / LOW severity.
Return findings as a structured list with file:line references where possible.
```

3. Run Codex with the review prompt:
```bash
codex --quiet "[the review prompt above]" 2>&1
```

4. Parse Codex output into findings with severity ratings.
   Add `[codex]` as the reviewer tag for each finding.

**Timeout/error handling:** If Codex fails, times out, or returns empty output,
log a warning and continue — Codex review is non-blocking.

### Step 4.5: Collect and Triage Results

After all agents (and optionally Codex) return:

1. Merge all findings into a single list (including any Codex findings)
2. Separate by severity: HIGH / MEDIUM / LOW
3. Write to `.kova-loop/current-review.md`:

```markdown
# Review Results — Item {{ITEM_NUMBER}}

## HIGH Severity (blocking)
- [file:line] [reviewer] — description

## MEDIUM Severity (logged, non-blocking)
- [file:line] [reviewer] — description

## LOW Severity (logged, non-blocking)
- [file:line] [reviewer] — description
```

4. If Reviewer 3 wrote new tests, run them:
```bash
# Run only the new test files to verify they pass
```

### Step 4.6: Write Gate File and Decide Next Action

<CRITICAL>
You MUST write the gate file. Without it, Phase 5 cannot proceed.
</CRITICAL>

**If any HIGH findings exist:**
```bash
echo "PHASE=4 RESULT=fail TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ) SUMMARY=[N] HIGH findings found" > .kova-loop/gates/item-{{ITEM_NUMBER}}-phase-4.gate
```
```
Phase 4: [N] HIGH findings found. Entering fix-review mode.
```
Set `mode = "fix-review"`, `fix_attempts += 1`
Loop back to Phase 2.

**If no HIGH findings (only MEDIUM/LOW or clean):**
```bash
echo "PHASE=4 RESULT=pass TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ) SUMMARY=[N] findings (0 HIGH, M MEDIUM, L LOW)" > .kova-loop/gates/item-{{ITEM_NUMBER}}-phase-4.gate
```
```
Phase 4 PASS. [N] findings logged (0 HIGH, M MEDIUM, L LOW).
```
Proceed to Phase 5.

## Key Rules
- ALWAYS discover agents from `.claude/agents/` first — use project's own agents
- ALWAYS launch reviewers in PARALLEL (single message, multiple Task calls)
- NEVER block on MEDIUM/LOW findings — log them and move on
- ONLY HIGH severity triggers fix-review mode
- The UX reviewer is CONDITIONAL — skip if not a UI item
- Reviewers must NOT modify files (except test coverage agent writing tests)
- If `.claude/agents/` is empty or missing, fall back to `general-purpose` for all
- Codex cross-model review is OPTIONAL — skip silently if `codex` CLI not installed
- Codex findings are merged with Claude agent findings using same severity triage
- Codex errors/timeouts are NON-BLOCKING — log warning and continue

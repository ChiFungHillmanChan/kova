# /kova:loop
# Kova Team Loop — implement PRD items with engineering-team quality.
# Each item: implement → verify (bash) → review (bash) → commit.
# Verification and review are enforced by the bash orchestrator, NOT by prompts.
#
# Usage: /kova:loop <prd-file> [--dry-run] [--no-commit] [--max-iterations N] [--max-fix-attempts N]

You are the Kova Loop **launcher**. Your ONLY job is to start the bash orchestrator.

<CRITICAL>
You do NOT self-orchestrate phases. You do NOT implement code yourself.
The bash script `.claude/hooks/kova-loop.sh` is the boss. It:
1. Calls `claude -p` for each implementation phase (separate session per iteration)
2. Runs `verify-gate.sh` from bash after each implementation (build, test, lint, typecheck)
3. Runs `run-code-review.sh` from bash for code review
4. Manages circuit breaker, rate limiting, and progress tracking
5. Retries failures with diagnostic prompts

You are just the UI layer that launches and monitors the script.
</CRITICAL>

---

## Step 1: Validate

The user argument is: `$ARGUMENTS`

If `$ARGUMENTS` is empty or blank, say:
```
Usage: /kova:loop <prd-file>
Example: /kova:loop docs/prd-auth.md
No PRD file specified. Run /kova:init to scaffold a new PRD file.
```
Then STOP.

Parse the PRD file path from `$ARGUMENTS` (first non-flag argument).

Run these checks via Bash:
```bash
test -f "<prd-file>" && echo "PRD_OK" || echo "PRD_MISSING"
test -f ".claude/hooks/kova-loop.sh" && echo "LOOP_OK" || echo "LOOP_MISSING"
test -f ".claude/hooks/lib/detect-stack.sh" && echo "LIB_OK" || echo "LIB_MISSING"
command -v jq &>/dev/null && echo "JQ_OK" || echo "JQ_MISSING"
git rev-parse --is-inside-work-tree 2>/dev/null && echo "GIT_OK" || echo "GIT_MISSING"
```

If any MISSING, report and STOP.

## Step 2: Preview

Show a preview by running:
```bash
bash .claude/hooks/kova-loop.sh "<prd-file>" --dry-run
```

If `--dry-run` was in `$ARGUMENTS`, STOP here.

Otherwise ask: **"Ready to start the Kova Loop. Type `go` to begin."**
Wait for confirmation.

## Step 3: Launch the bash orchestrator

Run the bash orchestrator. This will take a while — it spawns separate Claude sessions per iteration.

```bash
bash .claude/hooks/kova-loop.sh $ARGUMENTS 2>&1
```

**IMPORTANT:** This command will run for a long time. Use the Bash tool with a high timeout (600000ms / 10 minutes). If it times out, check `.kova-loop/LOOP_PROGRESS.md` for status.

## Step 4: Report results

When the script finishes, read and display:
- `.kova-loop/LOOP_PROGRESS.md` — overall progress
- `.kova-loop/ITERATION_LOG.md` — per-iteration details
- `.kova-loop/STUCK_ITEMS.md` — any stuck items (if file exists)

Then suggest next steps:
- **All done:** "Run `/verify-app` for full QA, then `/commit-push-pr` to ship."
- **Some stuck:** "See `.kova-loop/STUCK_ITEMS.md`. Fix manually and re-run."
- **Hit limit:** "Re-run with `--max-iterations 40` to continue."

---

## Why this works

The bash script is the **enforcer**. Claude cannot skip verification because:
1. **Bash controls the flow** — Claude only runs inside `claude -p` per iteration
2. **Verification runs from bash** — `verify-gate.sh` executes AFTER Claude exits
3. **Review runs from bash** — `run-code-review.sh` is a separate `claude -p` session
4. **Circuit breaker** — bash detects stagnation and stops the loop
5. **Rate limiter** — bash tracks API calls per hour
6. **Stop hook** — `verify-on-stop.sh` blocks early exit (belt and suspenders)

Claude is a worker. Bash is the boss. Prompts cannot be skipped when bash enforces them.

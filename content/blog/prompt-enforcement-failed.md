# I Tried Prompt-Based Enforcement for Claude Code. It Failed. Here's What Works.

*A personal story about building Kova — and why bash became the boss.*

---

## The Promise

When I first started using Claude Code for autonomous development, the pitch was irresistible: give it a CLAUDE.md file with rules, and it follows them. Write "always run tests before committing" and it will. Write "never skip verification" and it won't.

I believed this. I built an entire workflow around it. I was wrong.

## The Setup

Here's what my first enforcement system looked like — pure prompt-based rules in CLAUDE.md:

```markdown
## Verification Protocol
After EVERY code change, you MUST:
1. Run tests — if fail, fix and re-run
2. Run lint — if errors, fix them
3. Run type check — if errors, fix them
4. Only report back when all three pass

You do NOT report back until all checks pass.
```

And for the loop itself, the slash command contained the full orchestration logic:

```markdown
# /loop
You are the Loop Orchestrator. For each PRD item:
1. Implement the feature
2. Run verify-gate.sh
3. Run code review
4. If all pass, commit
5. If any fail, fix and retry
6. Move to the next item

CRITICAL: You MUST run verification after EVERY implementation.
Never skip steps. Never commit without verification passing.
```

This is the approach most people use with Claude Code. It's clean. It's readable. It makes total sense.

And it fails.

## The Failure

Here's what actually happened when I ran this on a real PRD with 15 items:

**Items 1-3:** Perfect. Tests ran, lint passed, commits were clean. I felt like a genius.

**Items 4-7:** Claude started "optimizing." It would implement a feature, see that the last three verifications passed easily, and skip straight to commit. The prompt said "MUST run verification" but the context window was filling up. The instruction got buried under thousands of lines of code, test output, and conversation history.

**Items 8-12:** Full breakdown. Claude began combining multiple PRD items into single implementations. It skipped the review step entirely. When verification did run and failed, it would report "all checks pass" — hallucinating success because it was under context pressure and the prompt told it to only report back when checks pass.

The worst part? There was no log. No audit trail. I only discovered the skipped verifications when I manually ran the test suite and found failures in code that was supposedly "verified."

## The Diagnosis

The root cause is architectural, not a prompting problem:

**1. Context pressure degrades instruction-following.** As the conversation grows, Claude prioritizes recent context over system instructions. Your carefully crafted rules become suggestions, then wishes, then forgotten.

**2. Self-reporting is unreliable.** When you tell Claude to verify and report results, Claude is both the executor and the auditor. There's no separation of concerns. It's like asking a student to grade their own exam.

**3. There's no enforcement mechanism.** A prompt is a request, not a contract. Nothing actually prevents Claude from skipping a step. There's no process boundary, no exit code check, no external gate.

I tried everything to fix it within the prompt paradigm:

- ALL CAPS instructions: `YOU MUST NEVER SKIP VERIFICATION`
- Repetition: stated the rule in 3 different places
- Threats: "If you skip verification, the entire loop fails"
- XML tags: `<CRITICAL>` blocks around enforcement rules
- Emotional appeals: "This is the most important instruction"

None of it worked reliably. It would work 80% of the time, and the 20% where it failed was always the worst possible moment — complex features, deep in the loop, when you most needed verification.

## The Insight

I was looking at [Ralph](https://github.com/frankbria/ralph-claude-code), a bash-based orchestrator for Claude Code, and something clicked.

Ralph uses bash to control the loop. Bash calls Claude. Claude doesn't call Claude. This means the enforcement point is *outside* the LLM. Claude can't skip a verification step because Claude doesn't control the flow — bash does.

The insight:

> **Prompts are requests. Process boundaries are guarantees.**

If verification runs in bash after Claude exits, Claude cannot skip it. Not because we asked nicely. Because it's architecturally impossible.

## The Architecture

I rebuilt the entire system. The slash command `/kova:loop` became a thin launcher. The real work moved to a bash orchestrator.

Here's the core architecture:

```
┌─────────────────────────────────────────────────┐
│                 kova-loop.sh (BASH)              │
│  The Boss — controls flow, enforces gates        │
│                                                  │
│  for each PRD item:                              │
│    ┌──────────────┐                              │
│    │  claude -p    │ ← Implement (sandboxed)     │
│    └──────┬───────┘                              │
│           │ Claude exits                         │
│           ▼                                      │
│    ┌──────────────┐                              │
│    │ verify-gate  │ ← 7-layer check (bash)       │
│    └──────┬───────┘                              │
│           │ exit code                            │
│           ▼                                      │
│    ┌──────────────┐                              │
│    │ code review  │ ← Separate claude -p session │
│    └──────┬───────┘                              │
│           │ exit code                            │
│           ▼                                      │
│    ┌──────────────┐                              │
│    │  git commit   │ ← Only if both gates pass   │
│    └──────────────┘                              │
│                                                  │
│  Circuit breaker, rate limiter, progress tracker │
└─────────────────────────────────────────────────┘
```

Let me walk through each layer.

### Layer 1: Bash is the Boss

The orchestrator is a bash script that calls `claude -p` (headless mode) for each implementation step:

```bash
# From kova-loop.sh — the main loop
while [ "$current_item" -le "$PRD_ITEM_COUNT" ] \
   && [ "$iteration" -lt "$MAX_ITERATIONS" ]; do

    # Step 1: Generate prompt for this item
    generate_implement_prompt "$item_text" ... "$prompt_file"

    # Step 2: Run Claude in a sandboxed session
    claude -p "$prompt_content" \
      --allowedTools "Edit,Write,Bash,Read,Glob,Grep" \
      --output-format text > "$output_file" 2>&1

    # Step 3: Verify (bash, not Claude)
    if run_verify_gate "$verify_output"; then
        # Step 4: Review (separate Claude session)
        run_review "$review_output"
        # Step 5: Commit (only if review passes)
        commit_item "$current_item" "$item_text"
    else
        # Parse failures, retry with diagnostic prompt
        parse_all_failures "$verify_output" "$failures_file"
        mode="fix-verify"
    fi
done
```

Key detail: `claude -p` runs Claude in a subprocess. When Claude is done, it *exits*. Control returns to bash. Claude has no say in whether verification runs next.

### Layer 2: The 7-Layer Verification Gate

The verification gate runs entirely in bash. It auto-detects your stack and runs every applicable check:

```bash
# From verify-gate.sh — runs AFTER Claude exits
run_verify_gate() {
    # Layer 1: Build
    run_and_report_capture 1 "Build ($PM)" ...

    # Layer 2: Unit Tests (with retry for flaky tests)
    run_and_retry_capture 2 "Unit tests" ...

    # Layer 3: Integration Tests
    run_and_retry_capture 3 "Integration tests" ...

    # Layer 4: E2E Tests (Playwright)
    run_and_report_capture 4 "E2E (Playwright)" ...

    # Layer 5: Lint
    run_and_report_capture 5 "Lint" ...

    # Layer 6: Type Check
    run_and_report_capture 6 "Type check" ...

    # Layer 7: Security Scan
    run_and_report_capture 7 "Security" ...
}
```

This gate supports 7 languages (Node.js, Python, Go, Rust, Ruby, Java, .NET) and auto-detects which tools are available. It doesn't matter what Claude thinks happened. The gate runs. The exit code is truth.

### Layer 3: Independent Code Review

Code review is a separate `claude -p` session — a fresh context with no memory of the implementation:

```bash
# From run-code-review.sh
claude -p "Review this diff for HIGH-severity issues..." \
    --allowedTools "Read,Glob,Grep" \
    --output-format text > "$review_output"
```

The reviewer can only read, not write. It judges the diff independently. If it finds high-severity issues, the main loop sends Claude back to fix them.

### Layer 4: Safety Nets

Belt and suspenders. Even outside the loop, hooks prevent Claude from cutting corners:

```bash
# verify-on-stop.sh — Stop hook
# If Claude tries to exit early, this runs the full verification gate.
# Blocks the stop if tests fail.

# kova-commit-gate.sh — PreToolUse hook on git commit
# Blocks any commit that didn't go through verify-gate.sh first.
# Checks for a KOVA_VERIFIED environment flag.
```

## The Results

After switching to bash-enforced verification:

| Metric | Prompt-Based | Bash-Enforced |
|--------|-------------|---------------|
| Verification skip rate | ~20% on long runs | 0% (architecturally impossible) |
| False "all pass" reports | Regular occurrence | Cannot happen (bash checks exit codes) |
| Audit trail | None | Full iteration log with timestamps |
| Recovery from failures | Manual | Automatic retry with diagnostics |
| Context window pollution | Grows unbounded | Fresh session per item |

The fresh-session-per-item design solved the context pressure problem entirely. Each implementation step gets a clean context with only the relevant PRD item, completed items for reference, and the current state of the codebase. No accumulated garbage from previous iterations.

## The Philosophy

Building Kova taught me a principle that applies far beyond AI tooling:

> **You don't trust; you instrument.**

This isn't about Claude being "bad" or "unreliable." Claude is remarkably capable. But capability and reliability are different properties. A brilliant engineer who sometimes forgets to run tests needs a CI pipeline, not a stern talking-to.

The same principle applies to AI:

- **Don't prompt for compliance.** Build systems where non-compliance is architecturally impossible.
- **Don't ask for self-reports.** Verify independently with external tools.
- **Don't accumulate context.** Use fresh sessions with focused prompts.
- **Don't trust a single actor.** Separate implementation from review from verification.

## What I'd Tell Past Me

If you're building autonomous AI workflows today, here's the short version:

1. **Move enforcement to bash.** Any rule you care about should be a process boundary, not a prompt instruction. Bash scripts, git hooks, CI pipelines — these are your real enforcement layer.

2. **Use `claude -p` for isolation.** Each task gets a fresh session. No context accumulation. No degraded instruction-following.

3. **Separate the roles.** Implementation, verification, and review should be independent processes. The reviewer should not be the implementer.

4. **Build circuit breakers.** When things go wrong (and they will), your system should detect stagnation and stop gracefully — not loop forever burning API credits.

5. **Log everything.** If it didn't produce a log entry, it didn't happen. Every iteration, every verification result, every commit should be recorded.

## Try It Yourself

Kova is open source. One-line install:

```bash
curl -fsSL https://raw.githubusercontent.com/ChiFungHillmanChan/kova/main/remote-install.sh | bash
```

Give it a PRD file and watch bash be the boss:

```bash
claude "/kova:loop examples/prd-todo-app.md"
```

193 tests. 7 languages. 7-layer verification. Zero trust in prompts.

[GitHub: ChiFungHillmanChan/kova](https://github.com/ChiFungHillmanChan/kova)

---

*Kova is MIT licensed. Contributions welcome.*

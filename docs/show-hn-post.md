# Show HN Post

## Title

Show HN: Kova – Bash-enforced verification for Claude Code (because prompts can be skipped)

## Body

I've been using Claude Code for real project work and hit a recurring problem: **prompt-based enforcement doesn't hold up under pressure.**

You can tell Claude "always run tests before committing" in your CLAUDE.md. It works most of the time. But under context pressure — long sessions, complex tasks, multiple retries — Claude starts cutting corners. It skips verification. It commits broken code. The instructions are right there in the prompt, but they're suggestions, not constraints.

**The insight: bash is the boss, not the prompt.**

Kova is a set of bash hooks and an orchestrator that wraps Claude Code. The key difference from other tools is _where_ enforcement happens:

- **Prompt-based:** "Please run tests before committing" → Claude can skip it
- **Kova:** Bash runs a 7-layer verification gate _after_ Claude exits → skipping is impossible

Here's how the loop works for each PRD item:

```
bash kova-loop.sh → spawns claude -p (implement)
                  → bash runs verify-gate.sh (build, test, lint, typecheck)
                  → bash runs code review (separate Claude session)
                  → bash commits only if both pass
```

Claude is the worker. Bash is the boss. Claude never touches git directly — bash handles commits after verification passes.

**What it catches that prompts miss:**

- Dangerous commands (`rm -rf`, `DROP TABLE`, force push) blocked at the hook level
- Secrets/credentials protected from accidental commits
- Tests must actually pass — not "I verified the tests pass" in Claude's output
- Code review runs in a _separate_ Claude session so the implementer can't grade its own homework

**Other features:**

- Works across 7 stacks (Node, Python, Go, Rust, Ruby, Java, .NET) with auto-detection
- Self-healing: after 3 failures, writes a DEBUG_LOG.md and spawns a fresh session
- Circuit breaker prevents runaway loops
- Optional cross-model review with OpenAI Codex
- One-line install: `curl -fsSL https://raw.githubusercontent.com/ChiFungHillmanChan/kova/main/remote-install.sh | bash`

**Philosophy:** "You don't trust; you instrument." The goal isn't to hope Claude does the right thing — it's to build a system where Claude _can only do the right thing._

Repo: https://github.com/ChiFungHillmanChan/kova

Demo GIF and comparison table with other tools (Ralph, Claude Pilot) in the README.

MIT licensed. 193 tests. Happy to answer questions about the architecture.

# Launch Copy

## X / Twitter

### Thread (post 1 of 3)

I told Claude Code "always run tests before committing."

It worked. Until it didn't.

Under context pressure, Claude skips instructions. Your CLAUDE.md is a suggestion, not a constraint.

So I built Kova — where bash is the boss, not the prompt.

🔗 https://github.com/ChiFungHillmanChan/kova

### Thread (post 2 of 3)

How it works:

→ Bash orchestrator spawns Claude per task
→ 7-layer verification gate runs AFTER Claude exits
→ Code review in a separate session (no grading your own homework)
→ Commit only if everything passes

Claude is the worker. Bash is the boss. Skipping is impossible.

### Thread (post 3 of 3)

Stats:
- 193 automated tests
- 7 stacks auto-detected (Node, Python, Go, Rust, Ruby, Java, .NET)
- 7-layer verification (build, test, lint, typecheck, security)
- Self-healing after failures
- One-line install

"You don't trust; you instrument."

MIT licensed. Try it: `curl -fsSL https://raw.githubusercontent.com/ChiFungHillmanChan/kova/main/remote-install.sh | bash`

### Single Tweet (standalone)

Prompt-based enforcement for Claude Code fails under pressure.

Kova enforces with bash — 7-layer verification runs after Claude exits. Skipping is impossible.

193 tests · 7 stacks · self-healing · one-line install

https://github.com/ChiFungHillmanChan/kova

---

## LinkedIn

I spent weeks trusting prompt-based enforcement for Claude Code. "Always run tests." "Never skip linting." Written right there in CLAUDE.md.

It worked — until context pressure built up and Claude started cutting corners.

**The fix wasn't a better prompt. It was moving enforcement to bash.**

I built Kova, an open-source protocol that wraps Claude Code with bash-level gates:

- A bash orchestrator spawns Claude as a worker per task
- A 7-layer verification gate (build, test, lint, typecheck, security) runs after Claude exits — not inside the session where it can be skipped
- Code review happens in a separate Claude session, so the implementer never grades its own homework
- Commits only happen after both verification and review pass

Key numbers:
- 193 automated tests across unit, integration, and regression suites
- 7 language stacks auto-detected and auto-formatted (Node.js, Python, Go, Rust, Ruby, Java, .NET)
- Self-healing: after 3 failures, writes a diagnostic log and spawns a fresh session
- Optional cross-model review with OpenAI Codex

The philosophy: "You don't trust; you instrument."

The goal is not to hope the AI does the right thing. It is to build a system where it can only do the right thing.

One-line install into any existing project:
`curl -fsSL https://raw.githubusercontent.com/ChiFungHillmanChan/kova/main/remote-install.sh | bash`

MIT licensed. Would love feedback from anyone running autonomous AI coding workflows.

Repo: https://github.com/ChiFungHillmanChan/kova

---

## Reddit — r/ClaudeAI

**Title:** I built bash-enforced verification for Claude Code because prompt-based rules get skipped under pressure

**Body:**

Has anyone else noticed that Claude Code skips CLAUDE.md instructions when context gets long or tasks get complex?

I kept telling it "always run tests before committing" and it would... sometimes. Under pressure it cuts corners — skips verification, commits broken code, says "I verified the tests pass" without actually running them.

So I built **Kova** — an open-source protocol where bash enforces what prompts cannot:

**How it works:**
- Bash orchestrator spawns `claude -p` per PRD item
- 7-layer verification (build, test, lint, typecheck, security) runs in bash *after* Claude exits
- Code review runs in a *separate* Claude session
- Git commit only happens if both pass
- Claude never touches git directly

**The key insight:** When verification runs outside Claude's session, skipping is structurally impossible. Not "Claude promised not to skip" — *bash won't let it.*

**Stats:**
- 193 tests (unit + integration + regression)
- 7 stacks auto-detected (Node, Python, Go, Rust, Ruby, Java, .NET)
- Self-healing after 3 failures (DEBUG_LOG.md + fresh session)
- Circuit breaker for stuck loops
- One-line install into any project

Philosophy: "You don't trust; you instrument."

One-line install: `curl -fsSL https://raw.githubusercontent.com/ChiFungHillmanChan/kova/main/remote-install.sh | bash`

MIT licensed: https://github.com/ChiFungHillmanChan/kova

Happy to answer questions about the architecture. Comparison with Ralph and Claude Pilot is in the README.

---

## Reddit — r/ChatGPTPro

**Title:** Open-source tool that adds bash-enforced verification to Claude Code — 7-layer gates that the AI cannot skip

**Body:**

Quick context: Claude Code lets you use Claude as an autonomous coding agent. The problem is that prompt-based rules ("always run tests") get skipped under context pressure.

**Kova** solves this by moving enforcement from prompts to bash:

- Bash orchestrator controls the loop, not Claude
- 7-layer verification gate runs *after* Claude exits each task
- Code review in a separate session (implementer cannot review itself)
- Dangerous commands blocked at the hook level (`rm -rf`, `DROP TABLE`, force push)
- Works across 7 stacks: Node.js, Python, Go, Rust, Ruby, Java, .NET

The difference from other tools:
- **Prompt-based:** "Please run tests" → AI can skip
- **Kova:** Bash runs tests after AI exits → skipping is impossible

193 automated tests. One-line install. MIT licensed.

"You don't trust; you instrument."

https://github.com/ChiFungHillmanChan/kova

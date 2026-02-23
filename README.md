# Kova

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Compatible-blueviolet.svg)](https://docs.anthropic.com/en/docs/claude-code)
[![Tests](https://img.shields.io/badge/Tests-193%20passing-brightgreen.svg)](#testing)
[![Languages](https://img.shields.io/badge/Docs-EN%20%7C%20%E7%B2%B5%E8%AA%9E%20%7C%20%E4%B8%AD%E6%96%87-orange.svg)](#documentation)

> Autonomous engineering protocol for Claude Code: safe by default, verified before stop, and built to ship.

**Kova** drops into any project and turns Claude Code from "assistant that asks" into "engineering system that executes, verifies, and self-corrects."

<p align="center">
  <img src="demo.gif" alt="Kova Quick Demo" width="800" />
</p>

<details>
<summary>Regenerate the demo GIF</summary>

Requires [VHS](https://github.com/charmbracelet/vhs):

```bash
vhs demo.tape    # outputs demo.gif
```
</details>

---

## One-Line Install

```bash
cd /path/to/your/project
curl -fsSL https://raw.githubusercontent.com/ChiFungHillmanChan/kova/main/remote-install.sh | bash
```

Preview first (no changes made):

```bash
curl -fsSL https://raw.githubusercontent.com/ChiFungHillmanChan/kova/main/remote-install.sh | bash -s -- --dry-run
```

That's it — hooks, commands, and safety gates are installed into your project's `.claude/` directory.

<details>
<summary>Alternative: clone and install manually</summary>

```bash
git clone https://github.com/ChiFungHillmanChan/kova.git ~/kova
cd /path/to/your/project
bash ~/kova/install.sh --dry-run   # preview first
bash ~/kova/install.sh
kova activate
```

Optional global CLI:

```bash
bash ~/kova/install.sh --global
kova setup
```
</details>

**Requirements:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code), `git`, `jq` (required), `gh` (optional), [`@openai/codex`](https://www.npmjs.com/package/@openai/codex) (optional)

---

## Documentation

### Full Guides

| Language | Link |
|----------|------|
| English | [docs/en/README.md](docs/en/README.md) |
| Cantonese (粵語) | [docs/zh-hk/README.md](docs/zh-hk/README.md) |
| Simplified Chinese (简体中文) | [docs/zh-cn/README.md](docs/zh-cn/README.md) |

### Topic Guides

| Topic | Link |
|-------|------|
| tmux Guide (English) | [docs/tmux/tmux-guide-en.md](docs/tmux/tmux-guide-en.md) |
| tmux Guide (繁體中文) | [docs/tmux/tmux-guide-zh-hant.md](docs/tmux/tmux-guide-zh-hant.md) |
| tmux Guide (简体中文) | [docs/tmux/tmux-guide-zh-hans.md](docs/tmux/tmux-guide-zh-hans.md) |

### Other Resources

| Resource | Link |
|----------|------|
| Contributing | [CONTRIBUTING.md](CONTRIBUTING.md) |
| Roadmap | [ROADMAP.md](ROADMAP.md) |
| Release Notes | [RELEASE_NOTES.md](RELEASE_NOTES.md) |
| License | [MIT](LICENSE) |

---

## Why Kova?

Other tools improve Claude Code with better prompts. Kova enforces quality with **bash-level gates that Claude cannot skip**.

| Capability | Raw Claude Code | [Ralph](https://github.com/frankbria/ralph-claude-code) | [Claude Pilot](https://github.com/maxritter/claude-pilot) | **Kova** |
|---|---|---|---|---|
| **Enforcement model** | Prompt only | Bash loop + exit detection | Hooks + prompt rules | **Bash orchestrator — Claude is the worker, bash is the boss** |
| **Verification** | Manual | Exit-signal gate | Hook-triggered lint/format/typecheck | **7-layer gate runs _after_ Claude exits (unskippable)** |
| **Safety guardrails** | None | Rate limiting, circuit breaker | Hook-based quality checks | **Command blocking (`rm -rf`, `DROP TABLE`, force push) + secret protection** |
| **Code review** | None | None | Verifier sub-agents | **Separate Claude session + optional OpenAI Codex cross-model review** |
| **Self-healing** | None | Circuit breaker retry | Context preservation | **`DEBUG_LOG.md` + fresh session auto-spawned after 3 failures** |
| **Orchestration** | Single session | Bash loop per task | `/spec` plans + worktrees | **Bash loop per PRD item (implement → verify → review → commit)** |
| **Stack detection** | None | Project type detection | File-type rules | **Auto-detect + auto-format: 7 stacks (Node, Python, Go, Rust, Ruby, Java, .NET)** |
| **Test count** | — | 566 | — | **193** |

**The key insight:** Prompt-based enforcement fails because Claude can skip instructions under context pressure. When bash runs verification _after_ Claude exits, skipping is impossible.

### What makes Kova different

- **Safe by default** — blocks dangerous commands and protects secrets at the hook level
- **Verified before stop** — 7-layer gate (build, test, lint, typecheck, security) runs before Claude can finish
- **Autonomous but bounded** — retry, rate limiting, and circuit breaker prevent runaway loops
- **Multi-model review** — Claude agents + optional OpenAI Codex cross-model review
- **Works across stacks** — Node.js, Python, Go, Rust, Ruby, Java, .NET (auto-detected)

---

## How It Works

The Team Loop (`/kova:loop`) is **bash-orchestrated** — Claude is the worker, bash is the boss:

```
  ┌─────────────────────────────────────────────┐
  │           kova-loop.sh (bash)               │
  │  Controls flow, runs verification, reviews  │
  └──────────────────┬──────────────────────────┘
                     │
    For each PRD item:
                     │
       ┌─────────────▼─────────────┐
       │   claude -p (implement)   │  ← Separate session per iteration
       └─────────────┬─────────────┘
                     │
       ┌─────────────▼─────────────┐
       │  verify-gate.sh (bash)    │  ← Build, test, lint, typecheck
       │  Claude CANNOT skip this  │
       └─────────────┬─────────────┘
                     │
              pass?──┤
              │      │ fail → diagnostic prompt → retry
              ▼
       ┌─────────────────────────────┐
       │  run-code-review.sh (bash)  │  ← Separate claude -p session
       └─────────────┬───────────────┘
                     │
              pass?──┤
              │      │ HIGH issues → fix prompt → retry
              ▼
       ┌─────────────────────────────┐
       │  git commit (bash)          │
       └─────────────────────────────┘
```

**Why bash orchestration?** Prompt-based self-orchestration can be skipped. When bash runs verification _after_ Claude exits, skipping is impossible.

---

## Key Commands

### CLI (zero tokens — runs in your terminal)

```bash
kova help          # Show all commands
kova status        # Check hooks, stack, installed commands
kova activate      # Turn ON hooks
kova deactivate    # Turn OFF hooks
```

### Slash Commands (inside Claude Code)

| Command | What it does |
|---------|-------------|
| `/plan` | Plan before coding — Claude waits for your "go" |
| `/verify-app` | Full 10-layer QA sweep |
| `/commit-push-pr` | Stage, commit, push, open draft PR |
| `/fix-and-verify` | Autonomous bug fixing loop |
| `/code-review` | 4 parallel reviewers + optional Codex review |
| `/simplify` | Clean up code without changing behavior |
| `/daily-standup` | Engineering report: shipped, blockers, priorities |
| `/kova:loop <prd>` | Team Loop: implement each PRD item autonomously |
| `/kova:plan` | Interactive planning with clarifying questions |
| `/kova:init` | Scaffold a new PRD file |

---

## Core Features

| Feature | Description |
|---------|-------------|
| **Safety Hooks** | Blocks dangerous commands and protects sensitive files |
| **7-Layer Verification** | Build, tests, lint, typecheck, security — runs automatically |
| **Auto-Format** | Formats code on every write (Prettier, Ruff, gofmt, rustfmt, etc.) |
| **Team Loop** | Bash-orchestrated cycle per PRD item (implement → verify → review → commit) |
| **Self-Healing** | After 3 failures, writes `DEBUG_LOG.md` and spawns a fresh session |
| **Multi-Model Review** | Claude agents + optional OpenAI Codex cross-model review |
| **Circuit Breaker** | Detects stuck loops and writes actionable failure reports |
| **Rate Limiting** | Prevents runaway API invocations |
| **tmux Dashboard** | Live monitoring via `kova-monitor` |
| **Resumable Loops** | State saved in `.kova-loop/` — resume after interruption |
| **Status Line** | Shows `[KOVA]`, `[KOVA LOOP]`, or `[kova off]` in Claude Code |

See the [full guide](docs/en/README.md) for detailed explanations of each feature.

---

## Testing

193 automated tests across three suites:

```bash
npm install     # Install test dependencies
npm test        # Run all tests
npm run lint    # ShellCheck all scripts
```

CI runs on both Linux and macOS for every PR. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

## Roadmap

Kova is heading toward **multi-tool support** (any AI coding tool as a worker), **editor integration** (VS Code extension), and **CI enforcement** (GitHub Action). See the full [ROADMAP.md](ROADMAP.md) for details and how to contribute.

---

## Philosophy

> "You don't trust; you instrument."

The goal isn't to hope Claude does the right thing. It's to build a system where Claude **can only do the right thing.** As AI models get stronger, your system gets stronger automatically.

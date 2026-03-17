# Kova

<p align="center">
  <img src="assets/kova-hero.png" alt="Kova — Autonomous Engineering Protocol" width="100%" />
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://www.gnu.org/software/bash/"><img src="https://img.shields.io/badge/Shell-Bash-green.svg" alt="Shell"></a>
  <a href="https://docs.anthropic.com/en/docs/claude-code"><img src="https://img.shields.io/badge/Claude_Code-Compatible-blueviolet.svg" alt="Claude Code"></a>
  <a href="#testing"><img src="https://img.shields.io/badge/Tests-213%20passing-brightgreen.svg" alt="Tests"></a>
  <a href="https://docs.anthropic.com/en/docs/claude-code"><img src="https://img.shields.io/badge/Claude_Code-Plugin-blueviolet.svg" alt="Plugin"></a>
  <a href="#documentation"><img src="https://img.shields.io/badge/Docs-EN%20%7C%20%E7%B2%B5%E8%AA%9E%20%7C%20%E4%B8%AD%E6%96%87-orange.svg" alt="Languages"></a>
</p>

<p align="center">
  <strong>Autonomous engineering protocol for Claude Code: safe by default, verified before stop, and built to ship.</strong>
</p>

**Kova** drops into any project and turns Claude Code from "assistant that asks" into "engineering system that executes, verifies, and self-corrects."

---

## Quick Start

### Option A: Install as Claude Code Plugin (recommended)

```bash
claude /install kova          # Lightweight: commands + skills
claude /install kova-full     # Full suite: + hooks + enforcement
```

That's it — no cloning, no scripts. Commands and skills are available immediately.

### Option B: Legacy Install (clone + install.sh)

```bash
# Clone Kova
git clone https://github.com/ChiFungHillmanChan/kova.git ~/kova

# Go to your project
cd /path/to/your/project

# Preview what will be installed
bash ~/kova/install.sh --dry-run

# Install Kova into this project
bash ~/kova/install.sh
```

Optional global CLI:

```bash
# Install global CLI
bash ~/kova/install.sh --global

# Activate hooks for this project
kova activate

# Verify setup
kova status
```

### Two Plugins

| Plugin | What you get |
|--------|-------------|
| **kova** | Slash commands (`/plan`, `/verify-app`, `/code-review`, etc.) + engineering protocol skill |
| **kova-full** | Everything in kova + safety hooks, verification gate, auto-format, commit gate, team loop |

Choose `kova` if you want the workflow without enforcement. Choose `kova-full` if you want the full autonomous engineering system.

**Requirements:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code), `jq` (required), `gh` (optional), [`@openai/codex`](https://www.npmjs.com/package/@openai/codex) (optional)

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
| Release Notes | [RELEASE_NOTES.md](RELEASE_NOTES.md) |
| License | [MIT](LICENSE) |

---

## Why Kova

<p align="center">
  <img src="assets/kova-comparison.png" alt="Without Kova vs With Kova" width="100%" />
</p>

- **Safe by default** — blocks dangerous commands (`rm -rf /`, `DROP TABLE`, force push) and protects secrets
- **Verified before stop** — fast stop gate (lint + typecheck) catches errors on every stop; full 7-layer verification runs in the Team Loop
- **Autonomous but bounded** — retry, rate limiting, and circuit breaker prevent runaway loops
- **Multi-model review** — Claude agents + optional OpenAI Codex cross-model review
- **Works across stacks** — Node.js, Python, Go, Rust, Ruby, Java, .NET (auto-detected)

---

## How It Works

<p align="center">
  <img src="assets/kova-workflow.png" alt="Kova Team Loop — 6-Phase Workflow" width="100%" />
</p>

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

<p align="center">
  <img src="assets/kova-safety.png" alt="Kova 7-Layer Verification Architecture" width="100%" />
</p>

| Feature | Description |
|---------|-------------|
| **Safety Hooks** | Blocks dangerous commands and protects sensitive files |
| **Fast Stop Gate** | Lint + typecheck on every stop; full 7-layer verification in Team Loop |
| **Auto-Format** | Formats code on every write (Prettier, Ruff, gofmt, rustfmt, etc.) |
| **Team Loop** | Bash-orchestrated cycle per PRD item (implement → verify → review → commit) |
| **Self-Healing** | After 3 failures, writes `DEBUG_LOG.md` and spawns a fresh session |
| **Multi-Model Review** | Claude agents + optional OpenAI Codex cross-model review |
| **Circuit Breaker** | Detects stuck loops and writes actionable failure reports |
| **Rate Limiting** | Prevents runaway API invocations |
| **tmux Dashboard** | Live monitoring via `kova-monitor` |
| **Resumable Loops** | State saved in `.kova-loop/` — resume after interruption |
| **Status Line** | Shows `[KOVA]`, `[KOVA LOOP]`, or `[kova off]` in Claude Code |

### What Runs Where

| Check | Stop hook | Team Loop | Commit gate |
|-------|-----------|-----------|-------------|
| Build | — | Yes | — |
| Tests | — | Yes | — |
| Lint | Yes | Yes | — |
| Type check | Yes | Yes | — |
| Security | — | Warn only | — |
| Verification proof | — | — | Blocks without pass |

See the [full guide](docs/en/README.md) for detailed explanations of each feature.

---

## Testing

213 automated tests across three suites:

```bash
npm install     # Install test dependencies
npm test        # Run all tests
npm run lint    # ShellCheck all scripts
```

CI runs on both Linux and macOS for every PR. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

## Philosophy

> "You don't trust; you instrument."

The goal isn't to hope Claude does the right thing. It's to build a system where **hooks make the wrong thing hard.** As AI models get stronger, your system gets stronger automatically.

---

## Current Guarantees and Limits

**What hooks guarantee (when active):**
- Every stop triggers lint + typecheck (fast stop gate)
- Every file write is checked against the protected files list
- Every bash command is checked against the dangerous commands list
- The Team Loop runs full 7-layer verification via bash instead of relying on prompt compliance

**What hooks do NOT guarantee:**
- Hooks can be disabled by the user (`kova deactivate` or editing settings.json)
- The stop gate runs lint + typecheck only — build, tests, and security run in the Team Loop
- File protection uses pattern matching, not OS-level permissions
- Hooks require `jq` to be installed; without it, they exit silently

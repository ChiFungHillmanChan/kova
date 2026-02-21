# Kova

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Compatible-blueviolet.svg)](https://docs.anthropic.com/en/docs/claude-code)
[![Tests](https://img.shields.io/badge/Tests-178%20passing-brightgreen.svg)](#testing)
[![Languages](https://img.shields.io/badge/Languages-EN%20%7C%20%E7%B2%B5%E8%AA%9E%20%7C%20%E4%B8%AD%E6%96%87-orange.svg)](#documentation)

> Autonomous engineering protocol for Claude Code: safe by default, verified before stop, and built to ship.

**Kova** drops into any project and turns Claude Code from "assistant that asks" into "engineering system that executes, verifies, and self-corrects." Install once, use per project.

---

## v0.2.0 Highlights

- **Rate limiting** for Team Loop to prevent runaway invocation storms
- **Circuit breaker** for stuck or no-progress loops with clear failure reports
- **tmux dashboard** via `kova-monitor` (`start`, `attach`, `status`, `dashboard`, `stop`)
- **Global install + setup wizard** (`install.sh --global`, `kova setup`)
- **178 automated tests passing** (unit + integration + regression)
- **CI on Linux and macOS** with ShellCheck + Bats

See [RELEASE_NOTES.md](RELEASE_NOTES.md) for upgrade notes and details.

## 60-Second Quick Start

```bash
# 1) Clone once
git clone https://github.com/ChiFungHillmanChan/kova.git ~/kova

# 2) In any target project
cd /path/to/your/project
bash ~/kova/install.sh --dry-run
bash ~/kova/install.sh
.claude/kova activate
.claude/kova status
```

Optional global CLI (so you can run `kova` from anywhere):

```bash
bash ~/kova/install.sh --global
kova setup
```

Requirements: `jq` (required), `gh` (optional), `@openai/codex` (optional).

---

## Why Teams Use Kova

- **Safe by default**: blocks dangerous shell/database commands and protects secrets.
- **Quality gates before stop**: build, tests, lint, type checks, and security audit hooks.
- **Autonomous but bounded**: retry, rate limiting, and circuit breaker prevent endless loops.
- **Operational visibility**: tmux dashboard shows loop status in real time.
- **Works across stacks**: Node.js, Python, Go, Rust, Ruby, Java, and .NET.

---

## Core Features

- **Safety Hooks** — Blocks dangerous commands (`rm -rf /`, force push, `DROP TABLE`) and protects sensitive files (`.env`, `.pem`, `secrets/`)
- **Auto-Format** — Formats code on every write using the right tool for each language (Prettier, Ruff, gofmt, rustfmt, RuboCop, etc.)
- **7-Layer Verification Gate** — Build, unit tests, integration tests, E2E, lint, type check, and security audit run automatically when Claude finishes
- **Flaky Test Handling** — Failed tests are automatically retried once before blocking
- **Self-Healing** — After 3 failed verification attempts, writes `DEBUG_LOG.md` and spawns a fresh session to fix
- **Rate Limiting** — Caps high-frequency loop invocations to prevent saturation
- **Circuit Breaker** — Stops loops with repeated stuck/no-progress states and writes actionable reports
- **Team Loop** — 6-phase cycle (Clarify, Plan, Implement, Verify, Review, Commit) that autonomously implements each item in a PRD
- **tmux Monitor** — `kova monitor` dashboard for live loop observability
- **Multi-Model Review** — 4 parallel Claude reviewer agents + optional OpenAI Codex cross-model review for catching blind spots
- **Zero-Token CLI** — `kova help`, `kova status`, `kova activate`, `kova deactivate` run in your terminal without consuming LLM tokens
- **Slash Commands** — `/plan`, `/verify-app`, `/commit-push-pr`, `/fix-and-verify`, `/code-review`, `/simplify`, `/daily-standup`, `/kova:loop`, `/kova:init`
- **CLAUDE.md Culture Doc** — Teaches Claude to never ask permission for routine decisions, always run tests, and escalate only for production deploys or repeated failures
- **7 Language Ecosystems** — Node.js, Python, Go, Rust, Ruby, Java, .NET — auto-detected from lockfiles and config files
- **On-Demand Activation** — Hooks can be toggled on/off without reinstalling
- **Resumable Loops** — If interrupted, Team Loop state is saved in `.kova-loop/` and can be resumed

---

## How It Works

The Team Loop (`/kova:loop`) processes each PRD item through 6 phases:

```
  ┌─────────┐     ┌──────┐     ┌───────────┐
  │ CLARIFY │────▶│ PLAN │────▶│ IMPLEMENT │
  │ Phase 0 │     │ Ph 1 │     │  Phase 2  │
  └─────────┘     └──────┘     └─────┬─────┘
                                     │
                                     ▼
  ┌─────────┐     ┌────────┐   ┌──────────┐
  │ COMMIT  │◀────│ REVIEW │◀──│  VERIFY  │
  │ Phase 5 │     │  Ph 4  │   │ Phase 3  │
  └────┬────┘     └───┬────┘   └────┬─────┘
       │              │             │
       │              │    fail     │ fail
       ▼              └─────────────┘
   Next Item            (auto-fix)
```

- **Phase 0 — Clarify**: Documents assumptions, no questions asked
- **Phase 1 — Plan**: Brainstorms approaches, picks the best, writes file-level plan
- **Phase 2 — Implement**: Writes code and tests following the plan
- **Phase 3 — Verify**: 7-layer gate (build, tests, lint, types, security)
- **Phase 4 — Review**: 4 Claude agents + optional Codex cross-model review
- **Phase 5 — Commit**: Conventional Commit with attribution

---

## Understanding Kova Files

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Culture document — teaches Claude autonomous behavior |
| `install.sh` | Installer script — copies `.claude/` into any project |
| `kova` | CLI script — zero-token commands (help, status, activate, deactivate) |
| `.claude/settings.json` | Hook configuration and permission rules |
| `.claude/hooks/*.sh` | 5 automatic hook scripts |
| `.claude/hooks/lib/*.sh` | 8 shared utility scripts |
| `.claude/commands/*.md` | 7 workflow slash commands |
| `.claude/commands/kova/*.md` | Team Loop and init commands |
| `.claude/commands/kova/phases/*.md` | 6 phase definitions for Team Loop |

### Key File Relationships

```
CLAUDE.md (rules)
    │
    ▼
.claude/settings.json (hook config + permissions)
    │
    ├── hooks/format.sh ──────────────▶ PostToolUse: auto-format
    ├── hooks/verify-on-stop.sh ──────▶ Stop: 7-layer gate
    │       └── lib/verify-gate.sh
    │       └── lib/detect-stack.sh
    ├── hooks/block-dangerous.sh ─────▶ PreToolUse: safety
    ├── hooks/protect-files.sh ───────▶ PreToolUse: file protection
    └── hooks/kova-loop.sh ──────────▶ Team Loop orchestration
            └── lib/parse-prd.sh
            └── lib/parse-failures.sh
            └── lib/generate-prompt.sh
            └── lib/run-code-review.sh
```

---

## Configuration

### Hooks

Hooks are registered in `.claude/settings.json` under the `hooks` key. Each hook has:

- **matcher** — Which Claude tool triggers it (`Bash`, `Write|Edit`, etc.)
- **command** — Path to the shell script
- **timeout** — Max execution time in seconds

Toggle hooks on/off without reinstalling:

```bash
.claude/kova activate     # Turn ON all hooks
.claude/kova deactivate   # Turn OFF all hooks
```

### Permissions

The `permissions` section in `settings.json` defines `allow` and `deny` lists for bash commands. Common safe commands (git, npm, go, cargo, etc.) are pre-allowed. Dangerous patterns (force push, recursive delete of system dirs) are pre-denied.

### Codex (Optional Multi-Model Review)

Install OpenAI Codex CLI for cross-model code review during Team Loop Phase 4:

```bash
npm install -g @openai/codex
codex login
```

If not installed, Codex review is silently skipped. Everything else works normally.

---

## Project Structure

```
kova/
├── README.md              # This file
├── CLAUDE.md              # Engineering protocol (copied to projects)
├── CONTRIBUTING.md        # Contribution guide
├── LICENSE                # MIT
├── .gitignore
├── install.sh             # Installer script
├── kova                   # CLI script (zero-token commands)
├── kova-monitor           # tmux dashboard for Team Loop
├── .claude/
│   ├── settings.json      # Hook config + permissions
│   ├── hooks/
│   │   ├── format.sh           # Auto-format on write
│   │   ├── verify-on-stop.sh   # 7-layer verification gate
│   │   ├── block-dangerous.sh  # Block dangerous commands
│   │   ├── protect-files.sh    # Protect sensitive files
│   │   ├── kova-loop.sh        # Team Loop orchestration
│   │   └── lib/
│   │       ├── detect-stack.sh     # Language/framework detection
│   │       ├── verify-gate.sh      # Verification gate logic
│   │       ├── parse-prd.sh        # PRD parser
│   │       ├── parse-failures.sh   # Failure parser
│   │       ├── generate-prompt.sh  # Prompt generator
│   │       ├── run-code-review.sh  # Code review orchestrator
│   │       ├── rate-limiter.sh    # Rate limiting for API calls
│   │       └── circuit-breaker.sh # Circuit breaker for stuck loops
│   └── commands/
│       ├── plan.md              # /plan
│       ├── verify-app.md        # /verify-app
│       ├── commit-push-pr.md    # /commit-push-pr
│       ├── fix-and-verify.md    # /fix-and-verify
│       ├── code-review.md       # /code-review
│       ├── simplify.md          # /simplify
│       ├── daily-standup.md     # /daily-standup
│       └── kova/
│           ├── init.md          # /kova:init
│           ├── loop.md          # /kova:loop
│           └── phases/
│               ├── clarify.md   # Phase 0
│               ├── plan.md      # Phase 1
│               ├── implement.md # Phase 2
│               ├── verify.md    # Phase 3
│               ├── review.md    # Phase 4
│               └── commit.md    # Phase 5
└── docs/
    ├── en/README.md         # Full guide (English)
    ├── zh-hk/README.md      # Full guide (Cantonese)
    └── zh-cn/README.md      # Full guide (Simplified Chinese)
```

---

## Best Practices

1. **Always preview first** — Run `install.sh --dry-run` before installing into a project
2. **Activate hooks after install** — Run `kova activate` to enable automatic hooks
3. **Write PRDs for large features** — Use `/kova:loop` for multi-item work instead of ad-hoc prompts
4. **Use `/plan` for non-trivial work** — Let Claude explore the codebase and plan before implementing
5. **Run `/verify-app` before PRs** — The 10-layer check is stricter than the automatic 7-layer gate
6. **Keep CLAUDE.md in your project** — It teaches Claude the autonomous engineering mindset

---

## System Requirements

- **Claude Code** — [docs.anthropic.com](https://docs.anthropic.com/en/docs/claude-code)
- **jq** (required) — `brew install jq` (macOS) / `apt install jq` (Linux)
- **gh** (optional) — For PR commands
- **Codex CLI** (optional) — `npm install -g @openai/codex` for multi-model review

---

## Command Reference

### CLI Commands (zero tokens — run from terminal)

| Command | What it does |
|---------|-------------|
| `kova help` | Show all available commands |
| `kova status` | Check hooks, stack, installed commands |
| `kova activate` | Turn ON automatic hooks |
| `kova deactivate` | Turn OFF automatic hooks |
| `kova install` | Install Kova into current project |

After installing into a project, add to PATH for convenience:

```bash
export PATH="$PWD/.claude:$PATH"
# Then just: kova help
```

### Slash Commands (inside Claude Code — uses LLM tokens)

| Command | What it does |
|---------|-------------|
| `/plan [feature]` | Plan before coding — Claude waits for your "go" |
| `/verify-app` | Full 10-layer QA sweep |
| `/commit-push-pr` | Auto: stage, commit, push, open draft PR |
| `/fix-and-verify` | Autonomous bug fixing loop |
| `/code-review` | 4 parallel reviewers + optional Codex cross-model review |
| `/simplify` | Clean up code without changing behavior |
| `/daily-standup` | Engineering report: shipped, blockers, priorities |
| `/kova:loop <prd>` | Team Loop: 6-phase cycle per PRD item |
| `/kova:init [name]` | Scaffold a new PRD file |

---

## Supported Languages

| Language | Build | Test | Lint | Type Check | Format | Security Audit |
|----------|-------|------|------|------------|--------|----------------|
| JS/TS | `npm run build` | vitest, jest | eslint | tsc | prettier | npm/pnpm/yarn audit |
| Python | - | pytest | ruff, flake8 | mypy, pyright | ruff, black | pip-audit |
| Go | `go build` | `go test` | golangci-lint | `go vet` | gofmt | govulncheck |
| Rust | `cargo build` | `cargo test` | cargo clippy | `cargo check` | rustfmt | cargo audit |
| Ruby | - | rspec | rubocop | - | rubocop -a | bundle-audit |
| Java | mvn/gradle | mvn/gradle test | - | - | google-java-format | - |
| .NET | `dotnet build` | `dotnet test` | dotnet format | `dotnet build` | dotnet format | - |

Auto-detection is based on lockfiles and config files (`package.json`, `go.mod`, `Cargo.toml`, etc.).

---

## Multi-Model Review

When the Team Loop reaches Phase 4 (Review), it spawns parallel Claude agents for code quality, security, test coverage, and UX review. If OpenAI Codex CLI is installed and authenticated, it also sends changes to Codex for an independent cross-model review.

**Why?** Same-model reviewers share the same blind spots. A different model catches patterns and issues that Claude's reviewers might miss, and vice versa. Like having two different accounting firms audit the same books.

Codex review is fully optional and non-blocking. If Codex isn't installed, isn't logged in, or errors out, the review continues with Claude agents only.

---

## Documentation

Full guides available in three languages:

| Language | Link |
|----------|------|
| English | [docs/en/README.md](docs/en/README.md) |
| Cantonese (粵語) | [docs/zh-hk/README.md](docs/zh-hk/README.md) |
| Simplified Chinese (简体中文) | [docs/zh-cn/README.md](docs/zh-cn/README.md) |

---

## Testing

Kova includes **178 automated tests** across three suites. See [CONTRIBUTING.md](CONTRIBUTING.md) for full details.

```bash
npm install              # Install test dependencies
npm test                 # Run all tests (unit + integration + regression)
npm run lint             # ShellCheck all shell scripts
```

| Suite | Tests | What it covers |
|-------|-------|----------------|
| Unit | 108 | parser/detector libs, rate limiter, circuit breaker, monitor behaviors |
| Integration | 63 | install, activate/deactivate, status, monitor, global install workflows |
| Regression | 7 | Hook-name consistency across kova/install/settings |

CI runs ShellCheck + all Bats suites on both Linux and macOS for every PR.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on adding language support, hooks, commands, and documentation.

---

## License

[MIT](LICENSE) - Kova Contributors

---

## Philosophy

> "You don't trust; you instrument."

The goal isn't to hope Claude does the right thing. It's to build a system where Claude **can only do the right thing.** As AI models get stronger, your system gets stronger automatically.

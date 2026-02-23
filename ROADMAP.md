# Kova Roadmap

> Where Kova is going — and how you can help get it there.

This roadmap reflects the project's direction. Items are roughly ordered by priority within each phase. If you want to contribute, pick an item and open an issue to discuss your approach before starting.

---

## Phase 1: Strengthen the Core

These improvements make the existing bash-orchestrated system more robust.

- [ ] **Parallel verification layers** — run independent gates (lint, typecheck, security) concurrently to cut verification time
- [ ] **Smarter self-healing** — use failure history from `DEBUG_LOG.md` to avoid repeating the same fix strategy
- [ ] **Configurable gate profiles** — let teams define which of the 7 layers are required vs. advisory per project
- [ ] **Improved resumability** — better state recovery after crashes mid-loop, including partial commit rollback
- [ ] **Performance benchmarks** — track verification time per stack so regressions are caught automatically

## Phase 2: Multi-Tool Support

Kova's enforcement model is tool-agnostic. The bash orchestrator doesn't care who the worker is.

- [ ] **OpenAI Codex CLI** — full support as a worker alongside Claude Code (review support already exists)
- [ ] **Gemini CLI** — support Google's CLI as a worker in the loop
- [ ] **Cursor / Windsurf** — investigate hook integration with IDE-based AI coding tools
- [ ] **Generic worker interface** — define a standard protocol so any AI coding tool can be a Kova worker

## Phase 3: Editor & CI Integration

Bring Kova's enforcement into the tools teams already use.

- [ ] **VS Code extension** — activate/deactivate hooks, view verification status, trigger `/kova:loop` from the editor
- [ ] **GitHub Action** — run Kova's verification gate as a CI check on PRs (enforce the same 7-layer gate in CI)
- [ ] **Pre-commit hook bridge** — integrate with the `pre-commit` framework so Kova gates run alongside existing hooks
- [ ] **tmux dashboard improvements** — richer live monitoring: progress bars, estimated time remaining, failure history

## Phase 4: Team & Enterprise Features

For teams running Kova across multiple projects and contributors.

- [ ] **Shared gate configurations** — publish and reuse verification profiles across repos
- [ ] **Metrics & reporting** — track verification pass rates, self-healing success rates, and review outcomes over time
- [ ] **Multi-repo orchestration** — run `/kova:loop` across related repos (e.g., frontend + backend) with dependency awareness
- [ ] **Policy-as-code** — define organization-wide rules (e.g., "all PRs must pass security gate") enforced at the bash level

---

## How to Contribute

1. **Pick an item** from any phase — earlier phases have more immediate impact
2. **Open an issue** describing your approach before writing code
3. **Reference this roadmap** in your PR (e.g., "Implements Roadmap Phase 2: OpenAI Codex CLI")
4. See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and testing guidelines

## Suggesting New Items

Have an idea that's not listed? [Open a feature request](https://github.com/ChiFungHillmanChan/kova/issues/new?template=feature_request.md) and tag it with `roadmap`. The best suggestions come with:
- A clear problem statement (what's painful today?)
- A proposed solution (how should it work?)
- Why it fits Kova's philosophy ("you don't trust; you instrument")

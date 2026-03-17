# Kova Protocol — Full Guide

<p align="center">
  <img src="../../assets/kova-hero.png" alt="Kova — Autonomous Engineering Protocol" width="100%" />
</p>

> Drop into **any project** to transform Claude Code from "AI that asks questions" into "autonomous engineering team that ships."

---

## Table of Contents

- [What is Kova?](#what-is-kova)
- [Installation](#installation)
- [The 4 Hooks (Automatic)](#the-4-hooks-automatic)
  - [Hook 1: auto-format](#hook-1-formatsh--auto-format)
  - [Hook 2: verify-on-stop (Fast Stop Gate)](#hook-2-verify-on-stopsh--fast-stop-gate)
  - [Hook 3: block-dangerous](#hook-3-block-dangeroussh--block-dangerous-commands)
  - [Hook 4: protect-files](#hook-4-protect-filessh--protect-sensitive-files)
- [CLAUDE.md — The Culture Document](#claudemd--the-culture-document)
- [Slash Commands](#slash-commands)
- [Team Loop — The Crown Jewel](#team-loop--the-crown-jewel)
  - [PRD Format](#prd-format)
  - [Phase 0: Clarify](#phase-0-clarify)
  - [Phase 1: Plan](#phase-1-plan)
  - [Phase 2: Implement](#phase-2-implement)
  - [Phase 3: Verify](#phase-3-verify)
  - [Phase 4: Review (Multi-Model)](#phase-4-review-multi-model)
  - [Phase 5: Commit](#phase-5-commit)
  - [Loop Controls](#loop-controls)
- [Installing Codex (Optional)](#installing-codex-optional)
- [Daily Workflow](#daily-workflow)
- [Supported Languages](#supported-languages)
- [Summary](#summary)

---

## What is Kova?

Kova is a bundle of rules, scripts, and commands. You install it into any project, and Claude Code transforms from a "you ask, it answers" assistant into an "autonomously builds, tests, fixes, and reviews" engineering team.

**After installing Kova, Claude stops asking "should I do this?" — it just does it, verifies its own work, and fixes its own mistakes.**

---

## Installation

### Option A: Claude Code Plugin (recommended)

```bash
claude /install kova          # Lightweight: commands + skills only
claude /install kova-full     # Full suite: commands + skills + hooks + enforcement
```

No cloning, no scripts. Everything is available immediately after install.

| Plugin | Includes |
|--------|----------|
| **kova** | Slash commands + engineering protocol skill |
| **kova-full** | Everything in kova + safety hooks, verification gate, auto-format, commit gate, team loop |

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

# Optional: install global CLI
bash ~/kova/install.sh --global

# Activate hooks for this project
kova activate

# Verify setup
kova status
```

What the installer does:
1. Creates the `.claude/` directory structure in your project
2. Copies all hooks (auto-triggered scripts)
3. Copies all slash commands (`/plan`, `/verify-app`, etc.)
4. Copies `CLAUDE.md` (the rules document that teaches Claude how to behave)
5. Makes all `.sh` files executable

**Requirements:**
- `jq` (required) — `brew install jq` (macOS) / `apt install jq` (Linux)
- `gh` (optional) — for opening Pull Requests
- `codex` (optional) — for cross-model review, explained in detail below

---

## The 4 Hooks (Automatic)

<p align="center">
  <img src="../../assets/kova-safety.png" alt="Kova 7-Layer Verification Architecture" width="100%" />
</p>

Hooks are scripts that run automatically. You never type anything — they trigger at specific moments during Claude's work.

### Hook 1: `format.sh` — Auto-format

**When does it run?** After every file write or edit by Claude.

**What does it do?** Automatically formats your code.

It auto-detects your language and runs the right formatter:
- JavaScript / TypeScript → Prettier
- Python → Ruff or Black
- Go → gofmt
- Rust → rustfmt
- Ruby → RuboCop
- Java → google-java-format
- .NET → dotnet format

**In plain English:** Claude writes code, the code is automatically formatted. You never touch a formatter manually.

---

### Hook 2: `verify-on-stop.sh` — Fast Stop Gate

**When does it run?** Every time Claude says "I'm done" and tries to stop.

**What does it do?** Runs a fast check: **lint + typecheck only** (layers 5-6). If either fails, Claude **is blocked from stopping** and must keep fixing. This keeps stop-time fast while catching the most common issues.

**Layer 5: Lint**
- Checks code against style rules.
- ESLint, ruff, flake8, golangci-lint, clippy, rubocop — auto-detected.
- Lint errors → **blocked**

**Layer 6: Type Check**
- TypeScript → `tsc --noEmit`
- Python → `mypy` or `pyright`
- Go → `go vet`
- Rust → `cargo check`
- Type errors → **blocked**

**In plain English:** Claude finishes work, tries to stop, but must pass lint and typecheck first. If either fails, Claude fixes the issue and tries again. Automatically.

**If it fails 3 times:** A `DEBUG_LOG.md` is written with diagnosis, and a fresh Claude session is auto-spawned to attempt the fix (self-healing). If the fresh session also fails, it finally stops for human review.

#### Full 7-Layer Verification (Team Loop)

The complete 7-layer verification runs in the **Team Loop** (`/kova:loop`) via `verify-gate.sh`, not on every stop. This includes:

1. **Build** — compile your project (npm run build, go build, cargo build, etc.)
2. **Unit Tests** — run all unit tests with flaky retry (auto-retry once on failure)
3. **Integration Tests** — only if `test:integration` script is configured
4. **E2E Tests** — only if Playwright is installed
5. **Lint** — same as stop gate
6. **Type Check** — same as stop gate
7. **Security Audit** — warning only, does not block

---

### Hook 3: `block-dangerous.sh` — Block Dangerous Commands

**When does it run?** Before every bash command Claude tries to execute.

**What does it do?** Checks if the command is dangerous. If so, blocks it immediately.

Blocked commands include:
- `rm -rf /` — delete the entire system
- `rm -rf ~` — delete the entire home directory
- `git push --force` — force push (overwrites other people's code)
- `DROP TABLE` / `DROP DATABASE` — delete database tables
- Fork bombs — commands that crash the computer
- Direct `/dev/` device operations

**In plain English:** Even if Claude "goes haywire," it physically cannot destroy your system.

---

### Hook 4: `protect-files.sh` — Protect Sensitive Files

**When does it run?** Before every file write or edit by Claude.

**What does it do?** Blocks modifications to sensitive files.

Protected files include:

**Env files** (basename exact match — `some.environment.ts` is NOT blocked):
- `.env`, `.env.local`, `.env.development`, `.env.test`, `.env.staging`, `.env.production`, `.env.prod`

**Sensitive paths** (substring match on full path):
- `.pem`, `.key` — encryption keys
- `id_rsa` — SSH private keys
- `secrets/` directory
- `credentials/` directory
- `serviceAccountKey.json`, `firebase-adminsdk` — cloud service credentials

**In plain English:** Claude will not accidentally edit your passwords or API keys.

---

## CLAUDE.md — The Culture Document

This file teaches Claude "how to behave." Once installed, Claude reads it automatically at the start of every session.

### Core Rules

**Things Claude does NOT need to ask you about — it just does them:**
- Choosing between implementation approaches → picks the better one, writes a comment explaining why
- Writing tests → always writes them, no need to ask
- File/folder naming → follows existing project conventions
- Minor refactors while fixing bugs → does it, notes in summary
- Adding types to untyped code → just does it
- Fixing lint/format errors → always fixes
- Running tests/builds/type checks → always runs without asking

**Things Claude MUST escalate to you before doing:**
- Deleting production data or database tables
- Changing `.env` / secrets / credentials
- Architectural changes affecting more than 3 major systems
- Deploying to production
- If the same task has failed 3+ times in a row

### Assumption Protocol

When requirements are ambiguous, Claude **does not stop and ask you**. Instead:
1. Makes the most reasonable assumption
2. Adds a comment: `// ASSUMPTION: [assumption]. Change X if different behaviour needed.`
3. Continues working
4. Includes assumptions in the final summary

**In plain English:** Claude doesn't bombard you with "what do you want?" and "should I do this?" questions. It makes judgment calls, documents them, and tells you afterward.

---

## Slash Commands

### `/plan [feature]` — Plan Before Coding

You say: `/plan add a login feature`

Claude will:
1. Explore your entire codebase, find related files
2. Write a detailed plan
3. **Wait for your approval** before writing any code

You read the plan, type `go`, and Claude starts implementing autonomously.

### `/verify-app` — Full 10-Layer QA Check

Stricter than the automatic 7-layer gate. Adds 3 more layers:

- Layers 1-4: Build + Unit + Integration + E2E (same as auto gate)
- **Layer 5: Browser check** — opens your app in Chrome, checks for console errors, broken pages
- **Layer 6: Accessibility check** — alt text, labels, heading hierarchy, keyboard navigation
- **Layer 7: Performance check** — load time, bundle size
- Layers 8-10: Lint + Type check + Security / Code review

**Use this before opening a PR or deploying.**

### `/commit-push-pr` — Auto Commit + Push + Open PR

Claude automatically:
1. `git add` relevant files
2. Writes a Conventional Commit message (`feat:`, `fix:`, `refactor:`, etc.)
3. `git push`
4. Opens a Draft PR using `gh`

### `/fix-and-verify` — Autonomous Bug Fixing

Claude will:
1. Analyze the error
2. Attempt a fix
3. Run tests
4. If tests still fail → analyze, fix, re-run
5. Loop until all pass
6. If 3 attempts fail → stop and ask you

**You say "there's a bug," Claude fixes it until there's no bug.**

### `/code-review` — Multi-Agent Code Review

Claude spawns 4 independent reviewers in parallel:

1. **Code Quality Reviewer** — code quality, architecture, DRY, naming, file length (300 line limit)
2. **Security Reviewer** — OWASP Top 10: injection, XSS, auth bypass, secrets exposure...
3. **Test Coverage Reviewer** — checks for missing tests, then writes them directly
4. **UX Reviewer** (UI changes only) — accessibility, responsive, interaction, loading/error/empty states

These 4 reviewers run **in parallel** (at the same time), not one after another.

### `/simplify` — Clean Up Code

Does not change behavior, just cleans up:
- Removes dead code
- Improves naming
- Simplifies structure

### `/daily-standup` — Daily Report

Shows: what was done today, blockers, next steps, velocity.

---

## Team Loop — The Crown Jewel

<p align="center">
  <img src="../../assets/kova-workflow.png" alt="Kova Team Loop — 6-Phase Workflow" width="100%" />
</p>

This is Kova's most powerful feature. You write a PRD (Product Requirements Document — basically a to-do list), then run:

```
/kova:loop docs/my-prd.md
```

Claude **automatically implements each item** in your PRD, and every item goes through 6 phases.

### PRD Format

Just a Markdown file with checkboxes:

```markdown
# My Feature PRD
- [ ] Add a login page
- [ ] Add password reset functionality
- [ ] Add Google OAuth login
- [x] Design database schema (already done)
```

`- [ ]` is pending, `- [x]` is completed.

---

### Phase 0: Clarify

Claude reads your item, e.g., "Add a login page."

It asks itself:
- Are the requirements clear?
- Is anything ambiguous?

**It does NOT ask you.** It makes assumptions and documents them in `.kova-loop/plans/item-N-clarify.md`.

Example output:
```
ASSUMPTION: Login page uses email + password, no username.
ASSUMPTION: Failed login shows toast notification.
```

---

### Phase 1: Plan

Unless the item is trivial (e.g., "fix a typo"), Claude will:

1. Use the `superpowers:brainstorming` skill to generate 2-3 approaches
2. Pick the best one
3. Spawn an Explore agent to scan the codebase and map related files/patterns
4. Write a detailed plan to `.kova-loop/plans/item-N-plan.md`

The plan is specific to `file:function` level:
```
1. Create src/pages/Login.tsx — login form component
2. Create src/api/auth.ts — login() function, calls POST /api/auth/login
3. Modify src/routes.tsx — add /login route
4. Create src/pages/__tests__/Login.test.tsx — tests
```

---

### Phase 2: Implement

Claude follows the plan step by step.

It will:
1. Load the `production-code-standards` skill (ensures production-quality code)
2. If the item is UI-related, also load `ui-ux-pro-max` skill
3. Execute plan steps sequentially
4. Write tests: happy path, edge cases, error cases
5. Track which files were changed

**This phase has 3 modes:**
- `implement` — normal fresh implementation
- `fix-verify` — Phase 3 (verify) failed last time; only fix those specific errors
- `fix-review` — Phase 4 (review) found HIGH-severity issues; only fix those

---

### Phase 3: Verify

Same 7-layer gate as described above:

1. Build
2. Unit tests (retry once on failure)
3. Integration tests (if configured)
4. E2E tests (if Playwright installed)
5. Lint
6. Type check
7. Security audit (warning only)

**If all layers 1-6 pass:** Proceed to Phase 4 (review).

**If any layer fails:**
- All errors written to `.kova-loop/current-failures.md` with file:line detail
- Mode set to `fix-verify`
- Returns to Phase 2 to fix only those specific errors
- Then Phase 3 runs again

This fix → verify → fix → verify loop continues until pass or max attempts (default 5) reached.

If 5 attempts all fail → marked as STUCK, written to `STUCK_ITEMS.md`, item is skipped, next item begins.

---

### Phase 4: Review (Multi-Model)

This phase has two parts: **Claude multi-agent review** and **Codex cross-model review**.

#### Part 1: Claude Multi-Agent Review

Claude spawns up to 4 independent reviewer agents:

**Reviewer 1 — Code Quality:**
- Code quality, DRY violations, pattern consistency
- Error handling, edge cases, naming
- File length (300 line limit)

**Reviewer 2 — Security:**
- OWASP Top 10: SQL injection, XSS, CSRF
- Hardcoded secrets, auth/authorization holes
- Input validation, output encoding

**Reviewer 3 — Test Coverage:**
- Which code paths lack tests
- Test quality (meaningful assertions?)
- **This reviewer writes tests directly** (other reviewers cannot modify files)

**Reviewer 4 — UX (UI items only):**
- Accessibility
- Responsive design
- Interaction patterns
- Loading state, error state, empty state

All 4 agents run **in parallel** — Claude launches them all in a single message.

#### Part 2: Codex Cross-Model Review (Optional)

Claude checks if the OpenAI Codex CLI is installed:

```bash
command -v codex &>/dev/null
```

**If not installed:** Silently skipped. Nothing is mentioned. Everything continues normally.

**If installed:** Claude will:

1. Generate a `git diff` of all changes
2. Prepare a prompt that includes:
   - What the PRD item is ("Add a login page")
   - What was implemented (summary)
   - What the expected result is
   - Which files changed
   - The complete diff
3. Send this prompt to Codex (i.e., OpenAI's model)
4. Codex reviews the code using its own "brain"
5. Claude parses Codex's response into findings

**Why do this?**

Because Claude's 4 reviewer agents are all the same Claude model. They share **the same blind spots**.

Using a completely different model (Codex/GPT) to review the same code catches issues Claude's reviewers might miss. And vice versa — Claude catches things Codex misses.

This is the "multi-model review" advantage. Like having two different accounting firms audit the same books.

**If Codex errors out, times out, or returns empty output:** A warning is logged, and the review continues. Codex review is non-blocking — it never stops the pipeline.

#### Merging Results

All findings (4 Claude agents + Codex) are merged into a single list, triaged by severity:

- **HIGH** (severe) — **Blocks!** Must go back and fix
- **MEDIUM** (moderate) — Logged, does not block
- **LOW** (minor) — Logged, does not block

Written to `.kova-loop/current-review.md`:
```
- [src/api/auth.ts:42] [security] — SQL injection: user input directly in query
- [src/pages/Login.tsx:15] [codex] — Missing error boundary for async state
```

**If any HIGH findings exist:** Enter `fix-review` mode, return to Phase 2.
**If no HIGH findings:** Pass! Proceed to Phase 5.

---

### Phase 5: Commit

Claude will:
1. `git add` all changed files
2. Write a Conventional Commit message:
   ```
   feat(auth): add login page with email/password

   Kova Team Loop — Item 1/3
   Co-Authored-By: Claude <noreply@anthropic.com>
   ```
3. `git commit`
4. Record the commit hash

Then move to the next item and restart at Phase 0.

---

### Loop Controls

**Progress tracking:**
After every iteration, Claude updates:
- `.kova-loop/LOOP_PROGRESS.md` — which items are complete, which is in progress
- `.kova-loop/ITERATION_LOG.md` — detailed log of each iteration

**Stuck detection:**
If the same item fails 5 times (default), Claude will:
- Mark it as STUCK
- Write to `.kova-loop/STUCK_ITEMS.md`
- Skip it and continue to the next item

**Resumable:**
If you stop midway (disconnect, manual cancel, etc.), all progress is saved in `.kova-loop/`. Next time you run `/kova:loop docs/my-prd.md`, it asks: `resume` / `restart` / `cancel`.

**Preview mode:**
```
/kova:loop docs/my-prd.md --dry-run
```
Shows the plan without executing anything.

**Other flags:**
- `--no-commit` — do everything but skip the git commit
- `--max-iterations 40` — max 40 iterations (default 20)
- `--max-fix-attempts 10` — max 10 fix attempts per item (default 5)

---

## Installing Codex (Optional)

```bash
npm install -g @openai/codex
codex login
```

If not installed, not logged in, or no OpenAI account, the cross-model review is automatically skipped. All other features work normally.

---

## Daily Workflow

```
Morning:
  /daily-standup              <- 30-second project overview

Feature work:
  /plan add a login page      <- plan first, you approve
  -> "go"                     <- Claude implements autonomously
  /verify-app                 <- QA check (also runs auto on Stop)
  /commit-push-pr             <- ships it

Bug found:
  /fix-and-verify             <- Claude fixes until no bugs remain

Before merge:
  /code-review                <- multi-agent review (+ Codex cross-model)
  /simplify                   <- clean up code

Large feature (multiple items):
  /kova:loop docs/prd.md      <- auto-implement each item, 6 phases each

End of day:
  /daily-standup              <- see what shipped
```

---

## Supported Languages

| Language | Build | Test | Lint | Type Check | Format | Security Audit |
|----------|-------|------|------|------------|--------|----------------|
| JS/TS | Yes | vitest, jest | eslint | tsc | prettier | npm/pnpm/yarn audit |
| Python | - | pytest | ruff, flake8 | mypy, pyright | ruff, black | pip-audit |
| Go | go build | go test | golangci-lint | go vet | gofmt | govulncheck |
| Rust | cargo build | cargo test | cargo clippy | cargo check | rustfmt | cargo audit |
| Ruby | - | rspec | rubocop | - | rubocop -a | bundle-audit |
| Java | mvn/gradle | mvn/gradle test | - | - | google-java-format | - |
| .NET | dotnet build | dotnet test | dotnet format | dotnet build | dotnet format | - |

Auto-detection is based on lockfiles and config files (package.json, go.mod, Cargo.toml, etc.).

---

## Summary

<p align="center">
  <img src="../../assets/kova-comparison.png" alt="Without Kova vs With Kova" width="100%" />
</p>

| Aspect | Without Kova | With Kova |
|--------|-------------|-----------|
| Formatting | You format manually | Auto-formatted on every save |
| Testing | Claude might skip tests | Auto-runs, auto-fixes on failure |
| Safety | Claude could `rm -rf` | All dangerous commands blocked |
| Secrets | Claude might edit .env | All sensitive files protected |
| Review | You read the code yourself | 4 Claude agents + Codex review in parallel |
| Work mode | You ask, it answers | It does the work, tells you when done |
| Failure handling | Reports error and stops | Auto-fixes, only stops after 3+ failures |

**Kova's philosophy:** *"You don't trust; you instrument."*

The goal isn't to hope Claude does the right thing. It's to build a system where **hooks make the wrong thing hard.**

---

## Current Guarantees and Limits

Kova's safety hooks are enforced by the Claude Code hook system. Here's what that means in practice:

**What hooks guarantee (when active):**
- Every stop triggers lint + typecheck (fast stop gate)
- Every file write is checked against the protected files list
- Every bash command is checked against the dangerous commands list
- The Team Loop runs full 7-layer verification via bash — Claude cannot skip it

**What hooks do NOT guarantee:**
- Hooks can be disabled by the user (`kova deactivate` or editing settings.json)
- The stop gate runs lint + typecheck only — build, tests, and security run in the Team Loop
- File protection uses pattern matching, not OS-level permissions — unusual filenames could bypass it
- Hooks require `jq` to be installed; without it, they exit silently

**In short:** Kova makes the wrong thing hard, not impossible. It's an engineering discipline system, not a security sandbox.

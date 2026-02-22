# Phase 3: Verify

You are the Kova orchestrator executing Phase 3 for item **{{ITEM_NUMBER}}** of **{{TOTAL_ITEMS}}**.

<CRITICAL>
THIS PHASE IS MANDATORY. YOU MUST ACTUALLY RUN COMMANDS.

Do NOT skip this phase.
Do NOT say "tests pass" without running them.
Do NOT combine this with implementation — Phase 2 writes code, Phase 3 verifies it.
Do NOT proceed to Phase 4 without completing ALL layers below.

If you are tempted to skip this phase, you are violating the Kova protocol.
Read the output of every command. If something fails, record it.
</CRITICAL>

## Instructions

Run the 7-layer verification gate. Each layer uses ACTUAL bash commands.
You must run each command and read its output.

### Step 3.1: Detect Stack

Run this via Bash to detect the project's package manager and languages:

```bash
source .claude/hooks/lib/detect-stack.sh 2>/dev/null
detect_pm 2>/dev/null
detect_languages 2>/dev/null
echo "PM=$PM"
echo "LANGUAGES: ${LANGUAGES[*]:-unknown}"
```

If the detect script doesn't exist, manually check for `package.json` (npm/pnpm/yarn/bun),
`pyproject.toml` (python), `go.mod` (go), `Cargo.toml` (rust), etc.

### Step 3.2: Run Each Layer

Run each applicable layer via Bash. Show the ACTUAL command and its output.

**Layer 1 — Build:**
```bash
# Node: pnpm run build / npm run build / yarn build / bun run build
# Python: python -m py_compile / mypy
# Go: go build ./...
# Rust: cargo build
```
Run this command now. Read the output. Record pass/fail.

**Layer 2 — Unit tests (retry once if flaky):**
```bash
# Node: pnpm run test / npm test / jest / vitest
# Python: pytest
# Go: go test ./...
# Rust: cargo test
```
Run this command now. If it fails, retry ONCE. Read the output. Record pass/fail.

**Layer 3 — Integration tests (if configured):**
Check if `test:integration` script exists in package.json or equivalent.
If yes, run it. If no, skip and note "not configured".

**Layer 4 — E2E (if Playwright/Cypress installed):**
Check if playwright or cypress is installed. If yes, run. If no, skip.

**Layer 5 — Lint:**
```bash
# Node: pnpm run lint / npm run lint / eslint
# Python: ruff check . / flake8
# Go: golangci-lint run
# Rust: cargo clippy
```
Run this command now. Read the output. Record pass/fail.

**Layer 6 — Type check:**
```bash
# Node: pnpm run typecheck / npx tsc --noEmit
# Python: mypy .
# Go: go vet ./...
# Rust: (covered by cargo build)
```
Run this command now. Read the output. Record pass/fail.

**Layer 7 — Security audit (warn only, never blocks):**
```bash
# Node: pnpm audit / npm audit
# Python: pip-audit
# Rust: cargo audit
```
Run if available. Record warnings but do NOT block on failures.

### Step 3.3: Parse Failures

For each failing layer, extract structured diagnostics:
- **Test failures:** file, line, test name, expected vs received
- **Lint errors:** rule, file:line, message
- **Type errors:** error code, file:line, type mismatch detail
- **Build errors:** module not found, undefined reference, etc.

Write failures to `.kova-loop/current-failures.md` with file:line detail.

### Step 3.4: Write Gate File

<CRITICAL>
You MUST write the gate file. Without it, the loop cannot proceed.
</CRITICAL>

**All blocking layers pass (1-6):**
```bash
echo "PHASE=3 RESULT=pass TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ) SUMMARY=All 6 blocking layers green" > .kova-loop/gates/item-{{ITEM_NUMBER}}-phase-3.gate
```

**Any blocking layer failed:**
```bash
echo "PHASE=3 RESULT=fail TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ) SUMMARY=Failed layers: [list]. [N] errors" > .kova-loop/gates/item-{{ITEM_NUMBER}}-phase-3.gate
```

### Step 3.5: Report Result

**Pass:**
```
Phase 3 PASS. All 6 blocking layers green. [Layer 7 warnings if any]
```

**Fail:**
```
Phase 3 FAIL. Failed layers: [list]. [N] errors with file:line diagnostics.
See .kova-loop/current-failures.md for details.
```

## Key Rules
- NEVER skip any applicable layer
- NEVER say "pass" without actually running the command and reading its output
- ALWAYS record full error output for failing layers
- ALWAYS write the gate file — the loop depends on it
- Layer 7 (security) is warn-only — it never blocks
- Retry unit/integration/E2E once before marking as failed (flaky test handling)
- If a command doesn't exist (e.g., no `test` script), skip that layer and note it

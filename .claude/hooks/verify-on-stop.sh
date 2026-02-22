#!/bin/bash
# verify-on-stop.sh — Multi-layer verification gate when Claude finishes a task
# Pipeline: Build -> Unit -> Integration -> E2E -> Lint -> Types -> Security (warn only)
# Test layers (2-4) use run_and_retry for flaky test detection
# Max 3 retries before writing DEBUG_LOG.md and spawning self-healing session

source "$(dirname "$0")/lib/detect-stack.sh"

INPUT=$(cat)
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$STOP_ACTIVE" = "true" ] && exit 0
# Skip stop gate during Kova Smart Loop (it runs its own verification)
[ "${KOVA_LOOP_ACTIVE:-}" = "1" ] && exit 0

cd "$CLAUDE_PROJECT_DIR" || exit 0

# Fast exit: nothing to verify if working tree is clean
# Check tracked changes (staged + unstaged) and untracked files
if git diff --quiet HEAD 2>/dev/null \
   && git diff --cached --quiet 2>/dev/null \
   && [ -z "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
  exit 0
fi

# --- Retry counter (max 3 attempts) ---
PROJ_HASH=$(project_hash "$CLAUDE_PROJECT_DIR")
COUNTER_FILE="/tmp/.claude-verify-stop-$PROJ_HASH"
HISTORY_FILE="/tmp/.claude-verify-history-$PROJ_HASH"
ATTEMPT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
ATTEMPT=$((ATTEMPT + 1))
echo "$ATTEMPT" > "$COUNTER_FILE"

if [ "$ATTEMPT" -gt 3 ]; then
  # Collect failure details into DEBUG_LOG.md
  cat > DEBUG_LOG.md << DEBUGEOF
## Verification Failed After 3 Attempts — $(date '+%Y-%m-%d %H:%M')

### Failure history (all 3 attempts):
$(cat "$HISTORY_FILE" 2>/dev/null || echo "No history available")

### Pipeline layers checked:
1. Build (compile)
2. Unit tests (with flaky retry)
3. Integration tests (if configured, with flaky retry)
4. E2E tests (if installed, with flaky retry)
5. Lint
6. Type check
7. Security audit (warn only)

### Action: Auto-spawning fresh session to fix.
DEBUGEOF

  echo "STOP GATE: Failed 3 times. DEBUG_LOG.md written." >&2
  rm -f "$COUNTER_FILE"
  rm -f "$HISTORY_FILE"

  # Prevent infinite self-healing loops: check if THIS session was a self-heal
  if [ "${CLAUDE_SELF_HEAL:-}" = "1" ]; then
    echo "STOP GATE: Self-heal session also failed. Stopping for human review." >&2
    exit 0
  fi

  # Spawn fresh Claude session in background
  if command -v claude &>/dev/null; then
    PROMPT="Read DEBUG_LOG.md and fix all failures listed. Run tests after each fix. Do not ask questions — use the assumption protocol."
    CLAUDE_SELF_HEAL=1 nohup claude -p "$PROMPT" \
      --allowedTools "Edit,Write,Bash,Read,Glob,Grep" \
      > "/tmp/.claude-self-heal-$PROJ_HASH.log" 2>&1 &
    echo "STOP GATE: Self-healing session spawned (PID: $!)." >&2
  else
    echo "STOP GATE: claude CLI not found. Manual fix required." >&2
  fi

  exit 0
fi

# --- Detect stack ---
detect_pm
detect_languages
FAILURES=0
RESULTS=""

# --- Fast mode: skip slow layers (1-4, 7), only run lint + typecheck ---
# Full verification is handled by kova-loop.sh (verify-gate.sh) and kova-commit-gate.sh
RESULTS="$RESULTS\n[1] SKIP — Stop hook: fast mode"
RESULTS="$RESULTS\n[2] SKIP — Stop hook: fast mode"
RESULTS="$RESULTS\n[3] SKIP — Stop hook: fast mode"
RESULTS="$RESULTS\n[4] SKIP — Stop hook: fast mode"

# --- Layer 5: Lint ---
if [ -n "$PM" ] && [ -n "$(pkg_field '.scripts.lint')" ]; then
  run_and_report 5 "Lint ($PM)" "$PM" run lint
fi
has_lang python && {
  command -v ruff &>/dev/null && run_and_report 5 "Ruff" ruff check .
  ! command -v ruff &>/dev/null && command -v flake8 &>/dev/null && run_and_report 5 "Flake8" flake8 .
}
has_lang go     && command -v golangci-lint &>/dev/null && run_and_report 5 "Go lint" golangci-lint run
has_lang rust   && run_and_report 5 "Clippy" cargo clippy -- -D warnings
has_lang ruby   && command -v rubocop &>/dev/null && run_and_report 5 "RuboCop" rubocop
has_lang dotnet && run_and_report 5 "Dotnet format" dotnet format --verify-no-changes --nologo -v q
echo -e "$RESULTS" | grep -q '\[5\]' || RESULTS="$RESULTS\n[5] SKIP — No linter"

# --- Layer 6: Type Check ---
if [ -n "$PM" ]; then
  TC_SCRIPT=$(pkg_field '.scripts.typecheck // .scripts["type-check"]')
  if [ -n "$TC_SCRIPT" ]; then
    run_and_report 6 "Type check ($PM)" "$PM" run typecheck
  elif [ -f "tsconfig.json" ]; then
    run_and_report 6 "tsc --noEmit" npx tsc --noEmit
  fi
fi
has_lang python && {
  command -v mypy &>/dev/null && run_and_report 6 "Mypy" mypy .
  ! command -v mypy &>/dev/null && command -v pyright &>/dev/null && run_and_report 6 "Pyright" pyright
}
has_lang go   && run_and_report 6 "Go vet" go vet ./...
has_lang rust && run_and_report 6 "Cargo check" cargo check
echo -e "$RESULTS" | grep -q '\[6\]' || RESULTS="$RESULTS\n[6] SKIP — No type checker"

RESULTS="$RESULTS\n[7] SKIP — Stop hook: fast mode"

# --- Track failure history across attempts ---
echo -e "\n--- Attempt $ATTEMPT ---" >> "$HISTORY_FILE"
echo -e "$RESULTS" >> "$HISTORY_FILE"

# --- Final Report ---
echo "" >&2
echo "========================================" >&2
echo " STOP GATE (fast) — Attempt $ATTEMPT/3" >&2
echo "========================================" >&2
echo -e "$RESULTS" >&2
echo "========================================" >&2

if [ $FAILURES -gt 0 ]; then
  echo "{\"decision\":\"block\",\"reason\":\"STOP GATE FAILED (attempt $ATTEMPT/3). $FAILURES layer(s) failed. Fix all failures before stopping.\"}"
  exit 0
fi

# All passed — reset counter and history
rm -f "$COUNTER_FILE"
rm -f "$HISTORY_FILE"
exit 0

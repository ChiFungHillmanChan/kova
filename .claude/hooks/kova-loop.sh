#!/bin/bash
# kova-loop.sh — Kova Smart Loop orchestrator
# Usage: bash .claude/hooks/kova-loop.sh <prd-file> [options]
# Options: --max-iterations N | --max-fix-attempts N | --no-commit | --dry-run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

source "$LIB_DIR/detect-stack.sh"
source "$LIB_DIR/parse-prd.sh"
source "$LIB_DIR/generate-prompt.sh"
source "$LIB_DIR/parse-failures.sh"
source "$LIB_DIR/verify-gate.sh"
source "$LIB_DIR/run-code-review.sh"
source "$LIB_DIR/rate-limiter.sh"
source "$LIB_DIR/circuit-breaker.sh"

PRD_FILE=""
MAX_ITERATIONS=20
MAX_FIX_ATTEMPTS=5
NO_COMMIT=false
DRY_RUN=false
STATE_DIR=".kova-loop"

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --max-iterations)   MAX_ITERATIONS="$2"; shift 2 ;;
      --max-fix-attempts) MAX_FIX_ATTEMPTS="$2"; shift 2 ;;
      --no-commit)        NO_COMMIT=true; shift ;;
      --dry-run)          DRY_RUN=true; shift ;;
      -*)                 echo "Unknown option: $1" >&2; exit 1 ;;
      *)                  PRD_FILE="$1"; shift ;;
    esac
  done
  if [ -z "$PRD_FILE" ]; then
    echo "Usage: kova-loop.sh <prd-file> [--max-iterations N] [--max-fix-attempts N] [--no-commit] [--dry-run]" >&2
    exit 1
  fi
}

write_progress() {
  local current_item="$1" current_mode="$2" iteration="$3"
  {
    echo "# Kova Loop Progress"
    echo "Started: $(date '+%Y-%m-%d %H:%M') | PRD: $PRD_FILE ($PRD_ITEM_COUNT items)"
    echo ""
    local idx=0
    for item in "${PRD_ITEMS[@]}"; do
      idx=$((idx + 1))
      if [ "$idx" -lt "$current_item" ]; then
        local hash; hash=$(cat "$STATE_DIR/commit-item-$idx.txt" 2>/dev/null || echo "n/a")
        echo "- [x] $idx. $item (commit $hash)"
      elif [ "$idx" -eq "$current_item" ]; then
        echo "- [ ] $idx. $item (IN PROGRESS, mode: $current_mode)"
      else
        echo "- [ ] $idx. $item"
      fi
    done
    echo ""
    echo "Stats: $iteration/$MAX_ITERATIONS iterations | $((current_item - 1))/$PRD_ITEM_COUNT items done | mode: $current_mode"
  } > "$STATE_DIR/LOOP_PROGRESS.md"
}

log_iteration() {
  local iteration="$1" item_num="$2" mode="$3" result="$4" detail="$5"
  {
    echo ""
    echo "## Iteration $iteration — Item $item_num — Mode: $mode"
    echo "Time: $(date '+%Y-%m-%d %H:%M:%S') | Result: $result"
    [ -n "$detail" ] && echo "Detail: $detail"
    echo "---"
  } >> "$STATE_DIR/ITERATION_LOG.md"
}

# Record a stuck item and advance to the next PRD item
record_stuck_item() {
  local item_num="$1" item_text="$2" attempts="$3" last_mode="$4"
  echo "  STUCK: $attempts attempts on item $item_num. Skipping." >&2
  {
    echo ""
    echo "## Stuck Item $item_num"
    echo "Item: $item_text"
    echo "Fix attempts: $attempts | Last mode: $last_mode"
    [ -f "$STATE_DIR/parsed-failures-latest.md" ] && cat "$STATE_DIR/parsed-failures-latest.md"
  } >> "$STATE_DIR/STUCK_ITEMS.md"
}

run_claude_with_prompt() {
  local prompt_file="$1" output_file="$2"
  if ! command -v claude &>/dev/null; then
    echo "ERROR: claude CLI not found." >&2; return 1
  fi
  local prompt_content; prompt_content=$(cat "$prompt_file")
  KOVA_LOOP_ACTIVE=1 claude -p "$prompt_content" \
    --allowedTools "Edit,Write,Bash,Read,Glob,Grep" \
    --output-format text > "$output_file" 2>&1
  return $?
}

commit_item() {
  local item_num="$1" item_text="$2"
  if $NO_COMMIT; then echo "no-commit" > "$STATE_DIR/commit-item-$item_num.txt"; return 0; fi
  git add -A 2>/dev/null || true
  # Unstage sensitive files that shouldn't be committed
  git reset HEAD -- '*.env' '*.env.*' '*.pem' '*.key' 'secrets/' 'credentials/' 2>/dev/null || true
  if git diff --cached --quiet 2>/dev/null; then
    echo "nothing-to-commit" > "$STATE_DIR/commit-item-$item_num.txt"; return 0
  fi
  local short_desc; short_desc=$(echo "$item_text" | head -c 60)
  if ! git commit -m "feat(loop): $short_desc

Kova Smart Loop — PRD item $item_num
PRD: $PRD_FILE

Co-Authored-By: Claude <noreply@anthropic.com>" 2>/dev/null; then
    echo "COMMIT_ERROR" > "$STATE_DIR/commit-item-$item_num.txt"
    echo "  ERROR: git commit failed for item $item_num" >&2
    return 1
  fi
  local hash; hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
  echo "$hash" > "$STATE_DIR/commit-item-$item_num.txt"
  echo "Committed item $item_num: $hash" >&2
}

main() {
  parse_args "$@"
  detect_pm; detect_languages

  if ! parse_prd "$PRD_FILE"; then echo "Failed to parse PRD. Exiting." >&2; exit 1; fi

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  echo " KOVA SMART LOOP" >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  print_prd_items >&2
  echo "Config: max $MAX_ITERATIONS iterations, $MAX_FIX_ATTEMPTS fix attempts/item" >&2
  echo "Stack: PM=$PM LANGS=$LANGS" >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2

  if $DRY_RUN; then echo "DRY RUN — no changes will be made." >&2; exit 0; fi

  mkdir -p "$STATE_DIR"; : > "$STATE_DIR/ITERATION_LOG.md"
  rate_limit_init "$STATE_DIR"

  local completed_context=""
  for item in "${PRD_COMPLETED[@]}"; do
    [ -n "$item" ] && completed_context="$completed_context\n- [x] $item"
  done

  local iteration=0 current_item=1 fix_attempts=0 mode="implement"
  local consecutive_stuck_items=0
  local no_progress_count=0
  local last_diff_stat=""

  while [ "$current_item" -le "$PRD_ITEM_COUNT" ] && [ "$iteration" -lt "$MAX_ITERATIONS" ]; do
    iteration=$((iteration + 1))
    local item_text="${PRD_ITEMS[$((current_item - 1))]}"

    # Circuit breaker check at top of each iteration
    if ! circuit_breaker_check "$consecutive_stuck_items" "$no_progress_count"; then
      circuit_breaker_report "$STATE_DIR" "$CIRCUIT_BREAKER_REASON" "$iteration" "$MAX_ITERATIONS" "$current_item" "$PRD_ITEM_COUNT"
      log_iteration "$iteration" "$current_item" "$mode" "CIRCUIT_BREAKER" "$CIRCUIT_BREAKER_REASON"
      exit 2
    fi

    write_progress "$current_item" "$mode" "$iteration"
    echo "--- Iteration $iteration: Item $current_item/$PRD_ITEM_COUNT (mode: $mode) ---" >&2
    echo "  $item_text" >&2

    # Step 1: Generate prompt
    local prompt_file="$STATE_DIR/NEXT_PROMPT.md"
    case "$mode" in
      implement)  generate_implement_prompt "$item_text" "$current_item" "$PRD_ITEM_COUNT" "$completed_context" "$prompt_file" ;;
      fix-verify) generate_fix_verify_prompt "$STATE_DIR/parsed-failures-latest.md" "$STATE_DIR/verify-output-latest.log" "$fix_attempts" "$MAX_FIX_ATTEMPTS" "$prompt_file" ;;
      fix-review) generate_fix_review_prompt "$STATE_DIR/review-output-latest.log" "$fix_attempts" "$prompt_file" ;;
    esac

    # Step 2: Rate limit check + Run Claude
    if ! rate_limit_check; then
      echo "  Rate limit: ${RATE_LIMIT_CURRENT}/${MAX_INVOCATIONS_PER_HOUR:-100} per hour" >&2
      rate_limit_wait
    fi

    local claude_output="$STATE_DIR/claude-output-$iteration.log"
    echo "  Running Claude..." >&2
    if ! run_claude_with_prompt "$prompt_file" "$claude_output"; then
      log_iteration "$iteration" "$current_item" "$mode" "CLAUDE_ERROR" "exit $?"
      fix_attempts=$((fix_attempts + 1))
      if [ "$fix_attempts" -ge "$MAX_FIX_ATTEMPTS" ]; then
        record_stuck_item "$current_item" "$item_text" "$fix_attempts" "$mode"
        current_item=$((current_item + 1)); fix_attempts=0; mode="implement"
        consecutive_stuck_items=$((consecutive_stuck_items + 1))
      fi
      continue
    fi

    rate_limit_record

    # Check for API rate limit in Claude output
    if detect_api_limit "$claude_output"; then
      echo "  API rate limit detected in output. Waiting 300s..." >&2
      rate_limit_wait 300
    fi

    # Track progress for circuit breaker (file changes since last check)
    local current_diff_stat
    current_diff_stat=$(git diff --stat HEAD 2>/dev/null || echo "")
    if [ "$current_diff_stat" = "$last_diff_stat" ]; then
      no_progress_count=$((no_progress_count + 1))
    else
      no_progress_count=0
      last_diff_stat="$current_diff_stat"
    fi

    # Step 3: Verify
    local verify_output="$STATE_DIR/verify-output-$iteration.log"
    : > "$STATE_DIR/verify-output-latest.log"
    echo "  Running verification gate..." >&2

    if run_verify_gate "$verify_output"; then
      cp "$verify_output" "$STATE_DIR/verify-output-latest.log"
      log_iteration "$iteration" "$current_item" "$mode" "VERIFY_PASS" ""
      echo "  Verification passed. Running code review..." >&2
      local review_output="$STATE_DIR/review-output-$iteration.log"
      run_review "$review_output"
      cp "$review_output" "$STATE_DIR/review-output-latest.log"

      case "$REVIEW_RESULT" in
        CLEAN|LOW_ONLY)
          echo "  Review: $REVIEW_RESULT. Item $current_item complete!" >&2
          log_iteration "$iteration" "$current_item" "$mode" "ITEM_DONE" "review=$REVIEW_RESULT"
          if ! commit_item "$current_item" "$item_text"; then
            log_iteration "$iteration" "$current_item" "$mode" "COMMIT_ERROR" "git commit failed"
            fix_attempts=$((fix_attempts + 1)); mode="fix-review"
          else
            completed_context="$completed_context\n- [x] $item_text"
            current_item=$((current_item + 1)); fix_attempts=0; mode="implement"
            consecutive_stuck_items=0
            no_progress_count=0
          fi ;;
        HIGH|ERROR)
          echo "  Review: $REVIEW_RESULT — needs attention." >&2
          log_iteration "$iteration" "$current_item" "$mode" "REVIEW_$REVIEW_RESULT" ""
          fix_attempts=$((fix_attempts + 1)); mode="fix-review" ;;
      esac
    else
      cp "$verify_output" "$STATE_DIR/verify-output-latest.log"
      echo "  Verification failed ($FAILURES layer(s)). Parsing failures..." >&2
      parse_all_failures "$verify_output" "$STATE_DIR/parsed-failures-latest.md"
      log_iteration "$iteration" "$current_item" "$mode" "VERIFY_FAIL" "$FAILURES layers failed"
      fix_attempts=$((fix_attempts + 1))
      if [ "$fix_attempts" -ge "$MAX_FIX_ATTEMPTS" ]; then
        record_stuck_item "$current_item" "$item_text" "$fix_attempts" "$mode"
        current_item=$((current_item + 1)); fix_attempts=0; mode="implement"
        consecutive_stuck_items=$((consecutive_stuck_items + 1))
      else
        mode="fix-verify"
      fi
    fi
  done

  write_progress "$current_item" "done" "$iteration"
  local completed=$((current_item - 1))
  [ "$completed" -gt "$PRD_ITEM_COUNT" ] && completed=$PRD_ITEM_COUNT
  local stuck_count=0
  [ -f "$STATE_DIR/STUCK_ITEMS.md" ] && stuck_count=$(grep -c "## Stuck Item" "$STATE_DIR/STUCK_ITEMS.md" 2>/dev/null || echo "0")

  echo "" >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  echo " KOVA SMART LOOP — COMPLETE" >&2
  echo " Items: $completed/$PRD_ITEM_COUNT | Iterations: $iteration/$MAX_ITERATIONS | Stuck: $stuck_count | API calls: $RATE_LIMIT_CURRENT" >&2
  echo " Progress: $STATE_DIR/LOOP_PROGRESS.md | Log: $STATE_DIR/ITERATION_LOG.md" >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2

  [ "$completed" -lt "$PRD_ITEM_COUNT" ] && exit 1
  exit 0
}

main "$@"

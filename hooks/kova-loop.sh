#!/bin/bash
# kova-loop.sh — Kova Smart Loop orchestrator
# Usage: bash hooks/kova-loop.sh <prd-file> [options]
# Options: --max-iterations N | --max-fix-attempts N | --no-commit | --dry-run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
# Fallback for when invoked with CLAUDE_PLUGIN_ROOT (plugin mode)
[ -d "$LIB_DIR" ] || LIB_DIR="${CLAUDE_PLUGIN_ROOT:-$SCRIPT_DIR}/hooks/lib"

source "$LIB_DIR/detect-stack.sh"
source "$LIB_DIR/parse-prd.sh"
source "$LIB_DIR/generate-prompt.sh"
source "$LIB_DIR/parse-failures.sh"
source "$LIB_DIR/verify-gate.sh"
source "$LIB_DIR/run-code-review.sh"
source "$LIB_DIR/rate-limiter.sh"
source "$LIB_DIR/circuit-breaker.sh"
source "$LIB_DIR/codex-assist.sh"

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

# Snapshot the working tree state before Claude runs an iteration.
# Call this BEFORE run_claude_with_prompt to capture the baseline.
# Saves: tracked file mtimes + list of untracked files.
snapshot_pre_iteration() {
  # List of tracked files with their status (M/D/A/etc)
  git diff --name-only HEAD 2>/dev/null | sort > "$STATE_DIR/.pre-tracked"
  # List of all untracked files (excluding .gitignore'd)
  git ls-files --others --exclude-standard 2>/dev/null | sort > "$STATE_DIR/.pre-untracked"
  : > "$STATE_DIR/.pre-tracked-hashes"

  local tracked_file
  while IFS= read -r tracked_file; do
    [ -z "$tracked_file" ] && continue
    printf '%s\t%s\n' "$tracked_file" "$(working_tree_hash "$tracked_file")" >> "$STATE_DIR/.pre-tracked-hashes"
  done < "$STATE_DIR/.pre-tracked"
}

# Hash the current working-tree contents for a tracked path so we can tell
# whether a file that was already dirty changed again during this iteration.
working_tree_hash() {
  local path="$1"
  if [ -e "$path" ]; then
    git hash-object --no-filters -- "$path" 2>/dev/null || echo "__HASH_ERROR__"
  else
    echo "__MISSING__"
  fi
}

# Stage only files that changed SINCE the pre-iteration snapshot.
# This ensures only files Claude touched get committed — pre-existing
# dirty work in the working tree is left alone.
stage_item_changes() {
  # Current state
  git diff --name-only HEAD 2>/dev/null | sort > "$STATE_DIR/.post-tracked"
  git ls-files --others --exclude-standard 2>/dev/null | sort > "$STATE_DIR/.post-untracked"

  # Newly modified tracked files = in post but not pre (or changed since)
  local changed_file
  # Stage tracked files that are new or changed since snapshot
  comm -13 "$STATE_DIR/.pre-tracked" "$STATE_DIR/.post-tracked" 2>/dev/null | while IFS= read -r changed_file; do
    [ -n "$changed_file" ] && git add -- "$changed_file" 2>/dev/null || true
  done
  # Stage tracked files that were already dirty only if their contents changed
  # after the snapshot. This keeps unrelated pre-existing edits out of the commit.
  comm -12 "$STATE_DIR/.pre-tracked" "$STATE_DIR/.post-tracked" 2>/dev/null | while IFS= read -r changed_file; do
    [ -z "$changed_file" ] && continue

    local pre_hash post_hash
    pre_hash=$(awk -F '\t' -v target="$changed_file" '$1 == target { print $2; exit }' "$STATE_DIR/.pre-tracked-hashes")
    post_hash=$(working_tree_hash "$changed_file")

    if [ -n "$pre_hash" ] && [ "$pre_hash" != "$post_hash" ]; then
      git add -- "$changed_file" 2>/dev/null || true
    fi
  done

  # Stage only NEW untracked files (not present before Claude ran)
  comm -13 "$STATE_DIR/.pre-untracked" "$STATE_DIR/.post-untracked" 2>/dev/null | while IFS= read -r changed_file; do
    [ -z "$changed_file" ] && continue
    # Skip sensitive files
    case "$changed_file" in
      *.env|*.env.*|*.pem|*.key|*.p12|*.pfx|*.jks) continue ;;
      secrets/*|credentials/*|.secrets/*|.credentials/*) continue ;;
      *) git add -- "$changed_file" 2>/dev/null || true ;;
    esac
  done

  # Safety net: unstage any sensitive files
  git reset HEAD -- '*.env' '*.env.*' '*.pem' '*.key' '*.p12' '*.pfx' '*.jks' \
    'secrets/' 'credentials/' '.secrets/' '.credentials/' >/dev/null 2>&1 || true
}

commit_item() {
  local item_num="$1" item_text="$2"
  if $NO_COMMIT; then echo "no-commit" > "$STATE_DIR/commit-item-$item_num.txt"; return 0; fi

  # Stage only files Claude changed in this iteration (diff against pre-snapshot)
  stage_item_changes

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

# Attempt Codex cross-model diagnosis if fix_attempts has reached the threshold.
# Usage: _maybe_escalate_to_codex <context_file>
# Reads from outer scope: fix_attempts, codex_threshold, STATE_DIR, iteration, current_item, mode
_maybe_escalate_to_codex() {
  local context_file="$1"
  [ "$codex_threshold" -gt 0 ] && [ "$fix_attempts" -eq "$codex_threshold" ] || return 0
  echo "  Escalating to Codex for cross-model diagnosis..." >&2
  local codex_diag="$STATE_DIR/codex-diagnosis-latest.md"
  if codex_diagnose "$context_file" "$codex_diag"; then
    log_iteration "$iteration" "$current_item" "$mode" "CODEX_DIAGNOSE" "success"
  else
    rm -f "$codex_diag"
    log_iteration "$iteration" "$current_item" "$mode" "CODEX_DIAGNOSE" "skipped"
  fi
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
  if [ "$PRD_COMPLETED_COUNT" -gt 0 ]; then
    for item in "${PRD_COMPLETED[@]}"; do
      [ -n "$item" ] && completed_context="$completed_context\n- [x] $item"
    done
  fi

  local iteration=0 current_item=1 fix_attempts=0 mode="implement"
  local consecutive_stuck_items=0
  local no_progress_count=0
  local last_diff_stat=""
  local codex_threshold=$(( MAX_FIX_ATTEMPTS > 3 ? 3 : MAX_FIX_ATTEMPTS - 1 ))
  [ "$codex_threshold" -lt 1 ] && codex_threshold=0

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
    # Snapshot working tree state before Claude modifies anything
    snapshot_pre_iteration
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
          fix_attempts=$((fix_attempts + 1))
          _maybe_escalate_to_codex "$STATE_DIR/review-output-latest.log"
          mode="fix-review" ;;
      esac
    else
      cp "$verify_output" "$STATE_DIR/verify-output-latest.log"
      echo "  Verification failed ($FAILURES layer(s)). Parsing failures..." >&2
      parse_all_failures "$verify_output" "$STATE_DIR/parsed-failures-latest.md"
      log_iteration "$iteration" "$current_item" "$mode" "VERIFY_FAIL" "$FAILURES layers failed"
      fix_attempts=$((fix_attempts + 1))
      _maybe_escalate_to_codex "$STATE_DIR/parsed-failures-latest.md"
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

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi

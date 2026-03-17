#!/bin/bash
# run-code-review.sh — Lightweight code review between loop iterations
# Source this file: source "$(dirname "$0")/lib/run-code-review.sh"
#
# Runs a focused code review on recent changes, looking for HIGH-severity
# issues only (security vulnerabilities, logic bugs, missing error handling).
#
# Returns via REVIEW_RESULT:
#   "CLEAN"    — no issues found
#   "HIGH"     — HIGH-severity issues found (must fix)
#   "LOW_ONLY" — only low-severity issues (acceptable, continue)
#   "ERROR"    — review failed to run

# Run a lightweight code review on uncommitted changes (staged + unstaged vs HEAD)
# Usage: run_review <output_file>
# Sets: REVIEW_RESULT ("CLEAN", "HIGH", "LOW_ONLY", "ERROR")
run_review() {
  local output_file="$1"
  REVIEW_RESULT="CLEAN"

  # Get the diff to review
  local diff_content
  diff_content=$(git diff HEAD 2>/dev/null)

  if [ -z "$diff_content" ]; then
    # No committed changes to review — try staged/unstaged
    diff_content=$(git diff --cached 2>/dev/null)
  fi

  if [ -z "$diff_content" ]; then
    echo "No changes to review." > "$output_file"
    REVIEW_RESULT="CLEAN"
    return 0
  fi

  # Check if claude CLI is available
  if ! command -v claude &>/dev/null; then
    echo "WARNING: claude CLI not found. Skipping code review." > "$output_file"
    REVIEW_RESULT="ERROR"
    return 0
  fi

  # Build prompt with diff content inline
  local full_prompt="You are a senior code reviewer. Review the following git diff for HIGH-severity issues ONLY.

HIGH-severity issues (report these):
- Security vulnerabilities (injection, XSS, hardcoded secrets, auth bypass)
- Logic bugs (wrong conditions, off-by-one, null derefs, race conditions)
- Missing error handling that could crash in production
- Data loss risks

LOW-severity issues (mention briefly but do not flag as HIGH):
- Style/formatting
- Minor naming improvements
- Documentation gaps
- Performance micro-optimizations

Output format:
- Start with SEVERITY: HIGH or SEVERITY: LOW_ONLY or SEVERITY: CLEAN
- For HIGH issues, list each as: HIGH: file:line - description
- For LOW issues, list as: LOW: description
- Be specific with file paths and line numbers
- Keep it concise

Here is the diff:

$diff_content"

  # Run the review (read-only tools only)
  local review_output
  review_output=$(claude -p "$full_prompt" \
    --allowedTools "Read,Glob,Grep" \
    --output-format text 2>/dev/null)

  local exit_code=$?

  if [ $exit_code -ne 0 ] || [ -z "$review_output" ]; then
    echo "Code review failed to run (exit code: $exit_code)." > "$output_file"
    REVIEW_RESULT="ERROR"
    return 1
  fi

  echo "$review_output" > "$output_file"

  # Parse the severity from the output
  if echo "$review_output" | grep -qi "SEVERITY:.*HIGH"; then
    REVIEW_RESULT="HIGH"
  elif echo "$review_output" | grep -qi "SEVERITY:.*CLEAN"; then
    REVIEW_RESULT="CLEAN"
  else
    # shellcheck disable=SC2034
    REVIEW_RESULT="LOW_ONLY"
  fi

  # Optional: Cross-model review via Codex
  if type codex_available &>/dev/null && codex_available; then
    local _review_tmp="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/kova-review-$$"
    mkdir -p "$_review_tmp" 2>/dev/null
    chmod 700 "$_review_tmp" 2>/dev/null
    local codex_diff="$_review_tmp/diff.txt"
    local codex_rev="$_review_tmp/codex-review.md"
    echo "$diff_content" > "$codex_diff"
    if codex_review "$codex_diff" "$codex_rev"; then
      echo "" >> "$output_file"
      echo "---" >> "$output_file"
      cat "$codex_rev" >> "$output_file"
      # Elevate if Codex found HIGH issues Claude missed
      if [ "$REVIEW_RESULT" != "HIGH" ] && grep -qi "SEVERITY:.*HIGH" "$codex_rev"; then
        REVIEW_RESULT="HIGH"
      fi
    fi
    rm -rf "$_review_tmp"
  fi

  return 0
}

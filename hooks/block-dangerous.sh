#!/bin/bash
# block-dangerous.sh — Block catastrophic commands before Claude runs them
# Runs on PreToolUse for Bash

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$CMD" ]; then
  exit 0
fi

# Normalize a command string for safer pattern matching.
# Strips quotes, backslash escapes, and collapses whitespace so that
# obfuscated variants like  'rm' "-rf" /  still match blocked patterns.
normalize_cmd() {
  local c="$1"
  # Remove backslash escapes (e.g. r\m -> rm). Use | delimiter to avoid
  # ambiguity with / in sed — s/\\//g would also strip forward slashes.
  c=$(printf '%s' "$c" | sed 's|\\||g')
  # Remove single and double quotes
  c=$(printf '%s' "$c" | tr -d "\"'")
  # Collapse runs of whitespace into a single space
  c=$(printf '%s' "$c" | tr -s '[:space:]' ' ')
  # Trim leading/trailing whitespace
  c=$(printf '%s' "$c" | sed 's/^ //;s/ $//')
  printf '%s' "$c"
}

# Extract the inner command from wrapper invocations like:
#   eval 'rm -rf /'
#   bash -c "rm -rf /"
#   sh -c 'DROP TABLE foo'
extract_inner_cmd() {
  local c="$1"
  if printf '%s' "$c" | grep -qiE '^\s*(eval|bash\s+-c|sh\s+-c)\s+'; then
    printf '%s' "$c" | sed -E 's/^\s*(eval|bash\s+-c|sh\s+-c)\s+//I'
  fi
}

NORM_CMD=$(normalize_cmd "$CMD")
INNER_CMD=$(extract_inner_cmd "$NORM_CMD")
NORM_INNER=""
[ -n "$INNER_CMD" ] && NORM_INNER=$(normalize_cmd "$INNER_CMD")

# Patterns that are always blocked
BLOCKED_PATTERNS=(
  "rm -rf /"
  "rm -rf ~"
  "rm -rf \$HOME"
  "git push --force"
  "git push -f"
  "DROP TABLE"
  "DROP DATABASE"
  "TRUNCATE TABLE"
  "rm -rf *"
  "> /dev/sda"
  "mkfs"
  "dd if="
  ":(){:|:&};:"
)

# Check a string against all blocked patterns.
# Returns 0 (match) or 1 (no match). Prints the matched pattern on stdout.
_check_blocked() {
  local text="$1"
  for pattern in "${BLOCKED_PATTERNS[@]}"; do
    if printf '%s' "$text" | grep -qiF "$pattern"; then
      # --force-with-lease is semi-dangerous (warned), not catastrophic — don't block it
      if { [ "$pattern" = "git push --force" ] || [ "$pattern" = "git push -f" ]; } \
         && printf '%s' "$text" | grep -qiF "force-with-lease"; then
        continue
      fi
      printf '%s' "$pattern"
      return 0
    fi
  done
  return 1
}

# Also block commands containing $() or backtick substitutions that embed
# dangerous patterns (e.g.  $(rm -rf /)  or  `rm -rf /` ).
_check_subshell() {
  local text="$1"
  local sub=""
  # Extract content inside $(...) — greedy single match is sufficient
  sub=$(printf '%s' "$text" | sed -n 's/.*\$(\(.*\)).*/\1/p')
  [ -z "$sub" ] && sub=$(printf '%s' "$text" | sed -n 's/.*`\(.*\)`.*/\1/p')
  if [ -n "$sub" ]; then
    local norm_sub
    norm_sub=$(normalize_cmd "$sub")
    _check_blocked "$norm_sub" && return 0
  fi
  return 1
}

matched=""
# Check the raw command first (catches exact matches)
matched=$(_check_blocked "$CMD") ||
# Check the normalized form (catches quote/backslash obfuscation)
matched=$(_check_blocked "$NORM_CMD") ||
# Check inner command from eval/bash -c/sh -c wrappers
{ [ -n "$NORM_INNER" ] && matched=$(_check_blocked "$NORM_INNER"); } ||
# Check for dangerous subshell substitutions
matched=$(_check_subshell "$CMD") ||
matched=$(_check_subshell "$NORM_CMD") ||
true

if [ -n "$matched" ]; then
  echo "BLOCKED: Dangerous command detected: \"$matched\"" >&2
  echo '{"decision":"block","reason":"This command matches a dangerous pattern and has been blocked by Kova safety protocol. If you genuinely need to run this, ask the human explicitly."}'
  exit 0
fi

# Warn (but allow) for semi-dangerous patterns
WARN_PATTERNS=(
  "rm -rf"
  "force-with-lease"
  "drop_table"
)

for pattern in "${WARN_PATTERNS[@]}"; do
  if printf '%s' "$NORM_CMD" | grep -qiF "$pattern"; then
    echo "WARNING: Potentially destructive command detected. Proceeding, but double-check." >&2
  fi
done

exit 0

#!/bin/bash
set -euo pipefail
# kavex-commit-gate.sh — PreToolUse hook for Bash(git commit*)
# Blocks git commit if kavex loop is active and verification gate hasn't passed.
# Safety net: even if Claude tries to commit during a loop iteration,
# this hook ensures verification ran first.

_HOOK_DIR="$(dirname "$0")"
[ -d "$_HOOK_DIR/lib" ] || _HOOK_DIR="${CLAUDE_PLUGIN_ROOT:-$_HOOK_DIR}/hooks"
source "$_HOOK_DIR/lib/require-jq.sh"
source "$_HOOK_DIR/lib/kavex-config.sh"

# Skip safety when explicitly opted out (kavex config --dangerously-skip-safety)
if kavex_skip_safety; then
  exit 0
fi

if ! require_jq; then
  echo '{"decision":"block","reason":"KAVEX: jq is not installed. Cannot verify commit safety. Install jq to proceed."}'
  exit 0
fi

INPUT=$(cat)
if ! TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null); then
  echo '{"decision":"block","reason":"KAVEX: Failed to parse hook input. Blocking for safety."}'
  exit 0
fi

# Only gate git commit commands
case "$TOOL_INPUT" in
  git\ commit*) ;;
  *) exit 0 ;;
esac

# If not in a kavex loop, let it through (the Stop hook handles non-loop verification)
STATE_DIR=".kavex-loop"
[ ! -d "$STATE_DIR" ] && exit 0

# Check if any verification output exists from the CURRENT iteration
# The bash orchestrator writes verify-output-latest.log after running verify-gate.sh
if [ ! -f "$STATE_DIR/verify-output-latest.log" ]; then
  echo '{"decision":"block","reason":"KAVEX GATE: Cannot commit — no verification has been run. The bash orchestrator runs verification; do not commit directly."}'
  exit 0
fi

# Freshness check: verification log must be < 10 minutes old
_get_file_mtime() {
  # macOS stat vs Linux stat
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null
}
VERIFY_MTIME=$(_get_file_mtime "$STATE_DIR/verify-output-latest.log")
if [ -n "$VERIFY_MTIME" ]; then
  NOW=$(date +%s)
  AGE=$(( NOW - VERIFY_MTIME ))
  if [ "$AGE" -gt 600 ]; then
    echo '{"decision":"block","reason":"KAVEX GATE: Cannot commit — verification log is stale (>10 min old). Re-run verification."}'
    exit 0
  fi
fi

# Check if the latest verification passed (verify-gate.sh exits 0 on pass)
# The bash orchestrator only reaches commit_item() after verify passes,
# but this catches Claude trying to commit inside a `claude -p` session
LATEST_VERIFY=$(cat "$STATE_DIR/verify-output-latest.log" 2>/dev/null)
if echo "$LATEST_VERIFY" | grep -q "FAIL"; then
  echo '{"decision":"block","reason":"KAVEX GATE: Cannot commit — verification failed. Fix failures first."}'
  exit 0
fi

# Verification exists and doesn't show FAIL — allow commit
exit 0

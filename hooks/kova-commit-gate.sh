#!/bin/bash
set -euo pipefail
# kova-commit-gate.sh — PreToolUse hook for Bash(git commit*)
# Blocks git commit if kova loop is active and verification gate hasn't passed.
# Safety net: even if Claude tries to commit during a loop iteration,
# this hook ensures verification ran first.

_HOOK_DIR="$(dirname "$0")"
source "$_HOOK_DIR/lib/require-jq.sh"

if ! require_jq; then
  echo '{"decision":"block","reason":"KOVA: jq is not installed. Cannot verify commit safety. Install jq to proceed."}'
  exit 0
fi

INPUT=$(cat)
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || true)

# Only gate git commit commands
case "$TOOL_INPUT" in
  git\ commit*) ;;
  *) exit 0 ;;
esac

# If not in a kova loop, let it through (the Stop hook handles non-loop verification)
STATE_DIR=".kova-loop"
[ ! -d "$STATE_DIR" ] && exit 0

# Check if any verification output exists from the CURRENT iteration
# The bash orchestrator writes verify-output-latest.log after running verify-gate.sh
if [ ! -f "$STATE_DIR/verify-output-latest.log" ]; then
  echo '{"decision":"block","reason":"KOVA GATE: Cannot commit — no verification has been run. The bash orchestrator runs verification; do not commit directly."}'
  exit 0
fi

# Check if the latest verification passed (verify-gate.sh exits 0 on pass)
# The bash orchestrator only reaches commit_item() after verify passes,
# but this catches Claude trying to commit inside a `claude -p` session
LATEST_VERIFY=$(cat "$STATE_DIR/verify-output-latest.log" 2>/dev/null)
if echo "$LATEST_VERIFY" | grep -q "FAIL"; then
  echo '{"decision":"block","reason":"KOVA GATE: Cannot commit — verification failed. Fix failures first."}'
  exit 0
fi

# Verification exists and doesn't show FAIL — allow commit
exit 0

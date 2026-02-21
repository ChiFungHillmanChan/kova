#!/bin/bash
# circuit-breaker.sh — Circuit breaker for Kova Loop
# Stops the loop when it's clearly stuck and burning resources.
# Source this file: source "$LIB_DIR/circuit-breaker.sh"

# Set by circuit_breaker_check on trip
# shellcheck disable=SC2034
CIRCUIT_BREAKER_REASON=""

# Check if circuit breaker should trip
# Usage: circuit_breaker_check <consecutive_stuck> <no_progress_count>
# Returns: 0 = ok, 1 = tripped (should stop)
# Sets: CIRCUIT_BREAKER_REASON
circuit_breaker_check() {
  local consecutive_stuck="$1"
  local no_progress_count="$2"
  local stuck_threshold="${CIRCUIT_BREAKER_THRESHOLD:-3}"
  local no_progress_threshold="${CIRCUIT_BREAKER_NO_PROGRESS:-5}"

  CIRCUIT_BREAKER_REASON=""

  if [ "$consecutive_stuck" -ge "$stuck_threshold" ]; then
    # shellcheck disable=SC2034
    CIRCUIT_BREAKER_REASON="$consecutive_stuck consecutive items stuck (threshold: $stuck_threshold)"
    return 1
  fi

  if [ "$no_progress_count" -ge "$no_progress_threshold" ]; then
    # shellcheck disable=SC2034
    CIRCUIT_BREAKER_REASON="$no_progress_count iterations with no file changes (threshold: $no_progress_threshold)"
    return 1
  fi

  return 0
}

# Write circuit breaker report
# Usage: circuit_breaker_report <state_dir> <reason> <iteration> <max_iterations> <current_item> <total_items>
circuit_breaker_report() {
  local state_dir="$1"
  local reason="$2"
  local iteration="$3"
  local max_iterations="$4"
  local current_item="$5"
  local total_items="$6"

  {
    echo "# CIRCUIT BREAKER TRIPPED"
    echo ""
    echo "**Reason:** $reason"
    echo ""
    echo "**State at trip:**"
    echo "- Iteration: $iteration / $max_iterations"
    echo "- Current item: $current_item / $total_items"
    echo "- Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "**Action:** Loop stopped with exit code 2."
    echo ""
    echo "**Next steps:**"
    echo "1. Review STUCK_ITEMS.md and ITERATION_LOG.md for details"
    echo "2. Fix the stuck items manually or simplify the PRD"
    echo "3. Re-run the loop with \`kova loop <prd>\`"
  } > "$state_dir/CIRCUIT_BREAKER.md"

  echo "" >&2
  echo "  ╔══════════════════════════════════════════╗" >&2
  echo "  ║  CIRCUIT BREAKER TRIPPED                 ║" >&2
  echo "  ╠══════════════════════════════════════════╣" >&2
  echo "  ║  $reason" >&2
  echo "  ║  See: $state_dir/CIRCUIT_BREAKER.md      " >&2
  echo "  ╚══════════════════════════════════════════╝" >&2
  echo "" >&2
}

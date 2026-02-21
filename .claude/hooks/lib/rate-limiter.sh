#!/bin/bash
# rate-limiter.sh — Rate limiting for Kova Loop API calls
# Source this file: source "$LIB_DIR/rate-limiter.sh"

# State file path (set by rate_limit_init)
_RATE_LIMIT_STATE_FILE=""

# Current count and wait time (set by rate_limit_check)
# shellcheck disable=SC2034
RATE_LIMIT_CURRENT=0
# shellcheck disable=SC2034
RATE_LIMIT_WAIT_SECONDS=0

# Initialize rate limiter state
# Usage: rate_limit_init <state_dir>
# Creates state file if it doesn't exist
rate_limit_init() {
  local state_dir="$1"
  _RATE_LIMIT_STATE_FILE="$state_dir/.rate_limit_state"
  if [ ! -f "$_RATE_LIMIT_STATE_FILE" ]; then
    : > "$_RATE_LIMIT_STATE_FILE"
  fi
}

# Check if we're within rate limits
# Uses MAX_INVOCATIONS_PER_HOUR env var (default 100)
# Returns: 0 = ok to proceed, 1 = must wait
# Sets: RATE_LIMIT_CURRENT, RATE_LIMIT_WAIT_SECONDS
rate_limit_check() {
  local max_per_hour="${MAX_INVOCATIONS_PER_HOUR:-100}"
  local now
  now=$(date +%s)
  local cutoff=$((now - 3600))

  if [ ! -f "$_RATE_LIMIT_STATE_FILE" ]; then
    RATE_LIMIT_CURRENT=0
    RATE_LIMIT_WAIT_SECONDS=0
    return 0
  fi

  # Prune timestamps older than 1 hour and count remaining
  local tmp_file="${_RATE_LIMIT_STATE_FILE}.tmp"
  : > "$tmp_file"
  local count=0
  local oldest_in_window=""

  while IFS= read -r ts; do
    # Skip empty lines
    [ -z "$ts" ] && continue
    if [ "$ts" -gt "$cutoff" ] 2>/dev/null; then
      echo "$ts" >> "$tmp_file"
      count=$((count + 1))
      if [ -z "$oldest_in_window" ]; then
        oldest_in_window="$ts"
      fi
    fi
  done < "$_RATE_LIMIT_STATE_FILE"

  # Replace state file with pruned version
  if [ -f "$tmp_file" ]; then
    mv "$tmp_file" "$_RATE_LIMIT_STATE_FILE"
  else
    : > "$_RATE_LIMIT_STATE_FILE"
  fi

  # shellcheck disable=SC2034
  RATE_LIMIT_CURRENT=$count

  if [ "$count" -ge "$max_per_hour" ]; then
    # Calculate wait time: seconds until oldest timestamp exits the window
    if [ -n "$oldest_in_window" ]; then
      RATE_LIMIT_WAIT_SECONDS=$(( oldest_in_window + 3600 - now ))
      [ "$RATE_LIMIT_WAIT_SECONDS" -lt 1 ] && RATE_LIMIT_WAIT_SECONDS=1
    else
      RATE_LIMIT_WAIT_SECONDS=60
    fi
    return 1
  fi

  RATE_LIMIT_WAIT_SECONDS=0
  return 0
}

# Record a new API invocation timestamp
# Usage: rate_limit_record
rate_limit_record() {
  if [ -n "$_RATE_LIMIT_STATE_FILE" ]; then
    date +%s >> "$_RATE_LIMIT_STATE_FILE"
  fi
}

# Detect API rate limit errors in Claude output
# Usage: detect_api_limit <output_file>
# Returns: 0 = rate limit detected, 1 = no rate limit detected
detect_api_limit() {
  local output_file="$1"
  if [ ! -f "$output_file" ]; then
    return 1
  fi
  if grep -qi "rate limit\|too many requests\|error.*429\|status.*429\|http.*429\|rate_limit_error\|overloaded" "$output_file" 2>/dev/null; then
    return 0
  fi
  return 1
}

# Wait with countdown display on stderr
# Usage: rate_limit_wait [seconds]
# If no seconds given, uses RATE_LIMIT_WAIT_SECONDS
# For API-detected limits, caller should pass 300
rate_limit_wait() {
  local wait_secs="${1:-$RATE_LIMIT_WAIT_SECONDS}"
  [ "$wait_secs" -lt 1 ] 2>/dev/null && wait_secs=1

  echo "" >&2
  echo "  RATE LIMIT: Waiting ${wait_secs}s before next API call..." >&2

  local remaining=$wait_secs
  while [ "$remaining" -gt 0 ]; do
    printf "\r  Resuming in %ds...  " "$remaining" >&2
    sleep 1
    remaining=$((remaining - 1))
  done

  printf "\r  Rate limit wait complete.       \n" >&2
  echo "" >&2
}

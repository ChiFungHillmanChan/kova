#!/usr/bin/env bats

setup() {
  load "../helpers/test_helper"
  _common_setup

  SANDBOX="$(mktemp -d)"
  cd "$SANDBOX"
  mkdir -p ".kova-loop"

  source "$KOVA_ROOT/.claude/hooks/lib/rate-limiter.sh"
}

teardown() {
  rm -rf "$SANDBOX"
}

# --- rate_limit_init ---

@test "rate_limit_init: creates state file" {
  rate_limit_init ".kova-loop"
  [ -f ".kova-loop/.rate_limit_state" ]
}

@test "rate_limit_init: preserves existing state file" {
  echo "1700000000" > ".kova-loop/.rate_limit_state"
  rate_limit_init ".kova-loop"
  run cat ".kova-loop/.rate_limit_state"
  assert_output "1700000000"
}

# --- rate_limit_check ---

@test "rate_limit_check: returns 0 when under limit" {
  rate_limit_init ".kova-loop"
  run rate_limit_check
  assert_success
}

@test "rate_limit_check: returns 0 with no state file" {
  _RATE_LIMIT_STATE_FILE="/nonexistent/path"
  run rate_limit_check
  assert_success
}

@test "rate_limit_check: returns 1 when at limit" {
  rate_limit_init ".kova-loop"
  local now
  now=$(date +%s)
  # Write MAX_INVOCATIONS_PER_HOUR timestamps within the last hour
  export MAX_INVOCATIONS_PER_HOUR=5
  for i in $(seq 1 5); do
    echo "$((now - i))" >> ".kova-loop/.rate_limit_state"
  done
  local rc=0
  rate_limit_check || rc=$?
  assert_equal "$rc" "1"
}

@test "rate_limit_check: sets RATE_LIMIT_CURRENT" {
  rate_limit_init ".kova-loop"
  local now
  now=$(date +%s)
  echo "$((now - 10))" >> ".kova-loop/.rate_limit_state"
  echo "$((now - 20))" >> ".kova-loop/.rate_limit_state"
  rate_limit_check
  assert_equal "$RATE_LIMIT_CURRENT" "2"
}

@test "rate_limit_check: prunes old timestamps" {
  rate_limit_init ".kova-loop"
  local now
  now=$(date +%s)
  # Old timestamp (2 hours ago)
  echo "$((now - 7200))" >> ".kova-loop/.rate_limit_state"
  # Recent timestamp
  echo "$((now - 10))" >> ".kova-loop/.rate_limit_state"
  rate_limit_check
  assert_equal "$RATE_LIMIT_CURRENT" "1"
  # Old timestamp should be pruned from file
  local line_count
  line_count=$(wc -l < ".kova-loop/.rate_limit_state" | tr -d ' ')
  assert_equal "$line_count" "1"
}

@test "rate_limit_check: sets RATE_LIMIT_WAIT_SECONDS when at limit" {
  rate_limit_init ".kova-loop"
  local now
  now=$(date +%s)
  export MAX_INVOCATIONS_PER_HOUR=2
  echo "$((now - 100))" >> ".kova-loop/.rate_limit_state"
  echo "$((now - 50))" >> ".kova-loop/.rate_limit_state"
  rate_limit_check || true
  # Wait seconds should be > 0
  [ "$RATE_LIMIT_WAIT_SECONDS" -gt 0 ]
}

@test "rate_limit_check: respects custom MAX_INVOCATIONS_PER_HOUR" {
  rate_limit_init ".kova-loop"
  local now
  now=$(date +%s)
  echo "$((now - 10))" >> ".kova-loop/.rate_limit_state"
  echo "$((now - 20))" >> ".kova-loop/.rate_limit_state"
  # Default is 100, so 2 should be fine
  rate_limit_check
  local rc=$?
  assert_equal "$rc" "0"
  # But with limit of 2, should fail
  export MAX_INVOCATIONS_PER_HOUR=2
  local rc2=0
  rate_limit_check || rc2=$?
  assert_equal "$rc2" "1"
}

# --- rate_limit_record ---

@test "rate_limit_record: appends timestamp to state file" {
  rate_limit_init ".kova-loop"
  rate_limit_record
  local line_count
  line_count=$(wc -l < ".kova-loop/.rate_limit_state" | tr -d ' ')
  assert_equal "$line_count" "1"
  # Second record
  rate_limit_record
  line_count=$(wc -l < ".kova-loop/.rate_limit_state" | tr -d ' ')
  assert_equal "$line_count" "2"
}

@test "rate_limit_record: writes valid epoch timestamps" {
  rate_limit_init ".kova-loop"
  rate_limit_record
  local ts
  ts=$(cat ".kova-loop/.rate_limit_state")
  # Should be a number > 1700000000 (Nov 2023)
  [ "$ts" -gt 1700000000 ]
}

# --- detect_api_limit ---

@test "detect_api_limit: detects 'rate limit' in output" {
  echo "Error: rate limit exceeded" > output.log
  detect_api_limit output.log
}

@test "detect_api_limit: detects 'too many requests' in output" {
  echo "HTTP 429: Too Many Requests" > output.log
  detect_api_limit output.log
}

@test "detect_api_limit: detects 'try again' in output" {
  echo "Please try again later" > output.log
  detect_api_limit output.log
}

@test "detect_api_limit: detects '429' in output" {
  echo "Error 429" > output.log
  detect_api_limit output.log
}

@test "detect_api_limit: detects 'rate_limit_error' in output" {
  echo '{"error": {"type": "rate_limit_error"}}' > output.log
  detect_api_limit output.log
}

@test "detect_api_limit: detects 'overloaded' in output" {
  echo "API is overloaded" > output.log
  detect_api_limit output.log
}

@test "detect_api_limit: returns 1 for normal output" {
  echo "Successfully completed task" > output.log
  run detect_api_limit output.log
  assert_failure
}

@test "detect_api_limit: returns 1 for missing file" {
  run detect_api_limit /nonexistent/file
  assert_failure
}

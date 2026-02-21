#!/usr/bin/env bats

setup() {
  load "../helpers/test_helper"
  _common_setup

  SANDBOX="$(mktemp -d)"
  cd "$SANDBOX"
  mkdir -p ".kova-loop"

  source "$KOVA_ROOT/.claude/hooks/lib/circuit-breaker.sh"
}

teardown() {
  rm -rf "$SANDBOX"
}

# --- circuit_breaker_check ---

@test "circuit_breaker_check: returns 0 when under all thresholds" {
  run circuit_breaker_check 0 0
  assert_success
}

@test "circuit_breaker_check: returns 0 just under stuck threshold" {
  run circuit_breaker_check 2 0
  assert_success
}

@test "circuit_breaker_check: returns 1 at stuck threshold" {
  local rc=0
  circuit_breaker_check 3 0 || rc=$?
  assert_equal "$rc" "1"
}

@test "circuit_breaker_check: returns 1 above stuck threshold" {
  local rc=0
  circuit_breaker_check 5 0 || rc=$?
  assert_equal "$rc" "1"
}

@test "circuit_breaker_check: returns 0 just under no-progress threshold" {
  run circuit_breaker_check 0 4
  assert_success
}

@test "circuit_breaker_check: returns 1 at no-progress threshold" {
  local rc=0
  circuit_breaker_check 0 5 || rc=$?
  assert_equal "$rc" "1"
}

@test "circuit_breaker_check: returns 1 above no-progress threshold" {
  local rc=0
  circuit_breaker_check 0 8 || rc=$?
  assert_equal "$rc" "1"
}

@test "circuit_breaker_check: sets CIRCUIT_BREAKER_REASON for stuck items" {
  circuit_breaker_check 3 0 || true
  [[ "$CIRCUIT_BREAKER_REASON" == *"consecutive items stuck"* ]]
}

@test "circuit_breaker_check: sets CIRCUIT_BREAKER_REASON for no progress" {
  circuit_breaker_check 0 5 || true
  [[ "$CIRCUIT_BREAKER_REASON" == *"no file changes"* ]]
}

@test "circuit_breaker_check: clears reason when ok" {
  CIRCUIT_BREAKER_REASON="leftover"
  circuit_breaker_check 0 0
  assert_equal "$CIRCUIT_BREAKER_REASON" ""
}

@test "circuit_breaker_check: respects custom CIRCUIT_BREAKER_THRESHOLD" {
  export CIRCUIT_BREAKER_THRESHOLD=5
  run circuit_breaker_check 4 0
  assert_success
  local rc=0
  circuit_breaker_check 5 0 || rc=$?
  assert_equal "$rc" "1"
}

@test "circuit_breaker_check: respects custom CIRCUIT_BREAKER_NO_PROGRESS" {
  export CIRCUIT_BREAKER_NO_PROGRESS=10
  run circuit_breaker_check 0 9
  assert_success
  local rc=0
  circuit_breaker_check 0 10 || rc=$?
  assert_equal "$rc" "1"
}

@test "circuit_breaker_check: stuck items checked before no-progress" {
  # Both thresholds met — stuck items reason should win (checked first)
  circuit_breaker_check 3 5 || true
  [[ "$CIRCUIT_BREAKER_REASON" == *"consecutive items stuck"* ]]
}

# --- circuit_breaker_report ---

@test "circuit_breaker_report: creates CIRCUIT_BREAKER.md" {
  circuit_breaker_report ".kova-loop" "test reason" 5 20 2 10
  [ -f ".kova-loop/CIRCUIT_BREAKER.md" ]
}

@test "circuit_breaker_report: includes reason in report" {
  circuit_breaker_report ".kova-loop" "3 consecutive stuck" 5 20 2 10
  run cat ".kova-loop/CIRCUIT_BREAKER.md"
  assert_output --partial "3 consecutive stuck"
}

@test "circuit_breaker_report: includes iteration info" {
  circuit_breaker_report ".kova-loop" "test" 5 20 2 10
  run cat ".kova-loop/CIRCUIT_BREAKER.md"
  assert_output --partial "Iteration: 5 / 20"
  assert_output --partial "Current item: 2 / 10"
}

@test "circuit_breaker_report: includes exit code 2 note" {
  circuit_breaker_report ".kova-loop" "test" 5 20 2 10
  run cat ".kova-loop/CIRCUIT_BREAKER.md"
  assert_output --partial "exit code 2"
}

@test "circuit_breaker_report: includes next steps" {
  circuit_breaker_report ".kova-loop" "test" 5 20 2 10
  run cat ".kova-loop/CIRCUIT_BREAKER.md"
  assert_output --partial "Next steps"
  assert_output --partial "STUCK_ITEMS.md"
}

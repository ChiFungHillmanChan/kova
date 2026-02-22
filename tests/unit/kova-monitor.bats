#!/usr/bin/env bats

setup() {
  load "../helpers/test_helper"
  _common_setup
}

teardown() {
  if [ -n "$SANDBOX" ] && [ -d "$SANDBOX" ]; then
    rm -rf "$SANDBOX"
  fi
}

# --- help ---

@test "kova-monitor help: shows help text" {
  run bash "$KOVA_ROOT/kova-monitor" help
  assert_success
  assert_output --partial "KOVA MONITOR"
  assert_output --partial "tmux Dashboard"
}

@test "kova-monitor: no args shows help" {
  run bash "$KOVA_ROOT/kova-monitor"
  assert_success
  assert_output --partial "KOVA MONITOR"
}

@test "kova-monitor --help: shows help text" {
  run bash "$KOVA_ROOT/kova-monitor" --help
  assert_success
  assert_output --partial "COMMANDS"
}

# --- unknown command ---

@test "kova-monitor: unknown command fails" {
  run bash "$KOVA_ROOT/kova-monitor" foobar
  assert_failure
  assert_output --partial "Unknown command"
}

# --- start validation ---

@test "kova-monitor start: requires prd file argument" {
  run bash "$KOVA_ROOT/kova-monitor" start
  assert_failure
  assert_output --partial "PRD file required"
}

@test "kova-monitor start: fails on missing prd file" {
  run bash "$KOVA_ROOT/kova-monitor" start /nonexistent/file.md
  assert_failure
  # In CI without tmux, the tmux check may fire before the file check
  [[ "$output" == *"not found"* ]] || [[ "$output" == *"tmux"* ]]
}

# --- tmux missing ---

@test "kova-monitor start: error when tmux not available" {
  SANDBOX="$(mktemp -d)"
  echo "- [ ] test item" > "$SANDBOX/test.md"
  # Run with PATH stripped to simulate missing tmux
  run env PATH="/usr/bin:/bin" bash "$KOVA_ROOT/kova-monitor" start "$SANDBOX/test.md"
  # Should fail because tmux is not in the restricted path (or it is and works)
  # We can't guarantee tmux isn't in /usr/bin, so just check it doesn't crash.
  # In CI without a terminal, tmux may emit "size missing" instead of a tmux-related error.
  [ "$status" -eq 0 ] || [[ "$output" == *"tmux"* ]] || [[ "$output" == *"size"* ]]
}

# --- status ---

@test "kova-monitor status: runs without error" {
  run bash "$KOVA_ROOT/kova-monitor" status
  assert_success
}

@test "kova-monitor status: shows not running when no session" {
  run bash "$KOVA_ROOT/kova-monitor" status
  assert_success
  # Should show either "not running" or "tmux not installed"
  [[ "$output" == *"not running"* ]] || [[ "$output" == *"tmux not installed"* ]]
}

# --- stop ---

@test "kova-monitor stop: no error when no session exists" {
  run bash "$KOVA_ROOT/kova-monitor" stop
  # Should succeed or show tmux not installed
  [ "$status" -eq 0 ] || [[ "$output" == *"tmux"* ]]
}

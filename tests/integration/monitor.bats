#!/usr/bin/env bats

setup() {
  load "../helpers/test_helper"
  _common_setup

  SANDBOX="$(mktemp -d)"
  mkdir -p "$SANDBOX/.git"
}

teardown() {
  rm -rf "$SANDBOX"
}

# --- install copies kova-monitor ---

@test "install: copies kova-monitor script" {
  run_install "$SANDBOX"
  [ -f "$SANDBOX/.claude/kova-monitor" ]
}

@test "install: kova-monitor is executable after install" {
  run_install "$SANDBOX"
  [ -x "$SANDBOX/.claude/kova-monitor" ]
}

@test "install --dry-run: mentions kova-monitor" {
  run bash -c "cd '$SANDBOX' && bash '$KOVA_ROOT/install.sh' --dry-run"
  assert_success
  assert_output --partial "kova-monitor"
}

# --- kova CLI delegates monitor ---

@test "kova help: mentions monitor command" {
  run bash "$KOVA_ROOT/kova" help
  assert_success
  assert_output --partial "monitor"
}

@test "kova help: mentions setup command" {
  run bash "$KOVA_ROOT/kova" help
  assert_success
  assert_output --partial "setup"
}

# --- install copies new lib files ---

@test "install: copies rate-limiter.sh" {
  run_install "$SANDBOX"
  [ -f "$SANDBOX/.claude/hooks/lib/rate-limiter.sh" ]
}

@test "install: copies circuit-breaker.sh" {
  run_install "$SANDBOX"
  [ -f "$SANDBOX/.claude/hooks/lib/circuit-breaker.sh" ]
}

@test "install: rate-limiter.sh is executable" {
  run_install "$SANDBOX"
  [ -x "$SANDBOX/.claude/hooks/lib/rate-limiter.sh" ]
}

@test "install: circuit-breaker.sh is executable" {
  run_install "$SANDBOX"
  [ -x "$SANDBOX/.claude/hooks/lib/circuit-breaker.sh" ]
}

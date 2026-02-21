#!/usr/bin/env bats

setup() {
  load "../helpers/test_helper"
  _common_setup

  SANDBOX="$(mktemp -d)"
  FAKE_HOME="$(mktemp -d)"
  mkdir -p "$FAKE_HOME/.local/bin"
}

teardown() {
  rm -rf "$SANDBOX" "$FAKE_HOME"
}

# --- --global --dry-run ---

@test "install --global --dry-run: shows preview without changes" {
  run env HOME="$FAKE_HOME" bash "$KOVA_ROOT/install.sh" --global --dry-run
  assert_success
  assert_output --partial "DRY RUN"
  assert_output --partial "Global install preview"
  assert_output --partial "kova"
  assert_output --partial "kova-monitor"
  assert_output --partial "No changes made"
}

@test "install --global --dry-run: does not copy files" {
  run env HOME="$FAKE_HOME" bash "$KOVA_ROOT/install.sh" --global --dry-run
  assert_success
  [ ! -f "$FAKE_HOME/.local/bin/kova" ]
  [ ! -f "$FAKE_HOME/.local/bin/kova-monitor" ]
}

# --- --global (full install) ---

@test "install --global: copies kova to ~/.local/bin" {
  run env HOME="$FAKE_HOME" bash "$KOVA_ROOT/install.sh" --global
  assert_success
  [ -f "$FAKE_HOME/.local/bin/kova" ]
}

@test "install --global: copies kova-monitor to ~/.local/bin" {
  run env HOME="$FAKE_HOME" bash "$KOVA_ROOT/install.sh" --global
  assert_success
  [ -f "$FAKE_HOME/.local/bin/kova-monitor" ]
}

@test "install --global: kova is executable" {
  run env HOME="$FAKE_HOME" bash "$KOVA_ROOT/install.sh" --global
  assert_success
  [ -x "$FAKE_HOME/.local/bin/kova" ]
}

@test "install --global: kova-monitor is executable" {
  run env HOME="$FAKE_HOME" bash "$KOVA_ROOT/install.sh" --global
  assert_success
  [ -x "$FAKE_HOME/.local/bin/kova-monitor" ]
}

@test "install --global: warns when dir not in PATH" {
  # Run with PATH that doesn't include ~/.local/bin
  run env HOME="$FAKE_HOME" PATH="/usr/bin:/bin" bash "$KOVA_ROOT/install.sh" --global
  assert_success
  assert_output --partial "NOT in"
  assert_output --partial "PATH"
}

@test "install --global: no warning when dir is in PATH" {
  run env HOME="$FAKE_HOME" PATH="$FAKE_HOME/.local/bin:/usr/bin:/bin" bash "$KOVA_ROOT/install.sh" --global
  assert_success
  assert_output --partial "is in PATH"
}

@test "install --global: mentions per-project hooks still required" {
  run env HOME="$FAKE_HOME" bash "$KOVA_ROOT/install.sh" --global
  assert_success
  assert_output --partial "Per-project hooks"
}

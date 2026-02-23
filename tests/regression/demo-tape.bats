#!/usr/bin/env bats
# Regression test: demo.tape must exist and be a valid VHS tape file.
# Also verifies docs/example-prd.md exists (referenced by the demo).

setup() {
  load "../helpers/test_helper"
  _common_setup
}

@test "demo.tape exists at project root" {
  [ -f "$KOVA_ROOT/demo.tape" ]
}

@test "demo.tape contains required VHS Set directives" {
  run grep -c '^Set ' "$KOVA_ROOT/demo.tape"
  assert_success
  # Should have at least the basic settings (Shell, FontSize, Width, Height, etc.)
  [ "$output" -ge 5 ]
}

@test "demo.tape contains Type commands for kova status" {
  run grep 'Type.*kova status' "$KOVA_ROOT/demo.tape"
  assert_success
}

@test "demo.tape contains Type commands for kova:loop" {
  run grep 'Type.*kova:loop' "$KOVA_ROOT/demo.tape"
  assert_success
}

@test "demo.tape shows verification gate output" {
  run grep 'Verification' "$KOVA_ROOT/demo.tape"
  assert_success
}

@test "demo.tape shows commit output" {
  run grep 'Commit' "$KOVA_ROOT/demo.tape"
  assert_success
}

@test "demo.tape does not exceed 300 lines" {
  local lines
  lines="$(wc -l < "$KOVA_ROOT/demo.tape")"
  [ "$lines" -le 300 ]
}

@test "docs/example-prd.md exists" {
  [ -f "$KOVA_ROOT/docs/example-prd.md" ]
}

@test "docs/example-prd.md contains at least one PRD item" {
  run grep -c '### [0-9]' "$KOVA_ROOT/docs/example-prd.md"
  assert_success
  [ "$output" -ge 1 ]
}

@test "README references demo.gif" {
  run grep 'demo\.gif' "$KOVA_ROOT/README.md"
  assert_success
}

@test "README references demo.tape" {
  run grep 'demo\.tape' "$KOVA_ROOT/README.md"
  assert_success
}

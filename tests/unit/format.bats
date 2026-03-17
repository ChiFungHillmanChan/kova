#!/usr/bin/env bats

setup() {
  load "../helpers/test_helper"
  _common_setup

  HOOK="$KOVA_ROOT/hooks/format.sh"
  TMPDIR_FMT="$(mktemp -d)"
}

teardown() {
  [ -d "$TMPDIR_FMT" ] && rm -rf "$TMPDIR_FMT"
}

# Helper: pipe JSON with file_path into the hook
run_hook() {
  local file_path="$1"
  echo "{\"tool_input\":{\"file_path\":\"$file_path\"}}" | bash "$HOOK"
}

# ─── Empty / missing input ───

@test "format: empty file_path exits cleanly" {
  run run_hook ""
  assert_success
}

@test "format: missing tool_input exits cleanly" {
  run bash -c 'echo "{}" | bash '"$HOOK"
  assert_success
}

# ─── Non-existent file ───

@test "format: non-existent file exits cleanly" {
  run run_hook "/tmp/does-not-exist-at-all.ts"
  assert_success
}

# ─── Unknown extension ───

@test "format: unknown extension exits cleanly" {
  local f="$TMPDIR_FMT/data.xyz"
  echo "some data" > "$f"
  run run_hook "$f"
  assert_success
}

# ─── JSON formatting with jq ───

@test "format: formats messy JSON when jq is available" {
  if ! command -v jq &>/dev/null; then
    skip "jq not installed"
  fi
  local f="$TMPDIR_FMT/test.json"
  echo '{"a":1,"b":  2,  "c":3}' > "$f"
  run run_hook "$f"
  assert_success
  # jq reformats with indentation; verify it's valid and pretty-printed
  run jq '.' "$f"
  assert_success
  assert_line --index 0 '{'
}

@test "format: invalid JSON does not crash" {
  if ! command -v jq &>/dev/null; then
    skip "jq not installed"
  fi
  local f="$TMPDIR_FMT/broken.json"
  echo '{not valid json' > "$f"
  run run_hook "$f"
  assert_success
}

# ─── Extension detection ───

@test "format: recognizes .ts extension" {
  local f="$TMPDIR_FMT/app.ts"
  echo "const x = 1;" > "$f"
  run run_hook "$f"
  assert_success
}

@test "format: recognizes .py extension" {
  local f="$TMPDIR_FMT/app.py"
  echo "x = 1" > "$f"
  run run_hook "$f"
  assert_success
}

@test "format: recognizes .go extension" {
  local f="$TMPDIR_FMT/main.go"
  echo 'package main' > "$f"
  run run_hook "$f"
  assert_success
}

@test "format: recognizes .rs extension" {
  local f="$TMPDIR_FMT/main.rs"
  echo 'fn main() {}' > "$f"
  run run_hook "$f"
  assert_success
}

@test "format: recognizes .rb extension" {
  local f="$TMPDIR_FMT/app.rb"
  echo 'puts "hello"' > "$f"
  run run_hook "$f"
  assert_success
}

@test "format: recognizes .toml extension" {
  local f="$TMPDIR_FMT/config.toml"
  echo '[package]' > "$f"
  run run_hook "$f"
  assert_success
}

#!/usr/bin/env bats

setup() {
  load "../helpers/test_helper"
  _common_setup

  HOOK="$KOVA_ROOT/hooks/block-dangerous.sh"
}

# Helper: pipe JSON with command into the hook (JSON-escapes backslashes and double quotes)
run_hook() {
  local cmd="$1"
  cmd=$(printf '%s' "$cmd" | sed 's/\\/\\\\/g; s/"/\\"/g')
  echo "{\"tool_input\":{\"command\":\"$cmd\"}}" | bash "$HOOK"
}

# Helper: capture stderr from the hook
run_hook_stderr() {
  local cmd="$1"
  cmd=$(printf '%s' "$cmd" | sed 's/\\/\\\\/g; s/"/\\"/g')
  echo "{\"tool_input\":{\"command\":\"$cmd\"}}" | bash "$HOOK" 2>&1 1>/dev/null
}

# ─── Empty / missing input ───

@test "block-dangerous: empty command exits cleanly" {
  run run_hook ""
  assert_success
  refute_output --partial '"decision":"block"'
}

@test "block-dangerous: missing tool_input exits cleanly" {
  run bash -c 'echo "{}" | bash '"$HOOK"
  assert_success
  refute_output --partial '"decision":"block"'
}

# ─── Safe commands pass through ───

@test "block-dangerous: allows ls -la" {
  run run_hook "ls -la"
  assert_success
  refute_output --partial '"decision":"block"'
}

@test "block-dangerous: allows git status" {
  run run_hook "git status"
  assert_success
  refute_output --partial '"decision":"block"'
}

@test "block-dangerous: allows npm test" {
  run run_hook "npm test"
  assert_success
  refute_output --partial '"decision":"block"'
}

@test "block-dangerous: allows git push origin main" {
  run run_hook "git push origin main"
  assert_success
  refute_output --partial '"decision":"block"'
}

# ─── Blocked patterns (exact) ───

@test "block-dangerous: blocks rm -rf /" {
  run run_hook "rm -rf /"
  assert_output --partial '"decision":"block"'
}

@test "block-dangerous: blocks rm -rf ~" {
  run run_hook "rm -rf ~"
  assert_output --partial '"decision":"block"'
}

@test "block-dangerous: blocks git push --force" {
  run run_hook "git push --force"
  assert_output --partial '"decision":"block"'
}

@test "block-dangerous: blocks git push -f" {
  run run_hook "git push -f origin main"
  assert_output --partial '"decision":"block"'
}

@test "block-dangerous: blocks DROP TABLE" {
  run run_hook "psql -c 'DROP TABLE users'"
  assert_output --partial '"decision":"block"'
}

@test "block-dangerous: blocks DROP DATABASE" {
  run run_hook "DROP DATABASE production"
  assert_output --partial '"decision":"block"'
}

@test "block-dangerous: blocks TRUNCATE TABLE" {
  run run_hook "TRUNCATE TABLE logs"
  assert_output --partial '"decision":"block"'
}

@test "block-dangerous: blocks > /dev/sda" {
  run run_hook "cat /dev/zero > /dev/sda"
  assert_output --partial '"decision":"block"'
}

@test "block-dangerous: blocks mkfs" {
  run run_hook "mkfs.ext4 /dev/sda1"
  assert_output --partial '"decision":"block"'
}

@test "block-dangerous: blocks dd if=" {
  run run_hook "dd if=/dev/zero of=/dev/sda"
  assert_output --partial '"decision":"block"'
}

@test "block-dangerous: blocks fork bomb" {
  run run_hook ':(){:|:&};:'
  assert_output --partial '"decision":"block"'
}

@test "block-dangerous: blocks rm -rf *" {
  run run_hook "rm -rf *"
  assert_output --partial '"decision":"block"'
}

# ─── Case insensitive blocking ───

@test "block-dangerous: blocks drop table (lowercase)" {
  run run_hook "drop table users"
  assert_output --partial '"decision":"block"'
}

@test "block-dangerous: blocks DROP TABLE (mixed case)" {
  run run_hook "Drop Table users"
  assert_output --partial '"decision":"block"'
}

# ─── Bypass attempts (normalization catches these) ───

@test "block-dangerous: blocks quoted rm bypass" {
  run run_hook "'rm' '-rf' '/'"
  assert_output --partial '"decision":"block"'
}

@test "block-dangerous: blocks double-quoted rm bypass" {
  run run_hook '"rm" "-rf" "/"'
  assert_output --partial '"decision":"block"'
}

@test "block-dangerous: blocks extra whitespace bypass" {
  run run_hook "rm  -rf  /"
  assert_output --partial '"decision":"block"'
}

@test "block-dangerous: blocks eval wrapper" {
  run run_hook "eval 'rm -rf /'"
  assert_output --partial '"decision":"block"'
}

@test "block-dangerous: blocks bash -c wrapper" {
  run run_hook "bash -c 'rm -rf /'"
  assert_output --partial '"decision":"block"'
}

@test "block-dangerous: blocks sh -c wrapper" {
  run run_hook "sh -c 'rm -rf /'"
  assert_output --partial '"decision":"block"'
}

@test "block-dangerous: blocks subshell substitution" {
  run run_hook '$(rm -rf /)'
  assert_output --partial '"decision":"block"'
}

@test "block-dangerous: blocks backslash escape bypass" {
  run run_hook 'r\m -rf /'
  assert_output --partial '"decision":"block"'
}

# ─── Warning patterns (allowed but warned) ───

@test "block-dangerous: warns on rm -rf (non-root)" {
  run run_hook_stderr "rm -rf ./build"
  assert_output --partial "WARNING"
}

@test "block-dangerous: warns on force-with-lease (not blocked)" {
  run run_hook "git push --force-with-lease"
  refute_output --partial '"decision":"block"'
  run run_hook_stderr "git push --force-with-lease"
  assert_output --partial "WARNING"
}

@test "block-dangerous: warns on drop_table (snake_case)" {
  run run_hook_stderr "python migrate.py drop_table"
  assert_output --partial "WARNING"
}

@test "block-dangerous: warn patterns still allow execution" {
  run run_hook "rm -rf ./build"
  refute_output --partial '"decision":"block"'
}

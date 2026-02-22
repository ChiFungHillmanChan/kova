#!/usr/bin/env bats

setup() {
  load "../helpers/test_helper"
  _common_setup

  SANDBOX="$(mktemp -d)"
  HOOK="$KOVA_ROOT/.claude/hooks/verify-on-stop.sh"

  # Initialize a real git repo in the sandbox so git diff --quiet works
  git init "$SANDBOX" >/dev/null 2>&1
  cd "$SANDBOX"
  git commit --allow-empty -m "init" >/dev/null 2>&1

  # Set required env vars that the hook expects
  export CLAUDE_PROJECT_DIR="$SANDBOX"
}

teardown() {
  rm -rf "$SANDBOX"
  unset CLAUDE_PROJECT_DIR KOVA_LOOP_ACTIVE
}

@test "verify-on-stop: KOVA_LOOP_ACTIVE=1 skips entirely" {
  # Dirty the tree so we know it's not the git-clean exit
  echo "dirty" > "$SANDBOX/file.txt"

  export KOVA_LOOP_ACTIVE=1
  run bash -c 'echo "{}" | bash "$1"' _ "$HOOK"
  assert_success
  refute_output --partial "STOP GATE"
}

@test "verify-on-stop: clean git tree exits early without verification" {
  # Working tree is clean (no uncommitted changes)
  run bash -c 'echo "{}" | bash "$1"' _ "$HOOK"
  assert_success
  refute_output --partial "STOP GATE"
}

@test "verify-on-stop: dirty tree runs fast mode (skips layers 1-4, 7)" {
  # Create an uncommitted file to make the tree dirty
  echo "dirty" > "$SANDBOX/file.txt"

  # Hook outputs report to stderr, so redirect stderr to stdout for capture
  local out
  out=$(echo "{}" | bash "$HOOK" 2>&1)
  # Should see the fast mode banner
  echo "$out" | grep -q "STOP GATE (fast)"
  # Should see skip messages for layers 1-4 and 7
  echo "$out" | grep -q "\[1\] SKIP.*Stop hook: fast mode"
  echo "$out" | grep -q "\[2\] SKIP.*Stop hook: fast mode"
  echo "$out" | grep -q "\[3\] SKIP.*Stop hook: fast mode"
  echo "$out" | grep -q "\[4\] SKIP.*Stop hook: fast mode"
  echo "$out" | grep -q "\[7\] SKIP.*Stop hook: fast mode"
}

@test "verify-on-stop: stop_hook_active=true skips entirely" {
  echo "dirty" > "$SANDBOX/file.txt"

  run bash -c 'echo "{\"stop_hook_active\":true}" | bash "$1"' _ "$HOOK"
  assert_success
  refute_output --partial "STOP GATE"
}

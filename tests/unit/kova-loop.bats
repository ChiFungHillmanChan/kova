#!/usr/bin/env bats

setup() {
  load "../helpers/test_helper"
  _common_setup

  SANDBOX="$(mktemp -d)"
  cd "$SANDBOX"

  git init >/dev/null 2>&1
  git config user.name "Test User"
  git config user.email "test@example.com"

  echo "base" > preexisting.txt
  echo "base" > generated.txt
  git add preexisting.txt generated.txt
  git commit -m "init" >/dev/null 2>&1
}

teardown() {
  rm -rf "$SANDBOX"
}

@test "stage_item_changes: leaves pre-existing tracked edits unstaged when untouched after snapshot" {
  run bash -c "
    set -e
    cd '$SANDBOX'
    source '$KOVA_ROOT/hooks/kova-loop.sh'
    mkdir -p .kova-loop

    printf 'user edit\n' >> preexisting.txt
    snapshot_pre_iteration

    printf 'loop edit\n' >> generated.txt
    stage_item_changes

    git diff --cached --name-only | sort
  "

  assert_success
  assert_output --partial "generated.txt"
  refute_output --partial "preexisting.txt"
}

@test "stage_item_changes: stages tracked files that change again after snapshot" {
  run bash -c "
    set -e
    cd '$SANDBOX'
    source '$KOVA_ROOT/hooks/kova-loop.sh'
    mkdir -p .kova-loop

    printf 'user edit\n' >> preexisting.txt
    snapshot_pre_iteration

    printf 'loop followup\n' >> preexisting.txt
    stage_item_changes

    git diff --cached --name-only | sort
  "

  assert_success
  assert_output --partial "preexisting.txt"
}

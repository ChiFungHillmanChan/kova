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

# --- install.sh --dry-run ---

@test "install --dry-run: prints plan without creating files" {
  run bash -c "cd '$SANDBOX' && bash '$KOVA_ROOT/install.sh' --dry-run"
  assert_success
  assert_output --partial "DRY RUN"
  assert_output --partial "hooks/format.sh"
  assert_output --partial "hooks/protect-files.sh"
  assert_output --partial "No changes made"
  [ ! -d "$SANDBOX/.claude/hooks" ]
}

@test "install --dry-run: mentions CLAUDE.md when none exists" {
  run bash -c "cd '$SANDBOX' && bash '$KOVA_ROOT/install.sh' --dry-run"
  assert_success
  assert_output --partial "CLAUDE.md"
}

@test "install --dry-run: notes existing CLAUDE.md preservation" {
  echo "# My rules" > "$SANDBOX/CLAUDE.md"
  run bash -c "cd '$SANDBOX' && bash '$KOVA_ROOT/install.sh' --dry-run"
  assert_success
  assert_output --partial "CLAUDE.kova.md"
}

# --- install.sh (full) ---

@test "install: creates .claude directory structure" {
  run_install "$SANDBOX"
  [ -d "$SANDBOX/.claude/hooks" ]
  [ -d "$SANDBOX/.claude/hooks/lib" ]
  [ -d "$SANDBOX/.claude/commands" ]
  [ -d "$SANDBOX/.claude/commands/kova/phases" ]
}

@test "install: copies all hook scripts" {
  run_install "$SANDBOX"
  [ -f "$SANDBOX/.claude/hooks/format.sh" ]
  [ -f "$SANDBOX/.claude/hooks/verify-on-stop.sh" ]
  [ -f "$SANDBOX/.claude/hooks/block-dangerous.sh" ]
  [ -f "$SANDBOX/.claude/hooks/protect-files.sh" ]
  [ -f "$SANDBOX/.claude/hooks/kova-loop.sh" ]
}

@test "install: copies all lib scripts" {
  run_install "$SANDBOX"
  [ -f "$SANDBOX/.claude/hooks/lib/detect-stack.sh" ]
  [ -f "$SANDBOX/.claude/hooks/lib/parse-prd.sh" ]
  [ -f "$SANDBOX/.claude/hooks/lib/verify-gate.sh" ]
  [ -f "$SANDBOX/.claude/hooks/lib/parse-failures.sh" ]
  [ -f "$SANDBOX/.claude/hooks/lib/generate-prompt.sh" ]
  [ -f "$SANDBOX/.claude/hooks/lib/run-code-review.sh" ]
}

@test "install: hook scripts are executable" {
  run_install "$SANDBOX"
  [ -x "$SANDBOX/.claude/hooks/format.sh" ]
  [ -x "$SANDBOX/.claude/hooks/verify-on-stop.sh" ]
  [ -x "$SANDBOX/.claude/hooks/block-dangerous.sh" ]
  [ -x "$SANDBOX/.claude/hooks/protect-files.sh" ]
  [ -x "$SANDBOX/.claude/hooks/kova-loop.sh" ]
}

@test "install: lib scripts are executable" {
  run_install "$SANDBOX"
  [ -x "$SANDBOX/.claude/hooks/lib/detect-stack.sh" ]
  [ -x "$SANDBOX/.claude/hooks/lib/verify-gate.sh" ]
}

@test "install: copies settings.json" {
  run_install "$SANDBOX"
  [ -f "$SANDBOX/.claude/settings.json" ]
  run jq '.hooks' "$SANDBOX/.claude/settings.json"
  assert_success
}

@test "install: backs up existing settings.json" {
  mkdir -p "$SANDBOX/.claude"
  echo '{"custom": true}' > "$SANDBOX/.claude/settings.json"
  run_install "$SANDBOX"
  # Backup now uses a timestamp suffix (settings.json.bak.YYYYMMDDHHMMSS)
  local bak_file
  bak_file=$(ls "$SANDBOX/.claude/settings.json.bak."* 2>/dev/null | head -1)
  [ -n "$bak_file" ]
  run jq '.custom' "$bak_file"
  assert_output "true"
}

@test "install: copies slash commands" {
  run_install "$SANDBOX"
  [ -f "$SANDBOX/.claude/commands/plan.md" ]
  [ -f "$SANDBOX/.claude/commands/verify-app.md" ]
  [ -f "$SANDBOX/.claude/commands/commit-push-pr.md" ]
  [ -f "$SANDBOX/.claude/commands/fix-and-verify.md" ]
  [ -f "$SANDBOX/.claude/commands/code-review.md" ]
  [ -f "$SANDBOX/.claude/commands/simplify.md" ]
  [ -f "$SANDBOX/.claude/commands/daily-standup.md" ]
}

@test "install: copies kova commands and phases" {
  run_install "$SANDBOX"
  [ -f "$SANDBOX/.claude/commands/kova/init.md" ]
  [ -f "$SANDBOX/.claude/commands/kova/loop.md" ]
  [ -f "$SANDBOX/.claude/commands/kova/phases/clarify.md" ]
  [ -f "$SANDBOX/.claude/commands/kova/phases/plan.md" ]
  [ -f "$SANDBOX/.claude/commands/kova/phases/implement.md" ]
  [ -f "$SANDBOX/.claude/commands/kova/phases/verify.md" ]
  [ -f "$SANDBOX/.claude/commands/kova/phases/review.md" ]
  [ -f "$SANDBOX/.claude/commands/kova/phases/commit.md" ]
}

@test "install: copies kova CLI script and makes it executable" {
  run_install "$SANDBOX"
  [ -f "$SANDBOX/.claude/kova" ]
  [ -x "$SANDBOX/.claude/kova" ]
}

@test "install: creates CLAUDE.md when none exists" {
  run_install "$SANDBOX"
  [ -f "$SANDBOX/CLAUDE.md" ]
  run cat "$SANDBOX/CLAUDE.md"
  assert_output --partial "senior software engineer"
}

@test "install: preserves existing CLAUDE.md and writes .kova.md" {
  echo "# My custom rules" > "$SANDBOX/CLAUDE.md"
  run_install "$SANDBOX"
  run cat "$SANDBOX/CLAUDE.md"
  assert_output "# My custom rules"
  [ -f "$SANDBOX/CLAUDE.kova.md" ]
}

@test "install: idempotent — second install succeeds" {
  run_install "$SANDBOX"
  run_install "$SANDBOX"
  [ -f "$SANDBOX/.claude/hooks/format.sh" ]
  # Backup now uses a timestamp suffix
  local bak_file
  bak_file=$(ls "$SANDBOX/.claude/settings.json.bak."* 2>/dev/null | head -1)
  [ -n "$bak_file" ]
}

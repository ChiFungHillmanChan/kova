#!/usr/bin/env bats

setup() {
  load "../helpers/test_helper"
  _common_setup

  SANDBOX="$(mktemp -d)"
  mkdir -p "$SANDBOX/.claude/hooks/lib"

  # Copy the statusline script to sandbox
  cp "$KOVA_ROOT/.claude/hooks/lib/kova-statusline.sh" "$SANDBOX/.claude/hooks/lib/"

  source "$KOVA_ROOT/.claude/hooks/lib/kova-statusline.sh"
}

teardown() {
  rm -rf "$SANDBOX"
}

# --- kova_detect_state ---

@test "kova_detect_state: no .claude dir yields inactive" {
  local empty_dir
  empty_dir="$(mktemp -d)"
  result=$(kova_detect_state "$empty_dir")
  assert_equal "$result" "inactive"
  rm -rf "$empty_dir"
}

@test "kova_detect_state: empty settings.json yields inactive" {
  echo '{}' > "$SANDBOX/.claude/settings.json"
  result=$(kova_detect_state "$SANDBOX")
  assert_equal "$result" "inactive"
}

@test "kova_detect_state: settings with hooks yields active" {
  cat > "$SANDBOX/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": "cat | .claude/hooks/block-dangerous.sh", "timeout": 5}]
      }
    ]
  }
}
JSON
  result=$(kova_detect_state "$SANDBOX")
  assert_equal "$result" "active"
}

@test "kova_detect_state: settings with verify-on-stop yields active" {
  cat > "$SANDBOX/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "Stop": [
      {
        "hooks": [{"type": "command", "command": ".claude/hooks/verify-on-stop.sh", "timeout": 60}]
      }
    ]
  }
}
JSON
  result=$(kova_detect_state "$SANDBOX")
  assert_equal "$result" "active"
}

@test "kova_detect_state: settings with format hook yields active" {
  cat > "$SANDBOX/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [{"type": "command", "command": ".claude/hooks/format.sh", "timeout": 30}]
      }
    ]
  }
}
JSON
  result=$(kova_detect_state "$SANDBOX")
  assert_equal "$result" "active"
}

@test "kova_detect_state: hooks without kova scripts yields inactive" {
  cat > "$SANDBOX/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "Stop": [
      {
        "hooks": [{"type": "command", "command": "echo done", "timeout": 5}]
      }
    ]
  }
}
JSON
  result=$(kova_detect_state "$SANDBOX")
  assert_equal "$result" "inactive"
}

@test "kova_detect_state: .kova-loop dir present yields loop" {
  echo '{}' > "$SANDBOX/.claude/settings.json"
  mkdir -p "$SANDBOX/.kova-loop"
  result=$(kova_detect_state "$SANDBOX")
  assert_equal "$result" "loop"
}

@test "kova_detect_state: .kova-loop takes priority over active hooks" {
  cat > "$SANDBOX/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": "cat | .claude/hooks/block-dangerous.sh", "timeout": 5}]
      }
    ]
  }
}
JSON
  mkdir -p "$SANDBOX/.kova-loop"
  result=$(kova_detect_state "$SANDBOX")
  assert_equal "$result" "loop"
}

@test "kova_detect_state: settings.local.json with hooks key overrides settings.json" {
  # settings.json has hooks, settings.local.json has empty hooks — local wins
  cat > "$SANDBOX/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": "cat | .claude/hooks/block-dangerous.sh", "timeout": 5}]
      }
    ]
  }
}
JSON
  echo '{"hooks": {}}' > "$SANDBOX/.claude/settings.local.json"
  result=$(kova_detect_state "$SANDBOX")
  assert_equal "$result" "inactive"
}

@test "kova_detect_state: settings.local.json without hooks key falls through to settings.json" {
  # settings.json has hooks, settings.local.json has no hooks key — fall through
  cat > "$SANDBOX/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": "cat | .claude/hooks/block-dangerous.sh", "timeout": 5}]
      }
    ]
  }
}
JSON
  echo '{"permissions": {}}' > "$SANDBOX/.claude/settings.local.json"
  result=$(kova_detect_state "$SANDBOX")
  assert_equal "$result" "active"
}

@test "kova_detect_state: protect-files hook yields active" {
  cat > "$SANDBOX/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write",
        "hooks": [{"type": "command", "command": ".claude/hooks/protect-files.sh", "timeout": 5}]
      }
    ]
  }
}
JSON
  result=$(kova_detect_state "$SANDBOX")
  assert_equal "$result" "active"
}

# --- kova_statusline_indicator ---

@test "kova_statusline_indicator: active state shows green [KOVA]" {
  cat > "$SANDBOX/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": ".claude/hooks/block-dangerous.sh", "timeout": 5}]
      }
    ]
  }
}
JSON
  run kova_statusline_indicator "$SANDBOX"
  assert_success
  [[ "$output" == *"[KOVA]"* ]]
}

@test "kova_statusline_indicator: loop state shows [KOVA LOOP]" {
  echo '{}' > "$SANDBOX/.claude/settings.json"
  mkdir -p "$SANDBOX/.kova-loop"
  run kova_statusline_indicator "$SANDBOX"
  assert_success
  [[ "$output" == *"[KOVA LOOP]"* ]]
}

@test "kova_statusline_indicator: inactive state shows [kova off]" {
  echo '{}' > "$SANDBOX/.claude/settings.json"
  run kova_statusline_indicator "$SANDBOX"
  assert_success
  [[ "$output" == *"[kova off]"* ]]
}

# --- standalone execution ---

@test "kova-statusline.sh: runs standalone and outputs indicator" {
  echo '{}' > "$SANDBOX/.claude/settings.json"
  run bash "$KOVA_ROOT/.claude/hooks/lib/kova-statusline.sh" "$SANDBOX"
  assert_success
  assert_output --partial "[kova off]"
}

@test "kova-statusline.sh: standalone with active hooks" {
  cat > "$SANDBOX/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "Stop": [
      {
        "hooks": [{"type": "command", "command": ".claude/hooks/verify-on-stop.sh", "timeout": 60}]
      }
    ]
  }
}
JSON
  run bash "$KOVA_ROOT/.claude/hooks/lib/kova-statusline.sh" "$SANDBOX"
  assert_success
  assert_output --partial "[KOVA]"
}

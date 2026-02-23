#!/usr/bin/env bats
# Tests for the example PRD in examples/prd-todo-app.md
# Validates that the file exists, parses correctly, and follows conventions.

setup() {
  load "../helpers/test_helper"
  _common_setup

  source "$KOVA_ROOT/.claude/hooks/lib/parse-prd.sh"
}

# --- File existence ---

@test "example PRD: examples/prd-todo-app.md exists" {
  [ -f "$KOVA_ROOT/examples/prd-todo-app.md" ]
}

# --- Format detection ---

@test "example PRD: detected as markdown format" {
  local fmt
  fmt=$(detect_prd_format "$KOVA_ROOT/examples/prd-todo-app.md")
  assert_equal "$fmt" "markdown"
}

# --- Parsing ---

@test "example PRD: parses successfully" {
  run parse_prd "$KOVA_ROOT/examples/prd-todo-app.md"
  assert_success
}

@test "example PRD: has 5 pending items" {
  parse_prd "$KOVA_ROOT/examples/prd-todo-app.md"
  assert_equal "$PRD_ITEM_COUNT" "5"
}

@test "example PRD: has 0 completed items" {
  parse_prd "$KOVA_ROOT/examples/prd-todo-app.md"
  assert_equal "$PRD_COMPLETED_COUNT" "0"
}

# --- Item content ---

@test "example PRD: first item creates todo.sh" {
  parse_prd "$KOVA_ROOT/examples/prd-todo-app.md"
  [[ "${PRD_ITEMS[0]}" == *"todo.sh"* ]]
}

@test "example PRD: fourth item writes Bats tests" {
  parse_prd "$KOVA_ROOT/examples/prd-todo-app.md"
  [[ "${PRD_ITEMS[3]}" == *"Bats tests"* ]]
}

@test "example PRD: last item adds README" {
  parse_prd "$KOVA_ROOT/examples/prd-todo-app.md"
  [[ "${PRD_ITEMS[4]}" == *"README.md"* ]]
}

# --- Convention checks ---

@test "example PRD: contains run-with instruction" {
  run grep -q '/kova:loop examples/prd-todo-app.md' "$KOVA_ROOT/examples/prd-todo-app.md"
  assert_success
}

@test "example PRD: has Items section" {
  run grep -q '## Items' "$KOVA_ROOT/examples/prd-todo-app.md"
  assert_success
}

@test "example PRD: has Notes section" {
  run grep -q '## Notes' "$KOVA_ROOT/examples/prd-todo-app.md"
  assert_success
}

@test "example PRD: item count is between 3 and 5" {
  parse_prd "$KOVA_ROOT/examples/prd-todo-app.md"
  [ "$PRD_ITEM_COUNT" -ge 3 ]
  [ "$PRD_ITEM_COUNT" -le 5 ]
}

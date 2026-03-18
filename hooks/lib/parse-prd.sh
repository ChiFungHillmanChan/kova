#!/bin/bash
# parse-prd.sh — Parse PRD files into an array of items
# Source this file: source "$(dirname "$0")/lib/parse-prd.sh"
#
# Supports two formats:
#   Markdown: - [ ] task description (checklist format)
#   JSON:     { "items": [{ "title": "...", "description": "..." }] }
#
# After calling parse_prd(), PRD_ITEMS is a bash array of item strings.
# PRD_ITEM_COUNT holds the count.

# Detect PRD format: "markdown" or "json" or "unknown"
detect_prd_format() {
  local file="$1"
  if ! [ -f "$file" ]; then
    echo "unknown"
    return
  fi

  # Check for JSON format first (starts with { or [)
  local first_char
  first_char=$(head -c 1 "$file" | tr -d '[:space:]')
  if [ "$first_char" = "{" ] || [ "$first_char" = "[" ]; then
    # Validate it's parseable JSON with items array
    if jq -e '.items' "$file" >/dev/null 2>&1; then
      echo "json"
      return
    fi
  fi

  # Check for markdown checklist items
  if grep -qE '^\s*-\s*\[[ x]\]' "$file" 2>/dev/null; then
    echo "markdown"
    return
  fi

  echo "unknown"
}

# Parse markdown PRD: extracts unchecked items (- [ ] ...)
# Checked items (- [x]) are treated as already completed
parse_markdown_prd() {
  local file="$1"
  local idx=0

  PRD_ITEMS=()
  PRD_COMPLETED=()

  while IFS= read -r line; do
    # Extract the task text after the checkbox
    local task
    task=$(echo "$line" | sed -E 's/^[[:space:]]*-[[:space:]]*\[[ ]\][[:space:]]*//')
    PRD_ITEMS+=("$task")
    idx=$((idx + 1))
  done < <(grep -E '^\s*-\s*\[ \]' "$file")

  # Also track completed items for context
  while IFS= read -r line; do
    local task
    task=$(echo "$line" | sed -E 's/^[[:space:]]*-[[:space:]]*\[[xX]\][[:space:]]*//')
    PRD_COMPLETED+=("$task")
  done < <(grep -E '^\s*-\s*\[[xX]\]' "$file")

  PRD_ITEM_COUNT=${#PRD_ITEMS[@]}
  PRD_COMPLETED_COUNT=${#PRD_COMPLETED[@]}
}

# Parse JSON PRD: extracts items from { "items": [...] }
# Each item can be a string or { "title": "...", "description": "..." }
parse_json_prd() {
  local file="$1"

  if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required for JSON PRD parsing but not installed." >&2
    return 1
  fi

  PRD_ITEMS=()
  PRD_COMPLETED=()
  PRD_COMPLETED_COUNT=0

  local count
  count=$(jq '.items | length' "$file" 2>/dev/null || echo "0")

  local idx=0
  while [ "$idx" -lt "$count" ]; do
    local item_type
    item_type=$(jq -r ".items[$idx] | type" "$file")

    local title=""
    local desc=""

    if [ "$item_type" = "string" ]; then
      title=$(jq -r ".items[$idx]" "$file")
      PRD_ITEMS+=("$title")
    else
      title=$(jq -r ".items[$idx].title // .items[$idx].name // \"\"" "$file")
      desc=$(jq -r ".items[$idx].description // \"\"" "$file")

      local done_flag
      done_flag=$(jq -r ".items[$idx].done // .items[$idx].completed // false" "$file")

      if [ "$done_flag" = "true" ]; then
        PRD_COMPLETED+=("$title")
        PRD_COMPLETED_COUNT=$((PRD_COMPLETED_COUNT + 1))
      elif [ -n "$desc" ] && [ "$desc" != "null" ]; then
        PRD_ITEMS+=("$title: $desc")
      else
        PRD_ITEMS+=("$title")
      fi
    fi

    idx=$((idx + 1))
  done

  PRD_ITEM_COUNT=${#PRD_ITEMS[@]}
}

# Main entry point: parse a PRD file
# Usage: parse_prd "/path/to/prd.md"
# Sets: PRD_ITEMS (array), PRD_ITEM_COUNT (int),
#        PRD_COMPLETED (array), PRD_COMPLETED_COUNT (int)
parse_prd() {
  local file="$1"

  if ! [ -f "$file" ]; then
    echo "ERROR: PRD file not found: $file" >&2
    return 1
  fi

  local format
  format=$(detect_prd_format "$file")

  case "$format" in
    markdown) parse_markdown_prd "$file" ;;
    json)     parse_json_prd "$file" ;;
    *)
      echo "ERROR: Unrecognized PRD format in: $file" >&2
      echo "  Supported formats:" >&2
      echo "    Markdown: - [ ] task description" >&2
      echo "    JSON:     { \"items\": [{ \"title\": \"...\", \"description\": \"...\" }] }" >&2
      return 1
      ;;
  esac

  if [ "$PRD_ITEM_COUNT" -eq 0 ]; then
    echo "WARNING: No pending items found in PRD: $file" >&2
    return 1
  fi

  return 0
}

# Print parsed items (for display/confirmation)
print_prd_items() {
  echo "PRD Items ($PRD_ITEM_COUNT pending, $PRD_COMPLETED_COUNT completed):"
  echo ""
  local idx=1
  for item in "${PRD_ITEMS[@]}"; do
    echo "  $idx. [ ] $item"
    idx=$((idx + 1))
  done
  if [ "$PRD_COMPLETED_COUNT" -gt 0 ]; then
    echo ""
    echo "  Already completed:"
    for item in "${PRD_COMPLETED[@]}"; do
      echo "       [x] $item"
    done
  fi
}

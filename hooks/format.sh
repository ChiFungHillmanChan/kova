#!/bin/bash
# format.sh — Auto-format any file Claude writes or edits
# Runs after PostToolUse for Write|Edit|MultiEdit

_HOOK_DIR="$(dirname "$0")"
source "$_HOOK_DIR/lib/require-jq.sh"

if ! require_jq; then
  exit 0
fi

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [ -z "$FILE" ]; then
  exit 0
fi

# Skip if file doesn't exist
if [ ! -f "$FILE" ]; then
  exit 0
fi

EXT="${FILE##*.}"

# Run the right formatter based on file extension
case "$EXT" in
  ts|tsx|js|jsx|mjs|cjs|css|scss|html|md|yaml|yml)
    if command -v prettier &>/dev/null; then
      prettier --write "$FILE" 2>/dev/null || true
    elif [ -f "$CLAUDE_PROJECT_DIR/node_modules/.bin/prettier" ]; then
      "$CLAUDE_PROJECT_DIR/node_modules/.bin/prettier" --write "$FILE" 2>/dev/null || true
    fi
    ;;
  py)
    if command -v ruff &>/dev/null; then
      ruff format "$FILE" 2>/dev/null || true
    elif command -v black &>/dev/null; then
      black --quiet "$FILE" 2>/dev/null || true
    fi
    if command -v isort &>/dev/null; then
      isort "$FILE" 2>/dev/null || true
    fi
    ;;
  go)
    if command -v gofmt &>/dev/null; then
      gofmt -w "$FILE" 2>/dev/null || true
    fi
    ;;
  rs)
    if command -v rustfmt &>/dev/null; then
      rustfmt "$FILE" 2>/dev/null || true
    fi
    ;;
  rb)
    if command -v rubocop &>/dev/null; then
      rubocop -a --fail-level error "$FILE" 2>/dev/null || true
    fi
    ;;
  java)
    if command -v google-java-format &>/dev/null; then
      google-java-format -i "$FILE" 2>/dev/null || true
    fi
    ;;
  cs)
    if command -v dotnet &>/dev/null; then
      dotnet format --include "$FILE" 2>/dev/null || true
    fi
    ;;
  toml)
    if command -v taplo &>/dev/null; then
      taplo format "$FILE" 2>/dev/null || true
    fi
    ;;
  json)
    if command -v jq &>/dev/null; then
      TMP=$(jq '.' "$FILE" 2>/dev/null) && echo "$TMP" > "$FILE" || true
    fi
    ;;
esac

exit 0

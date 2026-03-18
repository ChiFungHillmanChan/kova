#!/bin/bash
# detect-stack.sh — Shared detection library for Claude Code hooks
# Source this file: source "$(dirname "$0")/lib/detect-stack.sh"

# Detect the Node.js package manager (if any)
# Sets global PM variable: npm|pnpm|yarn|bun or empty
# shellcheck disable=SC2034
detect_pm() {
  PM=""
  if [ -f "bun.lockb" ] || [ -f "bunfig.toml" ]; then
    PM="bun"
  elif [ -f "pnpm-lock.yaml" ]; then
    PM="pnpm"
  elif [ -f "yarn.lock" ]; then
    PM="yarn"
  elif [ -f "package.json" ]; then
    PM="npm"
  fi
}

# Detect all languages/ecosystems present in the project
# Sets global LANGS as space-separated list: node python go rust ruby java dotnet
detect_languages() {
  LANGS=""
  [ -f "package.json" ] && LANGS="$LANGS node"
  { [ -f "pyproject.toml" ] || [ -f "requirements.txt" ] || [ -f "setup.py" ] || [ -f "Pipfile" ]; } && LANGS="$LANGS python"
  [ -f "go.mod" ] && LANGS="$LANGS go"
  [ -f "Cargo.toml" ] && LANGS="$LANGS rust"
  { [ -f "Gemfile" ] || [ -f ".ruby-version" ]; } && LANGS="$LANGS ruby"
  { [ -f "pom.xml" ] || [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; } && LANGS="$LANGS java"
  { ls ./*.csproj >/dev/null 2>&1 || ls ./*.sln >/dev/null 2>&1 || [ -f "global.json" ]; } && LANGS="$LANGS dotnet"
  LANGS=$(echo "$LANGS" | xargs)
}

# Check if a language is in the detected list
# Usage: has_lang "python" && ...
has_lang() {
  echo " $LANGS " | grep -q " $1 "
}

# Run a command, capture exit code, append to RESULTS
# Usage: run_and_report LAYER "Description" command arg1 arg2 ...
# Sets FAILURES (increments on failure) and appends to RESULTS
run_and_report() {
  local layer="$1"; shift
  local desc="$1"; shift

  echo "[$layer/7] $desc..." >&2
  local OUTPUT
  OUTPUT=$("$@" 2>&1)
  local EXIT=$?
  echo "$OUTPUT" | tail -10 >&2

  if [ $EXIT -ne 0 ]; then
    FAILURES=$((FAILURES + 1))
    RESULTS="$RESULTS\n[$layer] FAIL — $desc"
  else
    RESULTS="$RESULTS\n[$layer] PASS — $desc"
  fi
  return $EXIT
}

# Run a command for warning only (does not increment FAILURES)
# Usage: run_and_warn LAYER "Description" command arg1 arg2 ...
run_and_warn() {
  local layer="$1"; shift
  local desc="$1"; shift

  echo "[$layer/7] $desc..." >&2
  local OUTPUT
  OUTPUT=$("$@" 2>&1)
  local EXIT=$?
  echo "$OUTPUT" | tail -5 >&2

  if [ $EXIT -ne 0 ]; then
    RESULTS="$RESULTS\n[$layer] WARN — $desc (review recommended)"
  else
    RESULTS="$RESULTS\n[$layer] PASS — $desc"
  fi
  return $EXIT
}

# Run a command; if it fails, retry once. If retry passes, mark FLAKY (no failure count).
# Usage: run_and_retry LAYER "Description" command arg1 arg2 ...
# Sets FAILURES (increments on confirmed failure) and appends to RESULTS
run_and_retry() {
  local layer="$1"; shift
  local desc="$1"; shift

  echo "[$layer/7] $desc..." >&2
  local OUTPUT
  OUTPUT=$("$@" 2>&1)
  local EXIT=$?
  echo "$OUTPUT" | tail -10 >&2

  if [ $EXIT -ne 0 ]; then
    # Retry once
    echo "[$layer/7] $desc (retry)..." >&2
    OUTPUT=$("$@" 2>&1)
    EXIT=$?
    echo "$OUTPUT" | tail -10 >&2

    if [ $EXIT -eq 0 ]; then
      RESULTS="$RESULTS\n[$layer] FLAKY — $desc (passed on retry)"
      return 0
    else
      FAILURES=$((FAILURES + 1))
      RESULTS="$RESULTS\n[$layer] FAIL — $desc (confirmed failure)"
      return $EXIT
    fi
  else
    RESULTS="$RESULTS\n[$layer] PASS — $desc"
  fi
  return 0
}

# Run a command, capture exit code, append to RESULTS, AND write full output to file
# Usage: run_and_report_capture LAYER "Description" OUTPUT_FILE command arg1 arg2 ...
# Like run_and_report but also captures full output to OUTPUT_FILE for parsing
run_and_report_capture() {
  local layer="$1"; shift
  local desc="$1"; shift
  local capture_file="$1"; shift

  echo "[$layer/7] $desc..." >&2
  local OUTPUT
  OUTPUT=$("$@" 2>&1)
  local EXIT=$?

  # Write full output to capture file (append)
  {
    echo "=== [$layer] $desc ==="
    echo "$OUTPUT"
    echo ""
  } >> "$capture_file"

  echo "$OUTPUT" | tail -10 >&2

  if [ $EXIT -ne 0 ]; then
    FAILURES=$((FAILURES + 1))
    RESULTS="$RESULTS\n[$layer] FAIL — $desc"
  else
    RESULTS="$RESULTS\n[$layer] PASS — $desc"
  fi
  return $EXIT
}

# Run a command with retry AND capture full output to file
# Usage: run_and_retry_capture LAYER "Description" OUTPUT_FILE command arg1 arg2 ...
run_and_retry_capture() {
  local layer="$1"; shift
  local desc="$1"; shift
  local capture_file="$1"; shift

  echo "[$layer/7] $desc..." >&2
  local OUTPUT
  OUTPUT=$("$@" 2>&1)
  local EXIT=$?

  # Capture first attempt output
  {
    echo "=== [$layer] $desc ==="
    echo "$OUTPUT"
    echo ""
  } >> "$capture_file"

  echo "$OUTPUT" | tail -10 >&2

  if [ $EXIT -ne 0 ]; then
    echo "[$layer/7] $desc (retry)..." >&2
    OUTPUT=$("$@" 2>&1)
    EXIT=$?

    # Capture retry output
    {
      echo "=== [$layer] $desc (retry) ==="
      echo "$OUTPUT"
      echo ""
    } >> "$capture_file"

    echo "$OUTPUT" | tail -10 >&2

    if [ $EXIT -eq 0 ]; then
      RESULTS="$RESULTS\n[$layer] FLAKY — $desc (passed on retry)"
      return 0
    else
      FAILURES=$((FAILURES + 1))
      RESULTS="$RESULTS\n[$layer] FAIL — $desc (confirmed failure)"
      return $EXIT
    fi
  else
    RESULTS="$RESULTS\n[$layer] PASS — $desc"
  fi
  return 0
}

# Run a command for warning only with capture (does not increment FAILURES)
# Usage: run_and_warn_capture LAYER "Description" OUTPUT_FILE command arg1 arg2 ...
run_and_warn_capture() {
  local layer="$1"; shift
  local desc="$1"; shift
  local capture_file="$1"; shift

  echo "[$layer/7] $desc..." >&2
  local OUTPUT
  OUTPUT=$("$@" 2>&1)
  local EXIT=$?

  {
    echo "=== [$layer] $desc ==="
    echo "$OUTPUT"
    echo ""
  } >> "$capture_file"

  echo "$OUTPUT" | tail -5 >&2

  if [ $EXIT -ne 0 ]; then
    RESULTS="$RESULTS\n[$layer] WARN — $desc (review recommended)"
  else
    RESULTS="$RESULTS\n[$layer] PASS — $desc"
  fi
  return $EXIT
}

# Cross-platform hash for project directory (macOS + Linux)
project_hash() {
  printf '%s' "$1" | shasum 2>/dev/null | cut -d' ' -f1 \
    || printf '%s' "$1" | sha1sum 2>/dev/null | cut -d' ' -f1 \
    || printf '%s' "$1" | md5 2>/dev/null
}

# Read a JSON field from package.json
# Usage: pkg_field '.scripts.build'
pkg_field() {
  if ! command -v jq &>/dev/null; then
    return
  fi
  jq -r "$1 // empty" package.json 2>/dev/null
}

#!/bin/bash
# test_helper.bash — Shared test utilities for Kova Bats tests

KOVA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

_common_setup() {
  load "$(npm root)/bats-support/load"
  load "$(npm root)/bats-assert/load"
}

# Create a temporary project sandbox with minimal .claude/ structure
# Sets SANDBOX to the temp dir path
create_sandbox() {
  SANDBOX="$(mktemp -d)"
  mkdir -p "$SANDBOX/.claude/hooks/lib"
  mkdir -p "$SANDBOX/.claude/commands/kova/phases"
  mkdir -p "$SANDBOX/.git"
}

# Tear down a sandbox created by create_sandbox
destroy_sandbox() {
  if [ -n "$SANDBOX" ] && [ -d "$SANDBOX" ]; then
    rm -rf "$SANDBOX"
  fi
}

# Run install.sh from the kova source into the given target dir
run_install() {
  local target="${1:-$SANDBOX}"
  (cd "$target" && bash "$KOVA_ROOT/install.sh")
}

# Run install.sh --dry-run
run_install_dry() {
  local target="${1:-$SANDBOX}"
  (cd "$target" && bash "$KOVA_ROOT/install.sh" --dry-run)
}

# Run the kova CLI from a sandbox project
run_kova() {
  local target="${1:-$SANDBOX}"
  shift
  (cd "$target" && bash "$KOVA_ROOT/kova" "$@")
}

# List of hook scripts that install.sh is expected to install
installed_hook_files() {
  echo "format.sh"
  echo "verify-on-stop.sh"
  echo "block-dangerous.sh"
  echo "protect-files.sh"
  echo "kova-loop.sh"
  echo "kova-commit-gate.sh"
}

# List of lib scripts that install.sh is expected to install
installed_lib_files() {
  echo "detect-stack.sh"
  echo "parse-prd.sh"
  echo "verify-gate.sh"
  echo "parse-failures.sh"
  echo "generate-prompt.sh"
  echo "run-code-review.sh"
  echo "rate-limiter.sh"
  echo "circuit-breaker.sh"
  echo "kova-statusline.sh"
}

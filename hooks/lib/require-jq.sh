#!/bin/bash
# require-jq.sh — Shared jq existence check for Kova hooks
# Source this file at the top of any hook that depends on jq.

# Returns 0 if jq is available, 1 if not.
# Prints an error to stderr when jq is missing.
require_jq() {
  if ! command -v jq &>/dev/null; then
    echo "KOVA ERROR: jq is required but not installed. Hook cannot run safely." >&2
    echo "  Install: brew install jq (macOS) | apt-get install jq (Linux)" >&2
    return 1
  fi
}

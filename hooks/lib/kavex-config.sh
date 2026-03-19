#!/bin/bash
# kavex-config.sh — Read Kavex global configuration
# Shared library used by hooks to check config state

# Returns 0 if safety should be skipped, 1 otherwise
kavex_skip_safety() {
  # Environment variable override (highest priority)
  if [ "${KAVEX_SKIP_SAFETY:-0}" = "1" ]; then
    return 0
  fi

  # Read from config file
  local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/kavex/config.json"
  if [ -f "$config_file" ] && command -v jq &>/dev/null; then
    local val
    val=$(jq -r '.skip_safety // "false"' "$config_file" 2>/dev/null)
    if [ "$val" = "true" ]; then
      return 0
    fi
  fi

  return 1
}

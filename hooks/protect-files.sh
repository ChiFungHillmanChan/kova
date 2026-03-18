#!/bin/bash
set -euo pipefail
# protect-files.sh — Block writes to sensitive files
# Runs on PreToolUse for Write|Edit|MultiEdit
#
# Two matching strategies:
#   - PROTECTED_BASENAME: exact match on filename (basename) — prevents false positives
#     like "some.environment.ts" matching ".env"
#   - PROTECTED_SUBSTRING: substring match on full path — for patterns that can appear
#     anywhere in a file path

_HOOK_DIR="$(dirname "$0")"
source "$_HOOK_DIR/lib/require-jq.sh"

if ! require_jq; then
  echo '{"decision":"block","reason":"KOVA: jq is not installed. Cannot verify file safety. Install jq to proceed."}'
  exit 0
fi

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)

if [ -z "$FILE" ]; then
  exit 0
fi

BASENAME=$(basename "$FILE")

# Env files — exact match on basename to avoid false positives
PROTECTED_BASENAME=(
  ".env"
  ".env.local"
  ".env.development"
  ".env.test"
  ".env.staging"
  ".env.production"
  ".env.prod"
)

# Sensitive paths/extensions — substring match on full path
PROTECTED_SUBSTRING=(
  "secrets/"
  "credentials/"
  ".pem"
  ".key"
  "id_rsa"
  "serviceAccountKey.json"
  "firebase-adminsdk"
)

# Basename exact match (env files)
for pattern in "${PROTECTED_BASENAME[@]}"; do
  if [[ "$BASENAME" == "$pattern" ]]; then
    echo "BLOCKED: Protected file pattern matched: $pattern" >&2
    echo "{\"decision\":\"block\",\"reason\":\"File '$FILE' matches protected pattern '$pattern'. This file contains sensitive data. Ask the human before editing.\"}"
    exit 0
  fi
done

# Substring match (secrets, keys, credentials)
for pattern in "${PROTECTED_SUBSTRING[@]}"; do
  if [[ "$FILE" == *"$pattern"* ]]; then
    echo "BLOCKED: Protected file pattern matched: $pattern" >&2
    echo "{\"decision\":\"block\",\"reason\":\"File '$FILE' matches protected pattern '$pattern'. This file contains sensitive data. Ask the human before editing.\"}"
    exit 0
  fi
done

exit 0

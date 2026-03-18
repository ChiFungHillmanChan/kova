#!/usr/bin/env bats

setup() {
  load "../helpers/test_helper"
  _common_setup

  HOOK="$KOVA_ROOT/hooks/protect-files.sh"
}

# Helper: pipe JSON with file_path into the hook
run_hook() {
  local file_path="$1"
  echo "{\"tool_input\":{\"file_path\":\"$file_path\"}}" | bash "$HOOK"
}

# ─── Blocking tests: env files (basename exact match) ───

@test "protect-files: blocks .env" {
  run run_hook ".env"
  assert_output --partial '"decision":"block"'
}

@test "protect-files: blocks .env.local" {
  run run_hook ".env.local"
  assert_output --partial '"decision":"block"'
}

@test "protect-files: blocks .env.development" {
  run run_hook ".env.development"
  assert_output --partial '"decision":"block"'
}

@test "protect-files: blocks .env.test" {
  run run_hook ".env.test"
  assert_output --partial '"decision":"block"'
}

@test "protect-files: blocks .env.staging" {
  run run_hook ".env.staging"
  assert_output --partial '"decision":"block"'
}

@test "protect-files: blocks .env.production" {
  run run_hook ".env.production"
  assert_output --partial '"decision":"block"'
}

@test "protect-files: blocks .env.prod" {
  run run_hook ".env.prod"
  assert_output --partial '"decision":"block"'
}

@test "protect-files: blocks nested env file (apps/web/.env.test)" {
  run run_hook "apps/web/.env.test"
  assert_output --partial '"decision":"block"'
}

# ─── Blocking tests: secrets/credentials (substring match) ───

@test "protect-files: blocks secrets/api.json" {
  run run_hook "secrets/api.json"
  assert_output --partial '"decision":"block"'
}

@test "protect-files: blocks credentials/gcp.json" {
  run run_hook "credentials/gcp.json"
  assert_output --partial '"decision":"block"'
}

@test "protect-files: blocks server.pem" {
  run run_hook "server.pem"
  assert_output --partial '"decision":"block"'
}

@test "protect-files: blocks server.key" {
  run run_hook "server.key"
  assert_output --partial '"decision":"block"'
}

@test "protect-files: blocks id_rsa" {
  run run_hook "id_rsa"
  assert_output --partial '"decision":"block"'
}

@test "protect-files: blocks serviceAccountKey.json" {
  run run_hook "serviceAccountKey.json"
  assert_output --partial '"decision":"block"'
}

@test "protect-files: blocks firebase-adminsdk-xxx.json" {
  run run_hook "firebase-adminsdk-xxx.json"
  assert_output --partial '"decision":"block"'
}

# ─── Non-blocking tests: must NOT match ───

@test "protect-files: allows some.environment.ts (not an env file)" {
  run run_hook "some.environment.ts"
  refute_output --partial '"decision":"block"'
}

@test "protect-files: allows docs/env-guide.md" {
  run run_hook "docs/env-guide.md"
  refute_output --partial '"decision":"block"'
}

@test "protect-files: allows src/components/KeyManager.ts (Key != .key)" {
  run run_hook "src/components/KeyManager.ts"
  refute_output --partial '"decision":"block"'
}

@test "protect-files: allows README.md" {
  run run_hook "README.md"
  refute_output --partial '"decision":"block"'
}

@test "protect-files: empty file_path exits cleanly" {
  run bash -c 'echo "{\"tool_input\":{}}" | bash "$1"' _ "$HOOK"
  assert_success
  refute_output --partial '"decision":"block"'
}

# ─── jq missing: fail-closed ───

@test "protect-files: blocks when jq is not installed (fail-closed)" {
  local tmpdir
  tmpdir=$(mktemp -d)
  cp -r "$KOVA_ROOT/hooks/"* "$tmpdir/"
  cat > "$tmpdir/lib/require-jq.sh" << 'MOCK'
require_jq() {
  echo "KOVA ERROR: jq is required but not installed. Hook cannot run safely." >&2
  return 1
}
MOCK
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\".env\"}}" | bash "$1/protect-files.sh"' _ "$tmpdir"
  rm -rf "$tmpdir"
  assert_output --partial '"decision":"block"'
  assert_output --partial 'jq is not installed'
}

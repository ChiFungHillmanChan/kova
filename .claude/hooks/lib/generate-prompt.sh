#!/bin/bash
# generate-prompt.sh — Generate unique prompts per iteration
# Source this file: source "$(dirname "$0")/lib/generate-prompt.sh"
#
# Core differentiator from Ralph Loop: each iteration gets a UNIQUE
# diagnostic prompt based on what failed, not the same prompt repeated.
#
# Modes:
#   implement   — New PRD item implementation
#   fix-verify  — Fix verification failures (test/lint/type/build)
#   fix-review  — Fix HIGH-severity code review issues

# Generate an implement prompt for a new PRD item
# Usage: generate_implement_prompt <item_text> <item_number> <total_items> <completed_list> <output_file>
generate_implement_prompt() {
  local item_text="$1"
  local item_number="$2"
  local total_items="$3"
  local completed_list="$4"
  local output_file="$5"

  local git_context
  git_context=$(git diff --stat HEAD 2>/dev/null | tail -20)

  cat > "$output_file" << PROMPT_EOF
# Implement PRD Item $item_number of $total_items

## Role
You are a senior engineer implementing a feature from a PRD. Follow CLAUDE.md standards.

## Task
Implement the following item:

**$item_text**

## Context
$(if [ -n "$completed_list" ]; then
echo "### Already completed:"
echo "$completed_list"
echo ""
fi)
### Recent changes (git diff --stat):
\`\`\`
${git_context:-No changes yet}
\`\`\`

## Instructions
1. Read relevant existing code before making changes
2. Implement the feature described above
3. Write tests covering: happy path, edge cases, expected errors
4. Run the verification pipeline (build, test, lint, typecheck)
5. Fix any failures before finishing

## Rules
- Follow CLAUDE.md coding standards
- Use the assumption protocol for ambiguous requirements
- Keep files under 300 lines
- No type-safety bypasses without justification
- Commit messages: conventional commits format
PROMPT_EOF
}

# Generate a fix-verify prompt for verification failures
# Usage: generate_fix_verify_prompt <parsed_failures_file> <raw_output_file> <fix_attempt> <max_attempts> <output_file>
generate_fix_verify_prompt() {
  local parsed_failures_file="$1"
  local raw_output_file="$2"
  local fix_attempt="$3"
  local max_attempts="$4"
  local output_file="$5"

  local git_context
  git_context=$(git diff --stat HEAD 2>/dev/null | tail -20)

  local raw_tail=""
  if [ -f "$raw_output_file" ]; then
    raw_tail=$(tail -100 "$raw_output_file")
  fi

  local parsed_content=""
  if [ -f "$parsed_failures_file" ]; then
    parsed_content=$(cat "$parsed_failures_file")
  fi

  local codex_section=""
  local state_dir
  state_dir=$(dirname "$parsed_failures_file")
  if [ -f "$state_dir/codex-diagnosis-latest.md" ]; then
    codex_section=$(cat "$state_dir/codex-diagnosis-latest.md")
  fi

  cat > "$output_file" << PROMPT_EOF
# Fix Verification Failures (attempt $fix_attempt of $max_attempts)

## Role
You are a senior engineer fixing specific test/lint/type failures. Do NOT re-implement features. Fix ONLY the listed failures.

## Parsed Failures
$parsed_content
$(if [ -n "$codex_section" ]; then
echo ""
echo "$codex_section"
echo ""
echo "IMPORTANT: The above diagnosis is from a DIFFERENT AI model (Codex). Consider its suggestions carefully."
fi)

## Raw Output (last 100 lines)
\`\`\`
$raw_tail
\`\`\`

## Recent changes (git diff --stat):
\`\`\`
${git_context:-No changes}
\`\`\`

## Instructions
1. Read the failing files at the specific lines mentioned above
2. Fix ONLY the failures listed — do not refactor or add features
3. Run the verification pipeline after fixing
4. If a test expectation is wrong (not the code), fix the test

## Rules
- Minimal changes — fix the failure, nothing else
- Do NOT re-implement existing functionality
- If stuck on the same failure, try a different approach
- Follow CLAUDE.md coding standards
PROMPT_EOF
}

# Generate a fix-review prompt for HIGH-severity code review issues
# Usage: generate_fix_review_prompt <review_output_file> <fix_attempt> <output_file>
generate_fix_review_prompt() {
  local review_output_file="$1"
  local fix_attempt="$2"
  local output_file="$3"

  local git_context
  git_context=$(git diff --stat HEAD 2>/dev/null | tail -20)

  local review_content=""
  if [ -f "$review_output_file" ]; then
    review_content=$(cat "$review_output_file")
  fi

  local codex_section=""
  local state_dir
  state_dir=$(dirname "$review_output_file")
  if [ -f "$state_dir/codex-diagnosis-latest.md" ]; then
    codex_section=$(cat "$state_dir/codex-diagnosis-latest.md")
  fi

  cat > "$output_file" << PROMPT_EOF
# Fix Code Review Issues (attempt $fix_attempt)

## Role
You are a senior engineer fixing HIGH-severity code review issues. Fix the issues without breaking existing tests.

## Code Review Findings (HIGH severity)
$review_content
$(if [ -n "$codex_section" ]; then
echo ""
echo "$codex_section"
echo ""
echo "IMPORTANT: The above diagnosis is from a DIFFERENT AI model (Codex). Consider its suggestions carefully."
fi)

## Recent changes (git diff --stat):
\`\`\`
${git_context:-No changes}
\`\`\`

## Instructions
1. Read the files mentioned in the review findings
2. Fix each HIGH-severity issue
3. Run the verification pipeline after fixing — tests MUST still pass
4. If fixing an issue would break tests, update the tests too

## Rules
- Fix HIGH-severity issues only — ignore LOW/INFO
- Do NOT break existing tests
- Follow CLAUDE.md coding standards
- Security issues take priority over all others
PROMPT_EOF
}

#!/bin/bash
# install.sh
# Run this from the ROOT of any project to install the Kova protocol.
#
# Usage:
#   cd /path/to/kova && bash install.sh /path/to/project
#   OR from project root: bash /path/to/kova/install.sh
#   Add --dry-run to preview what would be installed without making changes
#
# What it does:
#   1. Creates .claude/ directory structure
#   2. Copies all hooks (including shared lib), commands, and settings
#   3. Makes hooks executable
#   4. Creates CLAUDE.md if one doesn't exist

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$(pwd)"
DRY_RUN=false
GLOBAL_INSTALL=false

# Parse flags
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --global)  GLOBAL_INSTALL=true ;;
  esac
done

# ─────────────────────────────────────────────
# Global install mode: copy kova + kova-monitor to PATH
# ─────────────────────────────────────────────
if $GLOBAL_INSTALL; then
  # Determine install directory
  GLOBAL_DIR=""
  if [ -d "$HOME/.local/bin" ] || mkdir -p "$HOME/.local/bin" 2>/dev/null; then
    GLOBAL_DIR="$HOME/.local/bin"
  elif [ -w "/usr/local/bin" ]; then
    GLOBAL_DIR="/usr/local/bin"
  else
    echo "ERROR: Cannot write to ~/.local/bin or /usr/local/bin" >&2
    echo "  Create ~/.local/bin: mkdir -p ~/.local/bin" >&2
    exit 1
  fi

  if $DRY_RUN; then
    echo "DRY RUN — Global install preview"
    echo ""
    echo "Would copy to: $GLOBAL_DIR"
    echo "  kova         -> $GLOBAL_DIR/kova"
    echo "  kova-monitor -> $GLOBAL_DIR/kova-monitor"
    echo ""
    # Check PATH
    if echo "$PATH" | tr ':' '\n' | grep -qx "$GLOBAL_DIR"; then
      echo "  PATH: $GLOBAL_DIR is in PATH ✓"
    else
      echo "  WARNING: $GLOBAL_DIR is NOT in PATH"
      echo "  Add to your shell profile:"
      echo "    export PATH=\"$GLOBAL_DIR:\$PATH\""
    fi
    echo ""
    echo "No changes made. Remove --dry-run to install."
    exit 0
  fi

  echo "Installing Kova globally to: $GLOBAL_DIR"
  echo ""

  cp "$SCRIPT_DIR/kova" "$GLOBAL_DIR/kova"
  chmod +x "$GLOBAL_DIR/kova"
  echo "  kova -> $GLOBAL_DIR/kova"

  cp "$SCRIPT_DIR/kova-monitor" "$GLOBAL_DIR/kova-monitor"
  chmod +x "$GLOBAL_DIR/kova-monitor"
  echo "  kova-monitor -> $GLOBAL_DIR/kova-monitor"

  echo ""

  # Check PATH
  if echo "$PATH" | tr ':' '\n' | grep -qx "$GLOBAL_DIR"; then
    echo "  PATH: $GLOBAL_DIR is in PATH ✓"
  else
    echo -e "  \033[0;33mWARNING: $GLOBAL_DIR is NOT in your PATH\033[0m"
    echo "  Add to your shell profile (~/.zshrc or ~/.bashrc):"
    echo "    export PATH=\"$GLOBAL_DIR:\$PATH\""
  fi

  echo ""
  echo "Global install complete! Per-project hooks still require: kova install"
  exit 0
fi

if $DRY_RUN; then
  echo "DRY RUN — showing what would be installed into: $TARGET_DIR"
  echo ""
  echo "Directories to create:"
  echo "  $TARGET_DIR/.claude/commands/"
  echo "  $TARGET_DIR/.claude/hooks/"
  echo "  $TARGET_DIR/.claude/hooks/lib/"
  echo "  $TARGET_DIR/.claude/commands/kova/"
  echo "  $TARGET_DIR/.claude/commands/kova/phases/"
  echo ""
  echo "Files to copy:"
  echo "  settings.json"
  echo "  hooks/format.sh"
  echo "  hooks/verify-on-stop.sh"
  echo "  hooks/block-dangerous.sh"
  echo "  hooks/protect-files.sh"
  echo "  hooks/kova-loop.sh"
  echo "  hooks/lib/detect-stack.sh"
  echo "  hooks/lib/parse-prd.sh"
  echo "  hooks/lib/verify-gate.sh"
  echo "  hooks/lib/parse-failures.sh"
  echo "  hooks/lib/generate-prompt.sh"
  echo "  hooks/lib/run-code-review.sh"
  echo "  hooks/lib/rate-limiter.sh"
  echo "  hooks/lib/circuit-breaker.sh"
  echo "  kova-monitor (CLI script → .claude/kova-monitor)"
  echo "  commands/commit-push-pr.md"
  echo "  commands/verify-app.md"
  echo "  commands/daily-standup.md"
  echo "  commands/fix-and-verify.md"
  echo "  commands/code-review.md"
  echo "  commands/plan.md"
  echo "  commands/simplify.md"
  echo "  commands/kova/init.md"
  echo "  commands/kova/loop.md"
  echo "  commands/kova/phases/clarify.md"
  echo "  commands/kova/phases/plan.md"
  echo "  commands/kova/phases/implement.md"
  echo "  commands/kova/phases/verify.md"
  echo "  commands/kova/phases/review.md"
  echo "  commands/kova/phases/commit.md"
  echo "  kova (CLI script → .claude/kova)"
  if [ -f "$TARGET_DIR/CLAUDE.md" ]; then
    echo "  CLAUDE.md -> CLAUDE.kova.md (existing CLAUDE.md preserved)"
  else
    echo "  CLAUDE.md"
  fi
  echo ""
  echo "No changes made. Remove --dry-run to install."
  exit 0
fi

echo "Installing Kova Protocol into: $TARGET_DIR"
echo ""

# Create directories
mkdir -p "$TARGET_DIR/.claude/commands/kova/phases"
mkdir -p "$TARGET_DIR/.claude/hooks/lib"

# Copy settings (backup if exists)
if [ -f "$TARGET_DIR/.claude/settings.json" ]; then
  echo "  .claude/settings.json already exists. Backing up to settings.json.bak"
  cp "$TARGET_DIR/.claude/settings.json" "$TARGET_DIR/.claude/settings.json.bak"
fi
cp "$SCRIPT_DIR/.claude/settings.json" "$TARGET_DIR/.claude/settings.json"
echo "  settings.json installed"

# Copy hooks
cp "$SCRIPT_DIR/.claude/hooks/format.sh"          "$TARGET_DIR/.claude/hooks/"
cp "$SCRIPT_DIR/.claude/hooks/verify-on-stop.sh"  "$TARGET_DIR/.claude/hooks/"
cp "$SCRIPT_DIR/.claude/hooks/block-dangerous.sh" "$TARGET_DIR/.claude/hooks/"
cp "$SCRIPT_DIR/.claude/hooks/protect-files.sh"   "$TARGET_DIR/.claude/hooks/"
cp "$SCRIPT_DIR/.claude/hooks/kova-loop.sh"  "$TARGET_DIR/.claude/hooks/"

# Copy shared library
cp "$SCRIPT_DIR/.claude/hooks/lib/detect-stack.sh"      "$TARGET_DIR/.claude/hooks/lib/"
cp "$SCRIPT_DIR/.claude/hooks/lib/parse-prd.sh"         "$TARGET_DIR/.claude/hooks/lib/"
cp "$SCRIPT_DIR/.claude/hooks/lib/verify-gate.sh"       "$TARGET_DIR/.claude/hooks/lib/"
cp "$SCRIPT_DIR/.claude/hooks/lib/parse-failures.sh"    "$TARGET_DIR/.claude/hooks/lib/"
cp "$SCRIPT_DIR/.claude/hooks/lib/generate-prompt.sh"   "$TARGET_DIR/.claude/hooks/lib/"
cp "$SCRIPT_DIR/.claude/hooks/lib/run-code-review.sh"   "$TARGET_DIR/.claude/hooks/lib/"
cp "$SCRIPT_DIR/.claude/hooks/lib/rate-limiter.sh"     "$TARGET_DIR/.claude/hooks/lib/"
cp "$SCRIPT_DIR/.claude/hooks/lib/circuit-breaker.sh"  "$TARGET_DIR/.claude/hooks/lib/"

# Make hooks executable
chmod +x "$TARGET_DIR/.claude/hooks/"*.sh
chmod +x "$TARGET_DIR/.claude/hooks/lib/"*.sh
echo "  Hooks installed and made executable"

# Copy slash commands
cp "$SCRIPT_DIR/.claude/commands/commit-push-pr.md" "$TARGET_DIR/.claude/commands/"
cp "$SCRIPT_DIR/.claude/commands/verify-app.md"     "$TARGET_DIR/.claude/commands/"
cp "$SCRIPT_DIR/.claude/commands/daily-standup.md"  "$TARGET_DIR/.claude/commands/"
cp "$SCRIPT_DIR/.claude/commands/fix-and-verify.md" "$TARGET_DIR/.claude/commands/"
cp "$SCRIPT_DIR/.claude/commands/code-review.md"    "$TARGET_DIR/.claude/commands/"
cp "$SCRIPT_DIR/.claude/commands/plan.md"           "$TARGET_DIR/.claude/commands/"
cp "$SCRIPT_DIR/.claude/commands/simplify.md"       "$TARGET_DIR/.claude/commands/"

# Copy kova commands (only LLM-powered ones; help/status/activate/deactivate are in the kova CLI)
cp "$SCRIPT_DIR/.claude/commands/kova/init.md"       "$TARGET_DIR/.claude/commands/kova/"
cp "$SCRIPT_DIR/.claude/commands/kova/loop.md"       "$TARGET_DIR/.claude/commands/kova/"

# Copy kova phase files (Team Loop)
cp "$SCRIPT_DIR/.claude/commands/kova/phases/clarify.md"   "$TARGET_DIR/.claude/commands/kova/phases/"
cp "$SCRIPT_DIR/.claude/commands/kova/phases/plan.md"      "$TARGET_DIR/.claude/commands/kova/phases/"
cp "$SCRIPT_DIR/.claude/commands/kova/phases/implement.md" "$TARGET_DIR/.claude/commands/kova/phases/"
cp "$SCRIPT_DIR/.claude/commands/kova/phases/verify.md"    "$TARGET_DIR/.claude/commands/kova/phases/"
cp "$SCRIPT_DIR/.claude/commands/kova/phases/review.md"    "$TARGET_DIR/.claude/commands/kova/phases/"
cp "$SCRIPT_DIR/.claude/commands/kova/phases/commit.md"    "$TARGET_DIR/.claude/commands/kova/phases/"
echo "  Slash commands installed (including kova commands + phase files)"

# Copy kova CLI script
cp "$SCRIPT_DIR/kova" "$TARGET_DIR/.claude/kova"
chmod +x "$TARGET_DIR/.claude/kova"
echo "  Kova CLI installed (.claude/kova)"

# Copy kova-monitor script
cp "$SCRIPT_DIR/kova-monitor" "$TARGET_DIR/.claude/kova-monitor"
chmod +x "$TARGET_DIR/.claude/kova-monitor"
echo "  Kova Monitor installed (.claude/kova-monitor)"

# Copy CLAUDE.md only if one doesn't exist
if [ -f "$TARGET_DIR/CLAUDE.md" ]; then
  echo "  CLAUDE.md already exists. Not overwriting. Kova additions saved to CLAUDE.kova.md"
  cp "$SCRIPT_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.kova.md"
  echo "   -> Manually merge CLAUDE.kova.md into your CLAUDE.md"
else
  cp "$SCRIPT_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
  echo "  CLAUDE.md installed"
fi

# Check for jq (required for hooks)
if ! command -v jq &>/dev/null; then
  echo ""
  echo "  WARNING: 'jq' is not installed. Hooks require jq to work."
  echo "   Install it:"
  echo "   macOS:  brew install jq"
  echo "   Ubuntu: sudo apt-get install jq"
  echo "   Fedora: sudo dnf install jq"
  echo "   Arch:   sudo pacman -S jq"
fi

# Check for codex (optional — multi-model review)
if ! command -v codex &>/dev/null; then
  echo ""
  echo "  INFO: OpenAI Codex CLI not found (optional)."
  echo "   Install for multi-model code review in the Team Loop:"
  echo "   npm install -g @openai/codex"
  echo "   codex login"
  echo "   If not installed, Codex review is silently skipped."
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Kova Protocol installed!"
echo ""
echo "CLI commands (zero tokens — run from terminal):"
echo "  .claude/kova help        Show all available commands"
echo "  .claude/kova status      Check hooks, stack, commands"
echo "  .claude/kova activate    Turn ON automatic hooks"
echo "  .claude/kova deactivate  Turn OFF automatic hooks"
echo "  .claude/kova setup       Interactive setup wizard"
echo "  .claude/kova monitor     tmux dashboard for loop"
echo ""
echo "  TIP: Add to PATH for convenience:"
echo "    export PATH=\"\$PWD/.claude:\$PATH\""
echo "    # Then just: kova help"
echo ""
echo "Slash commands (inside Claude Code):"
echo "  /plan           -> Plan before coding"
echo "  /verify-app     -> Full QA sweep"
echo "  /commit-push-pr -> Auto commit + push + PR"
echo "  /fix-and-verify -> Debug and fix failing tests"
echo "  /code-review    -> Multi-agent code review"
echo "  /simplify       -> Clean up code after feature"
echo "  /daily-standup  -> Engineering report"
echo ""
echo "  /kova:loop  -> Team Loop: 6-phase cycle per PRD item"
echo "  /kova:init  -> Scaffold a new PRD file"
echo ""
echo "Hooks active:"
echo "  PostToolUse -> auto-format on every file write"
echo "  Stop        -> auto-run tests when Claude finishes"
echo "  PreToolUse  -> block dangerous commands + protect sensitive files"
echo ""
echo "Supported ecosystems: Node.js, Python, Go, Rust, Ruby, Java, .NET"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

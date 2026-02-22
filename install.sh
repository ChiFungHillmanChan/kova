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
  echo "  hooks/kova-commit-gate.sh"
  echo "  hooks/lib/detect-stack.sh"
  echo "  hooks/lib/parse-prd.sh"
  echo "  hooks/lib/verify-gate.sh"
  echo "  hooks/lib/parse-failures.sh"
  echo "  hooks/lib/generate-prompt.sh"
  echo "  hooks/lib/run-code-review.sh"
  echo "  hooks/lib/rate-limiter.sh"
  echo "  hooks/lib/circuit-breaker.sh"
  echo "  hooks/lib/kova-statusline.sh"
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
cp "$SCRIPT_DIR/.claude/hooks/kova-loop.sh"       "$TARGET_DIR/.claude/hooks/"
cp "$SCRIPT_DIR/.claude/hooks/kova-commit-gate.sh" "$TARGET_DIR/.claude/hooks/"

# Copy shared library
cp "$SCRIPT_DIR/.claude/hooks/lib/detect-stack.sh"      "$TARGET_DIR/.claude/hooks/lib/"
cp "$SCRIPT_DIR/.claude/hooks/lib/parse-prd.sh"         "$TARGET_DIR/.claude/hooks/lib/"
cp "$SCRIPT_DIR/.claude/hooks/lib/verify-gate.sh"       "$TARGET_DIR/.claude/hooks/lib/"
cp "$SCRIPT_DIR/.claude/hooks/lib/parse-failures.sh"    "$TARGET_DIR/.claude/hooks/lib/"
cp "$SCRIPT_DIR/.claude/hooks/lib/generate-prompt.sh"   "$TARGET_DIR/.claude/hooks/lib/"
cp "$SCRIPT_DIR/.claude/hooks/lib/run-code-review.sh"   "$TARGET_DIR/.claude/hooks/lib/"
cp "$SCRIPT_DIR/.claude/hooks/lib/rate-limiter.sh"     "$TARGET_DIR/.claude/hooks/lib/"
cp "$SCRIPT_DIR/.claude/hooks/lib/circuit-breaker.sh"  "$TARGET_DIR/.claude/hooks/lib/"
cp "$SCRIPT_DIR/.claude/hooks/lib/kova-statusline.sh" "$TARGET_DIR/.claude/hooks/lib/"

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

# Install statusline integration
install_statusline() {
  local user_settings_dir="$HOME/.claude"
  local statusline_script="$user_settings_dir/statusline-command.sh"
  local kova_marker="# --- KOVA STATUSLINE ---"

  # Check if user already has a statusline script with kova integration
  if [ -f "$statusline_script" ] && grep -q "$kova_marker" "$statusline_script" 2>/dev/null; then
    echo "  Statusline: kova indicator already integrated"
    return 0
  fi

  if [ -f "$statusline_script" ]; then
    # Backup existing script
    cp "$statusline_script" "$statusline_script.bak"
    echo "  Statusline: backed up existing to statusline-command.sh.bak"

    # Inject kova indicator by appending a block at the end of the existing script.
    # We append rather than splicing into the last line to avoid corrupting
    # scripts with unexpected formats (single-quoted, no trailing quote, etc.).
    # Uses ${cwd:-$PWD} to handle scripts that don't define $cwd.
    {
      cat "$statusline_script"
      printf '\n%s\n' "$kova_marker"
      cat <<'KOVA_INJECT'
# Source kova statusline detection (appended by kova install)
_kova_dir="${cwd:-$PWD}"
_kova_lib="$_kova_dir/.claude/hooks/lib/kova-statusline.sh"
if [ -f "$_kova_lib" ]; then
  . "$_kova_lib"
  printf ' %s' "$(kova_statusline_indicator "$_kova_dir")"
fi
KOVA_INJECT
      printf '%s\n' "$kova_marker"
    } > "$statusline_script.tmp"
    mv "$statusline_script.tmp" "$statusline_script"
    chmod +x "$statusline_script"
    echo "  Statusline: kova indicator appended to existing script"
  else
    # Create a new statusline script with kova integration
    mkdir -p "$user_settings_dir"
    cat > "$statusline_script" <<'STATUSLINE'
#!/bin/sh
# Claude Code statusline script with Kova integration
# Reads JSON from stdin and outputs a formatted status line

input=$(cat)

# Extract fields from JSON
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Shorten the cwd: replace $HOME with ~
home="$HOME"
short_cwd="${cwd#$home}"
if [ "$short_cwd" != "$cwd" ]; then
  short_cwd="~$short_cwd"
fi

# Get git branch
git_branch=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

# Build context usage display
ctx_display=""
if [ -n "$used_pct" ]; then
  used_rounded=$(printf "%.0f" "$used_pct")
  ctx_display=" | ctx: ${used_rounded}% used"
fi

# Build git display
git_display=""
if [ -n "$git_branch" ]; then
  git_display=" | $git_branch"
fi

# --- KOVA STATUSLINE ---
# Source kova statusline detection
KOVA_STATUSLINE_LIB="$cwd/.claude/hooks/lib/kova-statusline.sh"
kova_indicator=""
if [ -f "$KOVA_STATUSLINE_LIB" ]; then
  . "$KOVA_STATUSLINE_LIB"
  kova_indicator=" $(kova_statusline_indicator "$cwd")"
fi
# --- KOVA STATUSLINE ---

# Output: dir | branch model | ctx [KOVA]
printf "\033[0;36m%s\033[0m\033[0;33m%s\033[0m\033[0;35m %s\033[0m\033[0;32m%s\033[0m%s" \
  "$short_cwd" \
  "$git_display" \
  "$model" \
  "$ctx_display" \
  "$kova_indicator"
STATUSLINE
    chmod +x "$statusline_script"
    echo "  Statusline: created $statusline_script with kova indicator"

    # Also configure Claude Code settings if statusLine not already set
    local user_settings="$user_settings_dir/settings.json"
    if [ -f "$user_settings" ] && command -v jq &>/dev/null; then
      local has_statusline
      has_statusline=$(jq 'has("statusLine")' "$user_settings" 2>/dev/null || echo "false")
      if [ "$has_statusline" != "true" ]; then
        local updated
        updated=$(jq '. + {"statusLine": {"type": "command", "command": "sh '"$statusline_script"'"}}' "$user_settings")
        echo "$updated" > "$user_settings"
        echo "  Statusline: configured in Claude Code settings"
      fi
    fi
  fi
}

install_statusline

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

#!/bin/bash
set -euo pipefail

VERSION="1.0.0"
SINGULARITY_DIR="$HOME/.singularity"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()  { echo -e "${CYAN}$1${NC}"; }
ok()    { echo -e "${GREEN}  ✓ $1${NC}"; }
warn()  { echo -e "${YELLOW}  ! $1${NC}"; }
fail()  { echo -e "${RED}  ✗ $1${NC}"; }

echo ""
echo -e "${CYAN}╭─────────────────────────────────╮${NC}"
echo -e "${CYAN}│  Singularity Installer v${VERSION}     │${NC}"
echo -e "${CYAN}╰─────────────────────────────────╯${NC}"
echo ""

# --- Determine script source directory (for copying files) ---
# Works for both clone+run and curl|bash
if [ -f "./hooks/session-start.sh" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
else
  # curl | bash mode: download files from GitHub
  SCRIPT_DIR=""
  GITHUB_RAW="https://raw.githubusercontent.com/jcarter/singularity/main"
fi

# --- Helper: get file (from repo dir or GitHub) ---
get_file() {
  local path="$1"
  if [ -n "$SCRIPT_DIR" ]; then
    cat "$SCRIPT_DIR/$path"
  else
    curl -fsSL "$GITHUB_RAW/$(echo "$path" | sed 's/ /%20/g')"
  fi
}

# --- Detect Obsidian vault ---
detect_vault() {
  local candidates=(
    "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents"
    "$HOME/Documents/Obsidian"
    "$HOME/Obsidian"
    "$HOME/obsidian"
    "$HOME/Documents/obsidian"
  )
  for dir in "${candidates[@]}"; do
    if [ -d "$dir" ]; then
      # Find vaults (dirs containing .obsidian/)
      local obsidian_dir
      obsidian_dir=$(find "$dir" -maxdepth 2 -name ".obsidian" -type d 2>/dev/null | head -1)
      if [ -n "$obsidian_dir" ]; then
        dirname "$obsidian_dir"
        return 0
      fi
    fi
  done
  return 1
}

DETECTED_VAULT=$(detect_vault 2>/dev/null || echo "")

if [ -n "$DETECTED_VAULT" ]; then
  info "Detected Obsidian vault: $DETECTED_VAULT"
  read -rp "  Use this vault? (Y/n, or type a different path): " VAULT_INPUT </dev/tty
  if [ -z "$VAULT_INPUT" ] || [[ "$VAULT_INPUT" =~ ^[Yy]$ ]]; then
    VAULT_PATH="$DETECTED_VAULT"
  else
    VAULT_PATH="$VAULT_INPUT"
  fi
else
  read -rp "  Path to your Obsidian vault: " VAULT_PATH </dev/tty
fi

# Expand ~ if present
VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

if [ ! -d "$VAULT_PATH/.obsidian" ]; then
  fail "No .obsidian/ directory found in $VAULT_PATH. Is this an Obsidian vault?"
  exit 1
fi

SINGULARITY_VAULT="$VAULT_PATH/Singularity"
info ""

# --- Prompt for API key ---
info "Obsidian REST API key"
info "(Install the 'Local REST API' community plugin if you haven't already)"
read -rp "  API key: " API_KEY </dev/tty

if [ -z "$API_KEY" ]; then
  fail "API key is required."
  exit 1
fi

info ""

# --- Create ~/.singularity/ ---
info "Setting up ~/.singularity/ ..."

mkdir -p "$SINGULARITY_DIR/hooks"

# Write .env
cat > "$SINGULARITY_DIR/.env" << ENVEOF
# Singularity — Environment Configuration
OBSIDIAN_API_KEY=$API_KEY
OBSIDIAN_API_URL=https://127.0.0.1:27124
SINGULARITY_VAULT_PATH="$SINGULARITY_VAULT"
ENVEOF
ok "Created ~/.singularity/.env"

# Copy hook scripts
get_file "hooks/session-start.sh" > "$SINGULARITY_DIR/hooks/session-start.sh"
get_file "hooks/session-end.sh" > "$SINGULARITY_DIR/hooks/session-end.sh"
chmod +x "$SINGULARITY_DIR/hooks/session-start.sh" "$SINGULARITY_DIR/hooks/session-end.sh"
ok "Installed hook scripts"

# Copy skills
mkdir -p "$SINGULARITY_DIR/skills/distill"
get_file "skills/distill/SKILL.md" > "$SINGULARITY_DIR/skills/distill/SKILL.md"
ok "Installed skills"

# --- Create vault structure ---
info "Setting up vault structure ..."
mkdir -p "$SINGULARITY_VAULT/Sessions" "$SINGULARITY_VAULT/Learnings" "$SINGULARITY_VAULT/Decisions" "$SINGULARITY_VAULT/Distilled"
get_file "vault-readme.md" > "$SINGULARITY_VAULT/README.md"
ok "Created Singularity/ vault structure"

# Copy templates
TEMPLATE_DIR="$VAULT_PATH/Templates"
if [ -d "$TEMPLATE_DIR" ]; then
  get_file "templates/Singularity Session.md" > "$TEMPLATE_DIR/Singularity Session.md"
  get_file "templates/Singularity Learning.md" > "$TEMPLATE_DIR/Singularity Learning.md"
  ok "Copied templates to vault"
else
  warn "No Templates/ directory in vault — skipping template copy"
fi

info ""

# --- Provider detection & configuration ---
info "Detecting AI providers ..."

HAS_JQ=false
if command -v jq &>/dev/null; then
  HAS_JQ=true
fi

# MCP server JSON (used by all providers)
MCP_JSON=$(cat << MCPEOF
{
  "command": "npx",
  "args": ["-y", "mcp-obsidian"],
  "env": {
    "OBSIDIAN_API_KEY": "$API_KEY",
    "OBSIDIAN_API_URL": "https://127.0.0.1:27124",
    "VAULT_PATH": "Singularity"
  }
}
MCPEOF
)

CONFIGURED_PROVIDERS=()

# --- Claude Code ---
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
if [ -f "$CLAUDE_SETTINGS" ]; then
  info "  Found Claude Code"
  if [ "$HAS_JQ" = true ]; then
    jq --argjson mcp "$MCP_JSON" '
      .mcpServers.singularity = $mcp |
      .hooks.SessionStart = [{"hooks": [{"type": "command", "command": "SINGULARITY_PROVIDER=claude ~/.singularity/hooks/session-start.sh"}]}] |
      .hooks.SessionEnd = [{"hooks": [{"type": "command", "command": "SINGULARITY_PROVIDER=claude ~/.singularity/hooks/session-end.sh"}]}]
    ' "$CLAUDE_SETTINGS" > "${CLAUDE_SETTINGS}.tmp" && mv "${CLAUDE_SETTINGS}.tmp" "$CLAUDE_SETTINGS"
    ok "Claude Code — configured (MCP + hooks)"
  else
    warn "Claude Code — jq not found. Add MCP server and hooks manually to $CLAUDE_SETTINGS"
  fi
  # Symlink skills
  mkdir -p "$HOME/.claude/skills"
  ln -sfn "$SINGULARITY_DIR/skills/distill" "$HOME/.claude/skills/distill"
  ok "Claude Code — skills linked"
  CONFIGURED_PROVIDERS+=("Claude Code")
fi

# --- Cursor ---
CURSOR_DIR="$HOME/.cursor"
if [ -d "$CURSOR_DIR" ]; then
  info "  Found Cursor"
  CURSOR_MCP="$CURSOR_DIR/mcp.json"
  if [ "$HAS_JQ" = true ]; then
    if [ -f "$CURSOR_MCP" ]; then
      jq --argjson mcp "$MCP_JSON" '.mcpServers.singularity = $mcp' "$CURSOR_MCP" > "${CURSOR_MCP}.tmp" && mv "${CURSOR_MCP}.tmp" "$CURSOR_MCP"
    else
      echo '{}' | jq --argjson mcp "$MCP_JSON" '{mcpServers: {singularity: $mcp}}' > "$CURSOR_MCP"
    fi
    ok "Cursor — configured (MCP)"
  else
    warn "Cursor — jq not found. Add MCP server manually to $CURSOR_MCP"
  fi
  CONFIGURED_PROVIDERS+=("Cursor")
fi

# --- Windsurf ---
WINDSURF_DIR="$HOME/.windsurf"
if [ -d "$WINDSURF_DIR" ]; then
  info "  Found Windsurf"
  WINDSURF_MCP="$WINDSURF_DIR/mcp.json"
  if [ "$HAS_JQ" = true ]; then
    if [ -f "$WINDSURF_MCP" ]; then
      jq --argjson mcp "$MCP_JSON" '.mcpServers.singularity = $mcp' "$WINDSURF_MCP" > "${WINDSURF_MCP}.tmp" && mv "${WINDSURF_MCP}.tmp" "$WINDSURF_MCP"
    else
      echo '{}' | jq --argjson mcp "$MCP_JSON" '{mcpServers: {singularity: $mcp}}' > "$WINDSURF_MCP"
    fi
    ok "Windsurf — configured (MCP)"

    # Windsurf hooks
    WINDSURF_HOOKS="$WINDSURF_DIR/hooks.json"
    if [ -f "$WINDSURF_HOOKS" ]; then
      jq '.hooks.pre_user_prompt.command = "SINGULARITY_PROVIDER=windsurf ~/.singularity/hooks/session-start.sh"' "$WINDSURF_HOOKS" > "${WINDSURF_HOOKS}.tmp" && mv "${WINDSURF_HOOKS}.tmp" "$WINDSURF_HOOKS"
    else
      echo '{}' | jq '{hooks: {pre_user_prompt: {command: "SINGULARITY_PROVIDER=windsurf ~/.singularity/hooks/session-start.sh"}}}' > "$WINDSURF_HOOKS"
    fi
    ok "Windsurf — hooks configured"
  else
    warn "Windsurf — jq not found. Add config manually."
  fi
  CONFIGURED_PROVIDERS+=("Windsurf")
fi

# --- Copilot (VS Code) ---
if command -v code &>/dev/null; then
  info "  Found VS Code (Copilot)"
  GITHUB_HOOKS_DIR="$HOME/.github/hooks"
  mkdir -p "$GITHUB_HOOKS_DIR"

  cat > "$GITHUB_HOOKS_DIR/singularity-session-start.json" << HOOKEOF
{
  "event": "sessionStart",
  "command": "SINGULARITY_PROVIDER=copilot ~/.singularity/hooks/session-start.sh"
}
HOOKEOF

  cat > "$GITHUB_HOOKS_DIR/singularity-session-end.json" << HOOKEOF
{
  "event": "sessionEnd",
  "command": "SINGULARITY_PROVIDER=copilot ~/.singularity/hooks/session-end.sh"
}
HOOKEOF

  ok "Copilot — configured (hooks)"

  # Symlink skills
  mkdir -p "$HOME/.github/skills"
  ln -sfn "$SINGULARITY_DIR/skills/distill" "$HOME/.github/skills/distill"
  ok "Copilot — skills linked"

  # VS Code MCP config is per-workspace (.vscode/mcp.json), not global
  warn "Copilot MCP — add to each project's .vscode/mcp.json (see README)"
  CONFIGURED_PROVIDERS+=("Copilot")
fi

if [ ${#CONFIGURED_PROVIDERS[@]} -eq 0 ]; then
  warn "No AI providers detected. See README for manual configuration."
fi

# --- Verification ---
info ""
info "Verifying installation ..."

# Check Obsidian REST API
if curl -sk "https://127.0.0.1:27124/" -H "Authorization: Bearer $API_KEY" -o /dev/null --connect-timeout 3; then
  ok "Obsidian REST API is reachable"
else
  warn "Obsidian REST API not reachable — make sure Obsidian is running with Local REST API plugin"
fi

# --- Summary ---
echo ""
info "╭─────────────────────────────────╮"
info "│       Installation Complete      │"
info "╰─────────────────────────────────╯"
echo ""
if [ ${#CONFIGURED_PROVIDERS[@]} -gt 0 ]; then
  info "Configured providers: ${CONFIGURED_PROVIDERS[*]}"
else
  info "Configured providers: none (see README for manual setup)"
fi
echo ""
info "Next steps:"
info "  1. Make sure Obsidian is running with the Local REST API plugin enabled"
info "  2. Restart your AI assistant to pick up the new config"
info "  3. Start a session — on end, a note will appear in Singularity/Sessions/"
echo ""

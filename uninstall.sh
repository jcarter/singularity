#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}$1${NC}"; }
ok()    { echo -e "${GREEN}  ✓ $1${NC}"; }
warn()  { echo -e "${YELLOW}  ! $1${NC}"; }

SINGULARITY_DIR="$HOME/.singularity"
HAS_JQ=false
command -v jq &>/dev/null && HAS_JQ=true

echo ""
info "Singularity Uninstaller"
echo ""

# --- Read vault path before deleting .env ---
VAULT_PATH=""
if [ -f "$SINGULARITY_DIR/.env" ]; then
  source "$SINGULARITY_DIR/.env"
  VAULT_PATH="${SINGULARITY_VAULT_PATH:-}"
fi

# --- Remove ~/.singularity/ ---
if [ -d "$SINGULARITY_DIR" ]; then
  rm -rf "$SINGULARITY_DIR"
  ok "Removed ~/.singularity/"
else
  warn "~/.singularity/ not found — already removed?"
fi

# --- Remove vault structure (with confirmation) ---
if [ -n "$VAULT_PATH" ] && [ -d "$VAULT_PATH" ]; then
  read -rp "  Remove $VAULT_PATH and all session notes? (y/N): " CONFIRM
  if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    rm -rf "$VAULT_PATH"
    ok "Removed vault structure"
  else
    warn "Kept vault structure at $VAULT_PATH"
  fi
fi

# --- Remove provider configs ---
info "Cleaning provider configs ..."

# Claude Code
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
if [ -f "$CLAUDE_SETTINGS" ] && [ "$HAS_JQ" = true ]; then
  jq 'del(.mcpServers.singularity) | del(.hooks.SessionStart) | del(.hooks.SessionEnd)' \
    "$CLAUDE_SETTINGS" > "${CLAUDE_SETTINGS}.tmp" && mv "${CLAUDE_SETTINGS}.tmp" "$CLAUDE_SETTINGS"
  ok "Claude Code — removed Singularity config"
fi
rm -f "$HOME/.claude/skills/distill" 2>/dev/null

# Cursor
CURSOR_MCP="$HOME/.cursor/mcp.json"
if [ -f "$CURSOR_MCP" ] && [ "$HAS_JQ" = true ]; then
  jq 'del(.mcpServers.singularity)' "$CURSOR_MCP" > "${CURSOR_MCP}.tmp" && mv "${CURSOR_MCP}.tmp" "$CURSOR_MCP"
  ok "Cursor — removed Singularity config"
fi

# Windsurf
WINDSURF_MCP="$HOME/.windsurf/mcp.json"
if [ -f "$WINDSURF_MCP" ] && [ "$HAS_JQ" = true ]; then
  jq 'del(.mcpServers.singularity)' "$WINDSURF_MCP" > "${WINDSURF_MCP}.tmp" && mv "${WINDSURF_MCP}.tmp" "$WINDSURF_MCP"
  ok "Windsurf — removed Singularity config"
fi
WINDSURF_HOOKS="$HOME/.windsurf/hooks.json"
if [ -f "$WINDSURF_HOOKS" ] && [ "$HAS_JQ" = true ]; then
  jq 'del(.hooks.pre_user_prompt)' "$WINDSURF_HOOKS" > "${WINDSURF_HOOKS}.tmp" && mv "${WINDSURF_HOOKS}.tmp" "$WINDSURF_HOOKS"
  ok "Windsurf — removed hooks"
fi

# Copilot
GITHUB_HOOKS_DIR="$HOME/.github/hooks"
if [ -f "$GITHUB_HOOKS_DIR/singularity-session-start.json" ] || [ -f "$GITHUB_HOOKS_DIR/singularity-session-end.json" ]; then
  rm -f "$GITHUB_HOOKS_DIR/singularity-session-start.json" "$GITHUB_HOOKS_DIR/singularity-session-end.json"
  ok "Copilot — removed hook files"
fi
rm -f "$HOME/.github/skills/distill" 2>/dev/null

echo ""
info "Uninstall complete. Restart your AI assistant."
echo ""

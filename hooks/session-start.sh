#!/bin/bash
# Singularity — Session Start Hook
# Non-blocking check: remind user if distillation is overdue.
# Usage: SINGULARITY_PROVIDER=claude ~/.singularity/hooks/session-start.sh

source "$HOME/.singularity/.env"
VAULT_PATH="${SINGULARITY_VAULT_PATH}"
DISTILLED_DIR="$VAULT_PATH/Distilled"

if [ -d "$DISTILLED_DIR" ]; then
  LATEST=$(ls -t "$DISTILLED_DIR"/*.md 2>/dev/null | head -1)
  if [ -n "$LATEST" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      DAYS_OLD=$(( ($(date +%s) - $(stat -f %m "$LATEST")) / 86400 ))
    else
      DAYS_OLD=$(( ($(date +%s) - $(stat -c %Y "$LATEST")) / 86400 ))
    fi
    if [ "$DAYS_OLD" -gt 7 ]; then
      echo "Singularity: Last distillation was ${DAYS_OLD} days ago. Consider running a distillation."
    fi
  else
    echo "Singularity: No distillation notes yet. Consider distilling after a few sessions."
  fi
fi

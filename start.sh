#!/bin/bash
set -e

CONFIG="/data/.openclaw/openclaw.json"

if [ -f "$CONFIG" ]; then
  node -e "
const fs = require('fs');
const config = JSON.parse(fs.readFileSync('$CONFIG', 'utf8'));
const d = config.agents && config.agents.defaults;
if (d && d.model && d.model.primary && d.model.primary.startsWith('google/')) {
  d.models = { 'openai/gpt-4.1': {}, 'openai/gpt-4o-mini': {} };
  d.model = { primary: 'openai/gpt-4.1' };
  fs.writeFileSync('$CONFIG', JSON.stringify(config, null, 2));
  console.log('[start] Switched model to openai/gpt-4.1');
} else {
  console.log('[start] Model already: ' + (d && d.model && d.model.primary));
}
"
fi

# ── Sync workspace scripts from GitHub ───────────────────────────────────────
# Pull latest scripts from ben-flowdesk/alphaclaw-agent on every boot.
# Requires GITHUB_TOKEN env var set in Railway with repo read access.
SCRIPTS_DIR="/data/.openclaw/workspace/scripts"
SCRIPTS_REPO="https://raw.githubusercontent.com/ben-flowdesk/alphaclaw-agent/main/scripts"

if [ -n "$GITHUB_TOKEN" ]; then
  mkdir -p "$SCRIPTS_DIR"
  for script in youtube-to-brain.mjs x-to-brain.mjs; do
    curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" \
      "$SCRIPTS_REPO/$script" -o "$SCRIPTS_DIR/$script" 2>/dev/null \
      && echo "[start] Updated $script" \
      || echo "[start] Could not fetch $script (skipping)"
  done
else
  echo "[start] GITHUB_TOKEN not set — skipping script sync"
fi
# ─────────────────────────────────────────────────────────────────────────────

exec alphaclaw start

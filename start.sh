#!/bin/bash
set -e

CONFIG="/data/.openclaw/openclaw.json"

if [ -f "$CONFIG" ]; then
  node -e "
const fs = require('fs');
const config = JSON.parse(fs.readFileSync('$CONFIG', 'utf8'));
const d = config.agents && config.agents.defaults;
if (d) {
  const current = d.model && d.model.primary;
  const needsSwitch = current && current.startsWith('google/');
  // Always normalize model config — remove unsupported fields like 'fallback'
  d.models = { 'openai/gpt-5.5': {}, 'openai/gpt-5.5-mini': {} };
  d.model = { primary: 'openai/gpt-5.5' };
  fs.writeFileSync('$CONFIG', JSON.stringify(config, null, 2));
  if (needsSwitch) {
    console.log('[start] Switched model from ' + current + ' to openai/gpt-5.5');
  } else {
    console.log('[start] Model config normalized: openai/gpt-5.5');
  }
}
"
fi

# ── Sync full workspace from GitHub ──────────────────────────────────────────
# Pull latest workspace (bootstrap hooks, skills, etc) from ben-flowdesk/alphaclaw-agent.
WORKSPACE_DIR="/data/.openclaw/workspace"

if [ -n "$GITHUB_TOKEN" ] && [ -d "$WORKSPACE_DIR/.git" ]; then
  cd "$WORKSPACE_DIR"
  git config user.email "alphaclaw@flowdesk.ai"
  git config user.name "AlphaClaw"
  git remote set-url origin "https://${GITHUB_TOKEN}@github.com/ben-flowdesk/alphaclaw-agent.git"
  git pull --rebase origin main 2>&1 | tail -3 \
    && echo "[start] Workspace synced from GitHub" \
    || echo "[start] Workspace sync failed (continuing with local)"
  cd /
fi
# ─────────────────────────────────────────────────────────────────────────────

# ── Sync workspace scripts from GitHub ───────────────────────────────────────
# Keep individual script files up to date from raw GitHub URLs.
SCRIPTS_DIR="/data/.openclaw/workspace/scripts"
SCRIPTS_REPO="https://raw.githubusercontent.com/ben-flowdesk/alphaclaw-agent/main/scripts"

if [ -n "$GITHUB_TOKEN" ]; then
  mkdir -p "$SCRIPTS_DIR"
  for script in youtube-to-brain.mjs x-to-brain.mjs package.json; do
    curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" \
      "$SCRIPTS_REPO/$script" -o "$SCRIPTS_DIR/$script" 2>/dev/null \
      && echo "[start] Updated $script" \
      || echo "[start] Could not fetch $script (skipping)"
  done
  # Install script dependencies
  if [ -f "$SCRIPTS_DIR/package.json" ]; then
    cd "$SCRIPTS_DIR" && /data/.bun/bin/bun install --frozen-lockfile 2>/dev/null \
      || /data/.bun/bin/bun install 2>/dev/null \
      && echo "[start] Script deps installed" \
      || echo "[start] Script deps install failed"
    cd /
  fi
else
  echo "[start] GITHUB_TOKEN not set — skipping script sync"
fi
# ─────────────────────────────────────────────────────────────────────────────

# ── Install bird CLI (@steipete/bird) ────────────────────────────────────────
if [ ! -f "/root/.bun/bin/bird" ]; then
  /data/.bun/bin/bun install -g @steipete/bird 2>/dev/null \
    && echo "[start] bird installed" \
    || echo "[start] bird install failed"
fi
# ─────────────────────────────────────────────────────────────────────────────

# ── Wire brain repo remote ────────────────────────────────────────────────────
# Set up ben-flowdesk/alphaclaw-brain as the remote for the brain git repo.
# Uses GITHUB_TOKEN (ben-flowdesk PAT) already set in Railway env.
BRAIN_DIR="/data/.openclaw/brain"
BRAIN_REMOTE="https://${GITHUB_TOKEN}@github.com/ben-flowdesk/alphaclaw-brain.git"

if [ -n "$GITHUB_TOKEN" ] && [ -d "$BRAIN_DIR/.git" ]; then
  cd "$BRAIN_DIR"
  if ! git remote get-url origin &>/dev/null; then
    git remote add origin "$BRAIN_REMOTE"
    echo "[start] Brain remote added: ben-flowdesk/alphaclaw-brain"
  else
    git remote set-url origin "$BRAIN_REMOTE"
  fi
  git config user.email "alphaclaw@flowdesk.ai"
  git config user.name "AlphaClaw"
  # Push current brain on first boot (force to init empty remote)
  git push -u origin main --force 2>&1 | tail -3 \
    && echo "[start] Brain pushed to GitHub" \
    || echo "[start] Brain push failed (will retry on next sync)"
  cd /
fi
# ─────────────────────────────────────────────────────────────────────────────

exec alphaclaw start

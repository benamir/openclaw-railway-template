#!/bin/bash
set -e

# Patch the runtime config to use OpenAI if still set to Gemini.
# The config lives on the persistent volume at /data/openclaw.json
# and is not overwritten by git syncs.
if [ -f /data/openclaw.json ]; then
  node -e "
const fs = require('fs');
const config = JSON.parse(fs.readFileSync('/data/openclaw.json', 'utf8'));
const d = config.agents && config.agents.defaults;
if (d && d.model && d.model.primary && d.model.primary.startsWith('google/')) {
  d.models = { 'openai/gpt-4.1': {}, 'openai/gpt-4o-mini': {} };
  d.model = { primary: 'openai/gpt-4.1' };
  fs.writeFileSync('/data/openclaw.json', JSON.stringify(config, null, 2));
  console.log('[start] Switched model to openai/gpt-4.1');
} else {
  console.log('[start] Model already set to: ' + (d && d.model && d.model.primary));
}
"
fi

exec alphaclaw start

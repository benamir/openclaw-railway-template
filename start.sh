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

exec alphaclaw start

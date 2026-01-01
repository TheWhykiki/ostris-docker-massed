#!/usr/bin/env bash
set -euo pipefail

: "${AI_TOOLKIT_AUTH:=password}"
export AI_TOOLKIT_AUTH

echo "[ai-toolkit] starting UI on :8675"
cd /app/ai-toolkit/ui
npm run start

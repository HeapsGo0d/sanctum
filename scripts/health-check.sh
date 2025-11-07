#!/bin/bash
# Sanctum Health Check
# Verifies both Ollama and Open WebUI are responding

set -euo pipefail

# Check Ollama
if ! curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "❌ Ollama health check failed"
    exit 1
fi

# Check Open WebUI
if ! curl -sf http://localhost:${WEBUI_PORT:-8080} > /dev/null 2>&1; then
    echo "❌ Open WebUI health check failed"
    exit 1
fi

echo "✓ All services healthy"
exit 0

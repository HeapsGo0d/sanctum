#!/bin/bash
# Sanctum Startup Script
# Minimal, privacy-focused Ollama + Open WebUI for RunPod

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$@"

    case $level in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
        *)
            echo -e "$message"
            ;;
    esac
}

print_banner() {
    log "INFO" ""
    log "INFO" "╔═══════════════════════════════════════════╗"
    log "INFO" "║           🔒 SANCTUM v1.0.4              ║"
    log "INFO" "║   Privacy-Focused Ollama + Open WebUI   ║"
    log "INFO" "╚═══════════════════════════════════════════╝"
    log "INFO" ""
}

print_config() {
    log "INFO" "📋 Configuration:"
    if [[ "${PRIVACY_MODE:-enabled}" == "enabled" ]]; then
        log "INFO" "  • Privacy Mode: enabled (20 domains blocked)"
    else
        log "INFO" "  • Privacy Mode: ${PRIVACY_MODE:-enabled}"
    fi
    log "INFO" "  • Ollama Models: /workspace/models"
    log "INFO" "  • WebUI Data: /workspace/data"
    log "INFO" "  • WebUI Port: ${WEBUI_PORT:-8080}"
    log "INFO" ""
}

check_gpu() {
    log "INFO" "🔍 Checking GPU availability..."

    if command -v nvidia-smi &> /dev/null; then
        GPU_INFO=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits | head -1 || echo "Unknown")
        log "INFO" "  ✓ GPU Detected: $GPU_INFO"
    else
        log "WARN" "  ⚠ No NVIDIA GPU detected (will run in CPU mode)"
    fi

    log "INFO" ""
}

setup_storage() {
    log "INFO" "💾 Setting up storage directories..."

    mkdir -p /workspace/models
    mkdir -p /workspace/data

    log "INFO" "  ✓ /workspace/models (Ollama models)"
    log "INFO" "  ✓ /workspace/data (Open WebUI data)"
    log "INFO" ""
}

setup_privacy() {
    # Privacy approach: /etc/hosts blocklist only (simple and effective)
    # - No iptables filtering (can't filter by domain names, only IPs)
    # - No additional Python monitoring packages (psutil, httpx) needed
    # - This keeps the image minimal and the privacy promise honest
    if [[ "${PRIVACY_MODE:-enabled}" == "enabled" ]]; then
        log "INFO" "🔒 Setting up privacy protections..."

        # Setup telemetry blocklist
        if [[ -x /scripts/privacy/setup-blocklist.sh ]]; then
            /scripts/privacy/setup-blocklist.sh
        fi

        log "INFO" ""
    else
        log "INFO" "⚠️  Privacy mode disabled"
        log "INFO" ""
    fi
}

start_ollama() {
    log "INFO" "🚀 Starting Ollama..."

    # Start Ollama in background
    ollama serve > /tmp/ollama.log 2>&1 &
    OLLAMA_PID=$!

    log "INFO" "  • Ollama PID: $OLLAMA_PID"
    log "INFO" "  • Waiting for Ollama to be ready..."

    # Wait for Ollama (max 30 seconds)
    for i in {1..30}; do
        if curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
            log "INFO" "  ✓ Ollama ready on port 11434"
            return 0
        fi
        sleep 1
    done

    log "ERROR" "❌ Ollama failed to start within 30 seconds"
    log "ERROR" "Last 20 lines of Ollama log:"
    tail -20 /tmp/ollama.log
    exit 1
}

start_webui() {
    log "INFO" "🌐 Starting Open WebUI..."

    # Start Open WebUI in background
    open-webui serve --host 0.0.0.0 --port ${WEBUI_PORT:-8080} > /tmp/webui.log 2>&1 &
    WEBUI_PID=$!

    log "INFO" "  • WebUI PID: $WEBUI_PID"
    log "INFO" "  • Waiting for WebUI to be ready..."

    # Wait for Open WebUI (max 30 seconds)
    for i in {1..30}; do
        if curl -sf http://localhost:${WEBUI_PORT:-8080} > /dev/null 2>&1; then
            log "INFO" "  ✓ Open WebUI ready on port ${WEBUI_PORT:-8080}"
            return 0
        fi
        sleep 1
    done

    log "ERROR" "❌ Open WebUI failed to start within 30 seconds"
    log "ERROR" "Last 20 lines of WebUI log:"
    tail -20 /tmp/webui.log
    exit 1
}

print_success() {
    log "INFO" ""
    log "INFO" "✅ Sanctum started successfully!"
    log "INFO" ""
    log "INFO" "📡 Access Information:"
    log "INFO" "  • Open WebUI: http://0.0.0.0:${WEBUI_PORT:-8080}"
    log "INFO" "  • Ollama API: http://0.0.0.0:11434"
    log "INFO" ""
    log "INFO" "🔒 Privacy Status:"
    if [[ "${PRIVACY_MODE:-enabled}" == "enabled" ]]; then
        log "INFO" "  ✓ Telemetry blocking enabled"
        log "INFO" "  ✓ Analytics domains blocked via /etc/hosts"
    else
        log "INFO" "  ⚠ Privacy protections disabled"
    fi
    log "INFO" ""
    log "INFO" "💡 Next Steps:"
    log "INFO" "  1. Open the WebUI URL above"
    log "INFO" "  2. Go to Settings → Models → Pull Model"
    log "INFO" "  3. Start with a small model like llama3.2:1b"
    log "INFO" ""
}

# Main execution
main() {
    print_banner
    print_config
    check_gpu
    setup_storage
    setup_privacy
    start_ollama
    start_webui
    print_success

    log "INFO" "🔄 Container running - press Ctrl+C to stop"
    log "INFO" ""

    # Keep container alive
    tail -f /dev/null
}

main "$@"

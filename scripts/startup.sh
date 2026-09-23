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
    log "INFO" "║              🔒 SANCTUM                  ║"
    log "INFO" "║   Privacy-Focused Ollama + Open WebUI   ║"
    log "INFO" "╚═══════════════════════════════════════════╝"
    log "INFO" "                                ${SANCTUM_VERSION:-dev}"
    log "INFO" ""
}

print_config() {
    log "INFO" "📋 Configuration:"
    log "INFO" "  • Ollama Cloud: disabled (OLLAMA_NO_CLOUD=1)"
    log "INFO" "  • Ollama Models: /workspace/models"
    log "INFO" "  • WebUI Data: /workspace/data"
    log "INFO" "  • WebUI Port: ${WEBUI_PORT:-8080}"
    log "INFO" "  • RAG Embeddings: ${RAG_EMBEDDING_ENGINE:-ollama} / ${RAG_EMBEDDING_MODEL:-nomic-embed-text}"
    log "INFO" ""
}

warn_if_config_reset() {
    # One-shot re-seed of Open WebUI's persisted settings from the environment.
    # Loud on purpose: left on, it silently wipes admin-panel changes every boot.
    if [[ "${RESET_CONFIG_ON_START:-false}" == "true" ]]; then
        log "WARN" ""
        log "WARN" "══════════════════════════════════════════════════════════════"
        log "WARN" "  RESET_CONFIG_ON_START=true"
        log "WARN" "  Open WebUI will WIPE every admin-panel setting on this boot"
        log "WARN" "  and re-seed it from the environment. Users and chats are"
        log "WARN" "  kept. Switch this variable back off after this boot, or it"
        log "WARN" "  happens on every restart."
        log "WARN" "══════════════════════════════════════════════════════════════"
        log "WARN" ""
    fi
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

ensure_embedding_model() {
    # RAG_EMBEDDING_ENGINE=ollama means Open WebUI never downloads a model from
    # Hugging Face, but Ollama needs an embedding model to hand it. Pull once;
    # it lives on the volume afterwards. This is an outbound call to
    # registry.ollama.ai carrying the model name - the same channel every chat
    # model pull uses.
    local model="${RAG_EMBEDDING_MODEL:-nomic-embed-text}"
    log "INFO" "🧬 Checking embedding model for RAG..."

    if ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qE "^${model}(:latest)?$"; then
        log "INFO" "  ✓ ${model} present in /workspace/models"
    else
        log "INFO" "  • ${model} not found - pulling from registry.ollama.ai (one-time, persists on the volume)"
        if ollama pull "${model}" > /tmp/embed-pull.log 2>&1; then
            log "INFO" "  ✓ ${model} pulled"
        else
            log "WARN" "  ⚠ Pull failed - RAG and file uploads will error until an embedding model exists"
            tail -5 /tmp/embed-pull.log || true
        fi
    fi
    log "INFO" ""
}

start_webui() {
    log "INFO" "🌐 Starting Open WebUI..."

    # Start Open WebUI in background, from DATA_DIR: `open-webui serve` writes
    # .webui_secret_key to its cwd when WEBUI_SECRET_KEY is unset, and that key
    # must live on the volume or every login session is invalidated on restart.
    # exec keeps $! pointing at the server itself, not the subshell.
    ( cd "${DATA_DIR:-/workspace/data}" && exec open-webui serve --host 0.0.0.0 --port "${WEBUI_PORT:-8080}" ) > /tmp/webui.log 2>&1 &
    WEBUI_PID=$!

    log "INFO" "  • WebUI PID: $WEBUI_PID"
    log "INFO" "  • Waiting for WebUI to be ready..."

    # Wait for Open WebUI (max 120 seconds - first boot runs DB migrations)
    for i in {1..120}; do
        if curl -sf http://localhost:${WEBUI_PORT:-8080}/health > /dev/null 2>&1; then
            log "INFO" "  ✓ Open WebUI ready on port ${WEBUI_PORT:-8080}"
            return 0
        fi
        sleep 1
    done

    log "ERROR" "❌ Open WebUI failed to start within 120 seconds"
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
    log "INFO" "🔒 Privacy:"
    log "INFO" "  ✓ Ollama cloud features disabled (OLLAMA_NO_CLOUD=1)"
    log "INFO" "  ✓ Open WebUI telemetry disabled"
    log "INFO" "  • Model pulls still contact registry.ollama.ai (see README)"
    log "INFO" ""
    log "INFO" "💡 Next Steps:"
    log "INFO" "  1. Open the WebUI URL above"
    log "INFO" "  2. Go to Settings → Models → Pull Model"
    log "INFO" "  3. Start with a small model like llama3.2:1b"
    log "INFO" ""
}

# Shut down both services on signal or on exit
cleanup() {
    [[ "${CLEANUP_DONE:-false}" == "true" ]] && return
    CLEANUP_DONE=true
    log "INFO" "🛑 Shutting down Sanctum..."
    kill "${WEBUI_PID:-}" "${OLLAMA_PID:-}" 2>/dev/null || true
    wait 2>/dev/null || true
}

trap 'cleanup; exit 0' SIGTERM SIGINT

# Main execution
main() {
    print_banner
    print_config
    warn_if_config_reset
    check_gpu
    setup_storage
    start_ollama
    ensure_embedding_model
    start_webui
    print_success

    log "INFO" "🔄 Container running - press Ctrl+C to stop"
    log "INFO" ""

    # Supervise: return as soon as either service exits, so a dead service
    # takes the container down instead of leaving a zombie pod running.
    wait -n "$OLLAMA_PID" "$WEBUI_PID" || true

    log "ERROR" ""
    log "ERROR" "❌ A service exited unexpectedly"
    log "ERROR" "Last 20 lines of each log:"
    tail -20 /tmp/ollama.log /tmp/webui.log 2>/dev/null || true
    cleanup
    exit 1
}

main "$@"

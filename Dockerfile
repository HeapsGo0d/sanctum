# Sanctum - Privacy-Focused Ollama + Open WebUI for RunPod
# Minimal, clean, privacy-first

FROM ubuntu:22.04

# Consolidated environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH \
    CUDA_DEVICE_ORDER=PCI_BUS_ID

# Ollama configuration
ENV OLLAMA_HOST=127.0.0.1 \
    OLLAMA_MODELS=/workspace/models \
    OLLAMA_NUM_PARALLEL=2 \
    OLLAMA_NO_CLOUD=1

# Open WebUI configuration
ENV DATA_DIR=/workspace/data \
    WEBUI_AUTH=True \
    ENABLE_SIGNUP=false \
    DEFAULT_USER_ROLE=pending \
    WEBUI_PORT=8080 \
    OLLAMA_BASE_URL=http://127.0.0.1:11434 \
    SCARF_NO_ANALYTICS=true \
    DO_NOT_TRACK=true \
    ANONYMIZED_TELEMETRY=false \
    AUDIT_LOG_LEVEL=NONE \
    ENABLE_AUDIT_LOGS_FILE=false

# Open WebUI outbound features - all off. Each is on by default upstream and
# would contact a third party. OFFLINE_MODE also forces the GitHub version
# check off and HF_HUB_OFFLINE=1; embeddings go through Ollama instead of a
# Hugging Face download. See README "What prevents outbound contact".
ENV ENABLE_COMMUNITY_SHARING=false \
    ENABLE_OPENAI_API=false \
    ENABLE_DIRECT_CONNECTIONS=false \
    ENABLE_WEB_SEARCH=false \
    ENABLE_CODE_EXECUTION=false \
    ENABLE_CODE_INTERPRETER=false \
    OFFLINE_MODE=true \
    RAG_EMBEDDING_ENGINE=ollama \
    RAG_EMBEDDING_MODEL=nomic-embed-text

# Sanctum version (stamped by CI from the git tag; "dev" for local builds)
ARG SANCTUM_VERSION=dev
ENV SANCTUM_VERSION=${SANCTUM_VERSION}

# System dependencies + Python 3.11
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    software-properties-common \
    gnupg \
    build-essential \
    procps \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    python3-pip \
    zstd \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Ollama (manual binary installation - proper method)
# Version pinned for reproducible builds - review quarterly for updates
# Note: upstream switched the linux asset from .tgz to .tar.zst - see CONTEXT.md
ARG OLLAMA_VERSION=v0.32.14
RUN curl -fsSL -o /tmp/ollama.tar.zst \
    https://github.com/ollama/ollama/releases/download/${OLLAMA_VERSION}/ollama-linux-amd64.tar.zst \
    && tar -C /usr --zstd -xf /tmp/ollama.tar.zst \
    && rm /tmp/ollama.tar.zst \
    && test -x /usr/bin/ollama

# Install Open WebUI
# CPU-only torch goes in first so pip never pulls the CUDA build that
# sentence-transformers would otherwise drag in (~4.5GB). Ollama owns GPU
# inference and ships its own CUDA runtime - see CONTEXT.md.
RUN python3.11 -m pip install --no-cache-dir --upgrade pip setuptools wheel \
    && python3.11 -m pip install --no-cache-dir torch \
    --index-url https://download.pytorch.org/whl/cpu \
    && python3.11 -m pip install --no-cache-dir open-webui \
    && python3.11 -c "import torch; assert torch.__version__.endswith('+cpu'), 'CUDA torch leaked in: ' + torch.__version__"

# Create workspace directories
RUN mkdir -p /workspace/models /workspace/data

# Copy scripts
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh

# Expose ports
# 8080 - Open WebUI (HTTP)
# 11434 - Ollama API, loopback only (OLLAMA_HOST=127.0.0.1): no auth, so nothing
#         outside this network namespace may reach it
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD /scripts/health-check.sh || exit 1

# Entrypoint
ENTRYPOINT ["/scripts/startup.sh"]

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
ENV OLLAMA_HOST=0.0.0.0 \
    OLLAMA_MODELS=/workspace/models \
    OLLAMA_NUM_PARALLEL=2 \
    OLLAMA_NO_CLOUD=1

# Open WebUI configuration
ENV DATA_DIR=/workspace/data \
    WEBUI_AUTH=False \
    WEBUI_PORT=8080 \
    OLLAMA_BASE_URL=http://127.0.0.1:11434 \
    SCARF_NO_ANALYTICS=true \
    DO_NOT_TRACK=true \
    ANONYMIZED_TELEMETRY=false \
    AUDIT_LOG_LEVEL=NONE \
    ENABLE_AUDIT_LOGS_FILE=false

# Privacy configuration
ENV PRIVACY_MODE=enabled

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
    iptables \
    iproute2 \
    net-tools \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Ollama (manual binary installation - proper method)
# Version pinned for reproducible builds - review quarterly for updates
ARG OLLAMA_VERSION=v0.12.10
RUN curl -fsSL -o /tmp/ollama-linux-amd64.tgz \
    https://github.com/ollama/ollama/releases/download/${OLLAMA_VERSION}/ollama-linux-amd64.tgz \
    && tar -C /usr -xzf /tmp/ollama-linux-amd64.tgz \
    && rm /tmp/ollama-linux-amd64.tgz

# Upgrade pip, setuptools, and wheel for compatibility
RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel

# Install Open WebUI
RUN pip3 install --no-cache-dir open-webui

# Create workspace directories
RUN mkdir -p /workspace/models /workspace/data /scripts/privacy

# Copy scripts
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh /scripts/privacy/*.sh

# Expose ports
# 8080 - Open WebUI (HTTP)
# 11434 - Ollama API (internal, not exposed)
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD /scripts/health-check.sh || exit 1

# Entrypoint
ENTRYPOINT ["/scripts/startup.sh"]

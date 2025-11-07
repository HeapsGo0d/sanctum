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
    OLLAMA_NUM_PARALLEL=2

# Open WebUI configuration
ENV DATA_DIR=/workspace/data \
    WEBUI_AUTH=False \
    WEBUI_PORT=8080

# Privacy configuration
ENV PRIVACY_MODE=enabled \
    ALLOWED_DOMAINS=ollama.com,huggingface.co,registry.ollama.ai,ghcr.io

# System dependencies + Python 3.11
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    software-properties-common \
    gnupg \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    python3.11 \
    python3.11-venv \
    python3-pip \
    iptables \
    iproute2 \
    net-tools \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Ollama (using official install script)
RUN curl -fsSL https://ollama.com/install.sh | sh

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
# 22 - SSH (RunPod default)
EXPOSE 8080 22

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD /scripts/health-check.sh || exit 1

# Entrypoint
ENTRYPOINT ["/scripts/startup.sh"]

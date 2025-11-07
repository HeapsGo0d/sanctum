# 🔒 Sanctum - Privacy-Focused Ollama + Open WebUI for RunPod

**Minimal · Privacy-First · RunPod-Native**

Sanctum is a privacy-focused RunPod template for running Ollama + Open WebUI with network isolation, telemetry blocking, and controlled egress. Built for simplicity and security.

## ✨ Features

- **🔒 Privacy-First**: Network isolation with allowlist, telemetry blocking via /etc/hosts
- **⚡ Fast Startup**: Two services, no unnecessary operations
- **🎯 Minimal**: Clean architecture, essential functionality only
- **💾 Persistent Storage**: Models and data survive pod restarts
- **🎮 GPU Support**: Automatic NVIDIA GPU detection and configuration
- **🔧 RunPod-Native**: Designed specifically for RunPod deployment

## 🚀 Quick Start (RunPod)

### 1. Create Template

Use the template generator script:

```bash
./template.sh
```

Or for automatic API deployment:

```bash
export RUNPOD_API_KEY="your_runpod_api_key"
./template.sh --deploy
```

### 2. Deploy Pod

1. Go to RunPod Templates
2. Upload `sanctum_template.json` (or use API-deployed template)
3. Deploy pod with GPU (RTX 4090, A100, etc.)
4. Wait for startup (~30 seconds)

### 3. Access Open WebUI

Once running, access Open WebUI at:
```
http://[your-pod-id]-8080.proxy.runpod.net
```

SSH access (optional):
```bash
ssh root@[your-pod-id]-ssh.proxy.runpod.net
```

## 🧪 Local Testing

Test locally with Docker Compose:

```bash
# Build and run
docker-compose up

# Access Open WebUI
open http://localhost:8080
```

Test privacy mode:
```bash
# Shell into container
docker exec -it sanctum bash

# Check iptables rules
iptables -L OUTPUT -n -v

# Check blocked domains
grep "0.0.0.0" /etc/hosts
```

## 📋 Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_HOST` | `0.0.0.0` | Ollama server bind address |
| `OLLAMA_MODELS` | `/workspace/models` | Ollama models directory |
| `OLLAMA_NUM_PARALLEL` | `2` | Number of parallel requests |
| `DATA_DIR` | `/workspace/data` | Open WebUI data directory |
| `WEBUI_AUTH` | `False` | Enable Open WebUI authentication |
| `WEBUI_PORT` | `8080` | Open WebUI port |
| `PRIVACY_MODE` | `enabled` | Enable privacy protections (`enabled`/`disabled`) |
| `ALLOWED_DOMAINS` | `ollama.com,huggingface.co,registry.ollama.ai,ghcr.io` | Allowed domains for network access |

## 🔒 Privacy Features

### Network Isolation

When `PRIVACY_MODE=enabled` (default):

- **Default Deny**: All outbound traffic blocked by default
- **Allowlist Only**: Only specified domains can be accessed
- **DNS Filtering**: /etc/hosts blocks telemetry domains
- **Localhost Allowed**: Internal service communication works
- **Established Connections**: Return traffic allowed

Allowed domains by default:
- `ollama.com` - Ollama model downloads
- `huggingface.co` - HuggingFace models
- `registry.ollama.ai` - Ollama registry
- `ghcr.io` - GitHub Container Registry

### Telemetry Blocking

Blocks common analytics and tracking domains:
- Google Analytics, Tag Manager
- Segment, Amplitude, Mixpanel
- Sentry, PostHog, Hotjar
- AI/ML tracking (OpenAI, Anthropic, HuggingFace)

View blocked domains:
```bash
grep "0.0.0.0" /etc/hosts
```

### Disable Privacy Mode

To disable privacy protections:
```bash
PRIVACY_MODE=disabled
```

Or edit in RunPod template environment variables.

## 💾 Storage

### Persistent Data

- `/workspace/models` - Ollama models (survives restarts)
- `/workspace/data` - Open WebUI data (survives restarts)

### Volume Configuration

Set volume size in template or RunPod UI:
- **0GB**: Ephemeral (models redownload on restart)
- **20GB+**: Persistent (recommended for production)

## 🔧 Usage

### Download Models

Access Open WebUI and download models through the UI:

1. Open http://[pod-id]-8080.proxy.runpod.net
2. Go to Settings → Models
3. Pull models (e.g., `llama2`, `mistral`, `codellama`)

Models are stored in `/workspace/models` and persist across restarts.

### Via SSH

SSH into pod and use Ollama CLI:

```bash
# Pull a model
ollama pull llama2

# List models
ollama list

# Run a model
ollama run llama2

# Check service status
curl http://localhost:11434/api/tags
curl http://localhost:8080
```

## 🐛 Troubleshooting

### Services Not Starting

Check logs:
```bash
# Ollama logs
tail -f /tmp/ollama.log

# WebUI logs
tail -f /tmp/webui.log
```

### GPU Not Detected

Verify GPU is available:
```bash
nvidia-smi
```

### Network Issues

Check iptables rules:
```bash
iptables -L OUTPUT -n -v
```

Disable privacy mode temporarily:
```bash
export PRIVACY_MODE=disabled
# Restart container
```

### Health Check Failures

Manually check service health:
```bash
/scripts/health-check.sh
```

## 📁 Project Structure

```
sanctum/
├── Dockerfile                              # Container definition
├── README.md                               # This file
├── docker-compose.yml                      # Local testing
├── template.sh                             # RunPod template generator
├── sanctum_template.json                  # Generated template
├── .github/workflows/build-and-push.yml   # Auto build/push
└── scripts/
    ├── startup.sh                          # Main entrypoint
    ├── health-check.sh                    # Service verification
    └── privacy/
        ├── setup-network-isolation.sh      # iptables rules
        └── setup-blocklist.sh              # /etc/hosts blocking
```

## 🏗️ Development

### Build Locally

```bash
docker build -t sanctum:dev .
```

### Run Locally

```bash
docker run -d \
  --privileged \
  -p 8080:8080 \
  -v $(pwd)/test-workspace:/workspace \
  -e PRIVACY_MODE=enabled \
  sanctum:dev
```

### Push to Docker Hub

Configure GitHub secrets:
- `DOCKER_USERNAME`
- `DOCKER_PASSWORD`

Push to main branch triggers automatic build/push.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test thoroughly (local + RunPod)
4. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details.

## 🔐 Security Notes

- Privacy mode uses iptables - requires `--privileged` or `CAP_NET_ADMIN`
- `/etc/hosts` blocking may fail on read-only filesystems (gracefully degrades)
- Allowlist filtering is domain-based via DNS blocking
- For production use, consider additional network policies
- Default `WEBUI_AUTH=False` - enable authentication for public deployments

## 🙏 Acknowledgments

Built with:
- [Ollama](https://ollama.com) - Run large language models locally
- [Open WebUI](https://github.com/open-webui/open-webui) - ChatGPT-like interface
- [RunPod](https://runpod.io) - GPU cloud platform

Inspired by privacy-focused projects in the self-hosted AI community.

---

**🔒 Sanctum - Private AI, Your Way**

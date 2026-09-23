# 🔒 Sanctum - Privacy-Focused Ollama + Open WebUI for RunPod

**Minimal · Privacy-First · RunPod-Native**

Sanctum is a privacy-focused RunPod template for running Ollama + Open WebUI with telemetry blocking. Built for simplicity and security.

## ✨ Features

- **🔒 Privacy-First**: Telemetry blocking via /etc/hosts (22 analytics domains)
- **⚡ Fast Startup**: Two services, no unnecessary operations
- **🧩 Current Stack**: Ollama v0.32.14 + Open WebUI (latest on PyPI at build time)
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

# Non-interactive, pinned to a released tag:
./template.sh -y v1.1.0 --deploy
```

The script targets RunPod's REST API (`POST https://rest.runpod.io/v1/templates`) and
falls back to the legacy GraphQL `saveTemplate` mutation if that call fails.

### 2. Deploy Pod

1. Go to RunPod Templates
2. Upload `sanctum_template.json` (or use API-deployed template)
3. Deploy pod with GPU (RTX 4090, A100, etc.)
4. Wait for startup (~30s; first boot takes longer while Open WebUI migrates its database)

### 3. Access Open WebUI

Once running, access Open WebUI at:
```
https://[your-pod-id]-8080.proxy.runpod.net
```

**Note**: RunPod provides SSH access automatically. No additional configuration needed.

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

# Check blocked domains
grep "0.0.0.0" /etc/hosts
```

## 📋 Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_HOST` | `0.0.0.0` | Ollama server bind address |
| `OLLAMA_MODELS` | `/workspace/models` | Ollama models directory |
| `OLLAMA_NUM_PARALLEL` | `2` | Number of parallel requests |
| `OLLAMA_BASE_URL` | `http://127.0.0.1:11434` | Ollama API URL for Open WebUI |
| `DATA_DIR` | `/workspace/data` | Open WebUI data directory |
| `WEBUI_AUTH` | `True` | Open WebUI login. Leave on — a proxied RunPod pod is always public |
| `ENABLE_SIGNUP` | `false` | No self-registration after the first admin exists |
| `DEFAULT_USER_ROLE` | `pending` | Any account that does get created waits for admin approval |
| `WEBUI_ADMIN_EMAIL` | *(unset)* | With `WEBUI_ADMIN_PASSWORD`, pre-creates the admin at first boot |
| `WEBUI_ADMIN_PASSWORD` | *(unset)* | See above. Only used while the user table is empty |
| `WEBUI_PORT` | `8080` | Open WebUI port |
| `PRIVACY_MODE` | `enabled` | Enable telemetry blocking (`enabled`/`disabled`) |
| `RAG_EMBEDDING_ENGINE` | *(unset)* | Set to `ollama` to run RAG embeddings on the GPU via Ollama instead of the bundled CPU model |

### A Note on GPU Usage

Ollama does all model inference on the GPU using the CUDA runtime bundled in its own
release. Open WebUI's PyTorch is installed as a **CPU-only** build, because it is used
only for local RAG embeddings and Whisper transcription — keeping the CUDA wheels out
saves roughly 4.5GB of image, which is pod pull time on every cold start.

If you want RAG embeddings on the GPU, point them at Ollama instead:

```bash
ollama pull nomic-embed-text          # or any embedding model
# then set in the template environment:
RAG_EMBEDDING_ENGINE=ollama
```

## 🔐 Authentication

Login is on (`WEBUI_AUTH=True`). On RunPod every proxied pod is reachable by anyone who has
the URL, so there is no "private deployment" where auth-off is acceptable: with it off, the
first visitor is the admin, and the admin panel can add exfiltration endpoints or run Python
in the container.

### Fresh volume

Set `WEBUI_ADMIN_EMAIL` and `WEBUI_ADMIN_PASSWORD` in the template **before the first
boot**. Open WebUI creates that admin at startup (only while no users exist) and the first
signup race never happens.

If you leave them unset, the **first person to sign up becomes admin**. Open WebUI does not
gate that first signup on `ENABLE_SIGNUP`, so you cannot lock yourself out — but you must be
the one who gets there first. Open the URL as soon as the startup log prints
"Sanctum started successfully".

After the admin exists, `ENABLE_SIGNUP=false` closes registration and any account created by
other means sits at `DEFAULT_USER_ROLE=pending` until you approve it.

### Existing volume created with auth off (pre-v1.2.0)

Open WebUI's auth-off mode created a real admin account, **`admin@localhost` with password
`admin`**. Turning auth on against that database means anyone can log in with those
credentials until they are changed. Reset the password **before** you redeploy:

```bash
# On the pod (SSH), while it is still running the old image:
HASH=$(htpasswd -bnBC 10 "" 'your-new-password' | tr -d ':\n')
sqlite3 /workspace/data/webui.db \
  "UPDATE auth SET password='$HASH' WHERE email='admin@localhost';"
```

(`htpasswd` is in `apache2-utils`; `sqlite3` in `sqlite3`. This is the procedure from
Open WebUI's own password-reset docs.) Then redeploy with the new image and log in as
`admin@localhost`. Change the email in Settings → Account if you like.

The fallback — redeploy first, then log in as `admin`/`admin` and change it immediately —
works, but leaves a window where the default credentials are live on a public URL.
`WEBUI_ADMIN_EMAIL`/`PASSWORD` do nothing on this volume because users already exist.

## 🔒 Privacy Features

### Telemetry Blocking

When `PRIVACY_MODE=enabled` (default):

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

When you first open Open WebUI you'll see "No models available" — this is expected. Ollama is running but has no models downloaded yet.

**Via the UI:**
1. Click the model selector dropdown at the top
2. Type a model name and click **Search Ollama.com** — or —
3. Go to **Admin Panel** → **Settings** → **Models**, enter a model name in the pull field, and click the download button

**Via the terminal** (faster for large models):
```bash
# Shell into the container
docker exec -it <container_id> bash

# Pull any model by its Ollama Hub name
ollama pull llama3.2:3b
ollama pull mistral:7b
ollama pull qwen2.5:7b

# List downloaded models
ollama list
```

Browse available models at https://ollama.com/library. Use the full `name:tag` format when pulling (e.g. `llama3.2:3b`, not just `llama3.2`).

Models are stored in `/workspace/models` and persist across restarts.

### Via SSH (RunPod Host-Level)

SSH into your RunPod instance and use Ollama CLI:

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

### Check Privacy Status

View blocked telemetry domains:
```bash
grep "0.0.0.0" /etc/hosts
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
├── sanctum_template.json                  # Generated by template.sh (gitignored)
├── .github/workflows/build-and-push.yml   # Auto build/push
└── scripts/
    ├── startup.sh                          # Main entrypoint
    ├── health-check.sh                    # Service verification
    └── privacy/
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

Pushing a `v*` tag triggers the automatic build/push (see `.github/workflows/build-and-push.yml`).

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test thoroughly (local + RunPod)
4. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details.

## 🔐 Security Notes

- **Privacy Scope**: Blocks known telemetry/analytics domains via `/etc/hosts`
- **Limitations**: Does not provide full network isolation (open internet access remains)
- **Production Use**: Consider additional network policies (firewalls, VPNs) for stricter isolation
- **Authentication**: `WEBUI_AUTH=True`, signup closed. See the Authentication section for first-boot and migration steps
- **Graceful Degradation**: `/etc/hosts` blocking skipped on read-only filesystems
- **Supervision**: if Ollama or Open WebUI exits, the container exits too rather than
  leaving a pod that looks healthy with a dead service

## 🙏 Acknowledgments

Built with:
- [Ollama](https://ollama.com) - Run large language models locally
- [Open WebUI](https://github.com/open-webui/open-webui) - ChatGPT-like interface
- [RunPod](https://runpod.io) - GPU cloud platform

Inspired by privacy-focused projects in the self-hosted AI community.

---

**🔒 Sanctum - Private AI, Your Way**

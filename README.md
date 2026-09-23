# 🔒 Sanctum - Privacy-Focused Ollama + Open WebUI for RunPod

**Minimal · Privacy-First · RunPod-Native**

Sanctum is a privacy-focused RunPod template for running Ollama + Open WebUI: login on, telemetry off, no default-on features that talk to third parties. Built for simplicity and honesty about what it can and cannot protect.

## ✨ Features

- **🔒 Privacy-First**: Login required, all telemetry off, outbound features disabled by default
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

Check the privacy settings took effect:
```bash
docker exec sanctum env | grep -E 'OLLAMA_NO_CLOUD|ANONYMIZED_TELEMETRY|WEBUI_AUTH'
```

## 📋 Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_HOST` | `127.0.0.1` | Ollama bind address. Loopback only — the API has no authentication |
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
| `RAG_EMBEDDING_ENGINE` | `ollama` | RAG embeddings via Ollama — no Hugging Face download |
| `RAG_EMBEDDING_MODEL` | `nomic-embed-text` | Pulled onto the volume at first boot if missing |
| `OFFLINE_MODE` | `true` | No Hugging Face contact; also forces the GitHub version check off |
| `ENABLE_OPENAI_API` | `false` | No OpenAI-compatible connections (upstream default polls `api.openai.com`) |
| `ENABLE_COMMUNITY_SHARING` | `false` | Removes the "share to openwebui.com" button |
| `ENABLE_DIRECT_CONNECTIONS` | `false` | Users cannot add their own model endpoints |
| `ENABLE_WEB_SEARCH` | `false` | No search-provider calls |
| `ENABLE_CODE_EXECUTION` / `ENABLE_CODE_INTERPRETER` | `false` | Browser never fetches Pyodide from a CDN |
| `RESET_CONFIG_ON_START` | `false` | Set `true` for **one** boot to re-seed stored settings from these variables |

### A Note on GPU Usage

Ollama does all model inference on the GPU using the CUDA runtime bundled in its own
release. Open WebUI's PyTorch is installed as a **CPU-only** build, because it is used
only for local RAG embeddings and Whisper transcription — keeping the CUDA wheels out
saves roughly 4.5GB of image, which is pod pull time on every cold start.

RAG embeddings already go through Ollama (`RAG_EMBEDDING_ENGINE=ollama`,
`nomic-embed-text`, pulled at first boot), so they run on the GPU and nothing is fetched
from Hugging Face. Whisper transcription remains CPU-only and, with `OFFLINE_MODE=true`,
its model is not auto-downloaded — speech-to-text is effectively off unless you supply one.

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

## 🔒 What prevents outbound contact

There is no network filter in Sanctum. Earlier versions wrote an `/etc/hosts` blocklist; it
was removed in v1.2.0 because `/etc/hosts` matches exact hostnames only, and every real
telemetry endpoint is a subdomain (`posthog.com` does not block `us.i.posthog.com`;
Ollama's cloud lives at `ollama.com`, not the `ollama.ai` entries the list carried). It
blocked nothing while implying it did. The controls that work are settings:

| Setting | Stops |
|---|---|
| `OLLAMA_NO_CLOUD=1` | Ollama cloud inference (`*-cloud` models), web search and web fetch — each would send prompts to `ollama.com` |
| `ANONYMIZED_TELEMETRY=false` | Chroma's PostHog telemetry |
| `SCARF_NO_ANALYTICS=true`, `DO_NOT_TRACK=true` | Open WebUI and dependency analytics |
| `AUDIT_LOG_LEVEL=NONE`, `ENABLE_AUDIT_LOGS_FILE=false` | Request audit logs being written to the volume |
| `OFFLINE_MODE=true` | Hugging Face downloads (`HF_HUB_OFFLINE=1`) and the `api.github.com` version check |
| `RAG_EMBEDDING_ENGINE=ollama` | The `all-MiniLM-L6-v2` download from Hugging Face on first boot |
| `ENABLE_OPENAI_API=false` | Model-list polls to `api.openai.com` (on by default upstream, even with no key) |
| `ENABLE_COMMUNITY_SHARING=false` | The one-click chat upload to openwebui.com |
| `ENABLE_DIRECT_CONNECTIONS=false`, `ENABLE_WEB_SEARCH=false` | User-added endpoints and search providers |
| `ENABLE_CODE_EXECUTION=false`, `ENABLE_CODE_INTERPRETER=false` | Pyodide + packages fetched by your browser from jsdelivr/PyPI |

What still leaves the pod, by design:

- **Model pulls** go to `registry.ollama.ai` and carry the model name and the pod's IP.
- **The UI in your browser** is served by the pod, but RunPod's proxy and Cloudflare sit in
  front of it — see Security Notes.

### Admin-panel settings that affect privacy

Settings are persisted in `webui.db` and a value changed in the admin panel **overrides the
template** from then on. Leave these alone unless you mean it:

- **Settings → Connections**: OpenAI API, Direct Connections — any endpoint added here
  receives full conversations.
- **Settings → Web Search**: sends your query text to the provider.
- **Settings → Code Execution / Code Interpreter**: loads Pyodide from a CDN in your browser.
- **Settings → General → Community Sharing**: one-click upload of a chat to openwebui.com.
- **Workspace → Functions / Tools, Admin → Pipelines**: arbitrary Python running inside the
  container as the service user. These live in their own tables and are not touched by the
  config reset below.
- **Pulling a `*-cloud` model**: `OLLAMA_NO_CLOUD=1` refuses it, but the pull UI will still
  list them.

### Existing volumes: one-shot settings reset

A volume created before v1.2.0 has the old defaults stored in `webui.db` (OpenAI API on,
community sharing on, …) and those stored values win over the new template. To re-seed:

1. Note any admin-panel settings you changed on purpose — the reset wipes **all** of them.
   Users, chats, models and knowledge are untouched (it clears only the `config` table).
2. Set `RESET_CONFIG_ON_START=true` in the pod's environment and restart. The startup log
   prints a boxed warning while it is on.
3. Set it back to `false` and restart again. Left on, it wipes settings on every boot.

### Changing the embedding model

Anything already in `/workspace/data/vector_db/` was embedded with the old model and will not
match queries made with the new one. After the switch (including the v1.1 → v1.2 move to
`nomic-embed-text`), run **Admin → Settings → Documents → Reindex Knowledge and Memory
Vectors**, or re-upload the documents.

### What `OFFLINE_MODE=true` also turns off

- Local Whisper speech-to-text model auto-download (no STT unless you provide a model).
- `pip install` of a Function's declared `requirements` at install time.
- The "new version available" banner (the `api.github.com` check).

## 💾 Storage

### Persistent Data

- `/workspace/models` - Ollama models (survives restarts)
- `/workspace/data` - Open WebUI data (survives restarts)

### Volume Configuration

Set volume size in template or RunPod UI:
- **0GB**: Ephemeral (models redownload on restart)
- **20GB+**: Persistent (recommended for production)

## 👤 Service user

Ollama and Open WebUI run as `sanctum` (uid 1000), not root. The entrypoint starts as root
only to make `/workspace/models` and `/workspace/data` owned by that user, then launches
both services through `setpriv` with `--no-new-privs`. A Function or Tool that runs Python
inside Open WebUI therefore runs as `sanctum`, and cannot read root-only files or change the
image.

Two things to know:

- **First boot on an existing volume is slower.** The ownership fix is a recursive `chown`
  and runs only when the top-level owner is wrong — once per volume. On a volume already
  holding tens of GB of models, expect a minute or two.
- **If the volume refuses `chown`**, the startup log prints a red `FALLING BACK TO ROOT`
  block and runs both services as root so the pod stays usable. That is a deliberate,
  visible fallback, not a silent one — if you see it, privilege separation is off. RunPod
  documents nothing about volume ownership semantics; report what you see.

If `nvidia-smi` sees a GPU but Ollama does not report a CUDA device, the log warns; check
that `/dev/nvidia*` is readable by uid 1000.

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

# Check service status (Ollama listens on loopback only)
curl http://127.0.0.1:11434/api/tags
curl http://localhost:8080/health
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
    └── health-check.sh                    # Service verification
```

## 🏗️ Development

### Build Locally

```bash
docker build -t sanctum:dev .
```

### Run Locally

```bash
docker run -d \
  -p 8080:8080 \
  -v $(pwd)/test-workspace:/workspace \
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

- **Privacy Scope**: telemetry and outbound features are disabled by environment variables. There is no network-level filtering
- **Limitations**: Does not provide full network isolation (open internet access remains)
- **Production Use**: Consider additional network policies (firewalls, VPNs) for stricter isolation
- **Authentication**: `WEBUI_AUTH=True`, signup closed. See the Authentication section for first-boot and migration steps
- **Service user**: both services run as `sanctum` (uid 1000) via `setpriv`; root is used only to fix volume ownership at boot
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

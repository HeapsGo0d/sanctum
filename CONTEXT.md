# Sanctum - Project Context

**Last Updated**: 2026-08-19
**Current Version**: v1.1.0
**Status**: Active Development

## Project Philosophy

**"Simple, Functional, Elegant"**

Sanctum is designed to be the minimal, honest alternative to complex AI hosting templates. Core principles:

- **Only implement what actually works** - No aspirational features that don't deliver
- **Be honest about limitations** - Clear documentation about what we do/don't provide
- **Minimal complexity** - 7 core files, no supervisor loops, no unnecessary services
- **Fast startup** - Health checks with timeouts, no auto-downloads
- **Privacy-first** - Block telemetry where possible, be transparent about scope

## Architecture Decisions

### Why Manual Ollama Installation?
- **Decision**: Install Ollama via GitHub release tarball, not convenience script
- **Reason**: Proper installation method, more control, aligns with minimal philosophy
- **File**: `Dockerfile:57-65`

### Why Python 3.11?
- **Decision**: Use Python 3.11 from deadsnakes PPA
- **Reason**: `open-webui` package requires Python 3.11+, Ubuntu 22.04 ships with 3.10
- **File**: `Dockerfile:38-55`

### Why No /etc/hosts Blocklist? (v1.2.0 — reverses the v1.0.x decision)
- **Decision**: Delete `scripts/privacy/setup-blocklist.sh`, its validation step, the
  "N domains blocked" banner and the `PRIVACY_MODE` switch. Privacy is now entirely
  environment variables
- **Reason**: `/etc/hosts` is an exact-hostname match. Every real telemetry endpoint is a
  subdomain — `us.i.posthog.com` (Chroma), `oNNN.ingest.sentry.io`, `api.segment.io`,
  `www.google-analytics.com` — so `0.0.0.0 posthog.com` blocked none of them. The three
  Ollama entries were the wrong domain: Ollama moved to `ollama.com` in 2024, and the Linux
  `ollama serve` binary has no update check at all (the updater lives in `app/updater/`,
  desktop only). Cloud inference and web search go to `ollama.com` and are stopped by
  `OLLAMA_NO_CLOUD=1`, not by DNS
- **Validation was circular**: it checked that the bare domains it had just written resolved
  to 0.0.0.0, which said nothing about the endpoints actually contacted
- **Alternatives considered**: enumerating real subdomains (fragile, still a guess), or a
  local wildcard resolver such as dnsmasq (a second service, against the one-container
  premise). Neither beats "be honest that env vars are the control"
- **History**: the v1.0.x rationale was "iptables cannot filter by domain, so use
  /etc/hosts". The first half was right; the second half did not work either

### Why No Container SSH?
- **Decision**: Don't install SSH server, remove port 22 from container
- **Reason**: RunPod provides host-level SSH automatically, container SSH is redundant
- **Impact**: Removed from docker-compose.yml, template.sh, and README
- **File**: Multiple

### Why OLLAMA_NO_CLOUD=1?
- **Decision**: Set `OLLAMA_NO_CLOUD=1` explicitly in the Dockerfile Ollama ENV block
- **Reason**: Ollama added phone-home behavior (update checks) that has no simple opt-out until this env var was introduced. Don't rely on upstream defaults — they can change.
- **Important**: This disables Ollama's cloud features; it does NOT replace egress-level network control. Initial model pulls still require network access unless models are preloaded.
- **File**: `Dockerfile:15-18`

### Why Explicit Open WebUI Telemetry-Off Vars?
- **Decision**: Set `SCARF_NO_ANALYTICS=true`, `DO_NOT_TRACK=true`, `ANONYMIZED_TELEMETRY=false` explicitly; also `AUDIT_LOG_LEVEL=NONE` and `ENABLE_AUDIT_LOGS_FILE=false`
- **Reason**: Open WebUI's upstream Chromadb dependency sends PostHog telemetry by default. Official Dockerfile sets these vars — Sanctum should too, not rely on inherited defaults (fragile).
- **Audit logs**: Disabled to prevent Open WebUI from writing audit data to `/workspace/data` (mounted persistent volume).
- **File**: `Dockerfile:21-29`

### Why Ollama Domains in Blocklist? (v1.0.5 — superseded in v1.2.0)
- Added `ollama.ai`, `updates.ollama.ai`, `telemetry.ollama.ai` as a "backstop" to
  `OLLAMA_NO_CLOUD=1`. Review in v1.2.0 found the domain was wrong (`ollama.com`) and two
  of the three hostnames have no evidence of ever existing. Removed with the blocklist;
  see "Why No /etc/hosts Blocklist?"

### Why Pinned Ollama Version?
- **Decision**: Pin Ollama to specific version (v0.32.14), not dynamic "latest"
- **Reason**: Reproducible builds, simple to understand, no API rate limits or failures
- **Philosophy**: Aligns with "simple, functional, elegant" - one-line version updates
- **Maintenance**: Review quarterly or when important updates announced
- **Current**: v0.32.14 (updated 2026-08-19)
- **File**: `Dockerfile:60`

### Why `.tar.zst` for the Ollama Download?
- **Decision**: Extract Ollama from `ollama-linux-amd64.tar.zst` with `tar --zstd`, and add `zstd` to the apt list
- **Reason**: Upstream stopped publishing `ollama-linux-amd64.tgz` for current releases — the official `install.sh` now downloads `.tar.zst` and errors out if `zstd` is missing. A plain `OLLAMA_VERSION` bump would have 404'd
- **Layout**: Unchanged — extracting to `/usr` still yields `/usr/bin/ollama` and `/usr/lib/ollama`. A `test -x /usr/bin/ollama` guards the build against a future layout change
- **File**: `Dockerfile:57-65`

### Why CPU-Only PyTorch?
- **Decision**: Install `torch` from the PyTorch CPU index *before* `open-webui`, in the same `RUN` layer
- **Reason**: `open-webui` → `sentence-transformers` → `torch` pulls the CUDA build plus `nvidia-*` wheels, roughly 4.5GB. Ollama does all inference and ships its own CUDA runtime in its release tarball, so those wheels were never used
- **Why it works**: `sentence-transformers` only requires `torch>=1.11.0` (no exact pin anywhere in the dependency tree), so pip treats the pre-installed CPU build as satisfying the requirement
- **Trade-off, stated honestly**: local RAG embeddings and Whisper transcription now run on CPU. Users who want GPU embeddings set `RAG_EMBEDDING_ENGINE=ollama` and pull an embedding model — documented in the README
- **Guard**: the build asserts `torch.__version__` ends in `+cpu`, so a future dependency change that drags CUDA torch back in fails the build instead of silently shipping a 7GB image
- **File**: `Dockerfile:69-75`

### Why `wait -n` Instead of `tail -f /dev/null`?
- **Decision**: Supervise both children with `wait -n`, and trap `SIGTERM`/`SIGINT` to shut them down
- **Reason**: `tail -f /dev/null` kept PID 1 alive no matter what. If Ollama or Open WebUI crashed, the pod stayed "running" with a dead service — Docker's `HEALTHCHECK` records this but RunPod does not act on it, so the failure was invisible until someone opened the UI
- **Behaviour**: either service exiting now prints the tail of both logs and exits 1, so the pod visibly stops
- **Not a supervisor**: there is deliberately no restart loop. Sanctum's premise is one container, no supervision framework — a crash should surface, not be papered over
- **File**: `scripts/startup.sh:176-210`

### Why Is the Version a Build ARG?
- **Decision**: `ARG SANCTUM_VERSION` → `ENV SANCTUM_VERSION`, stamped by CI from `github.ref_name`, printed by the startup banner
- **Reason**: the banner was a hardcoded string and had already drifted (said v1.0.5 while the repo was tagged v1.0.6). One source of truth, no release-checklist step to forget
- **File**: `Dockerfile:35-36`, `.github/workflows/build-and-push.yml`

## Build History

### Build Failures and Fixes

1. **Ollama Download 404** (Build #2)
   - Error: URL `https://ollama.com/download/ollama-linux-amd64` returned 404
   - Fix: Switched to official install script (temporary)
   - Final Fix: Manual binary from GitHub releases v0.5.4

2. **Python Package Not Found** (Build #3)
   - Error: `open-webui` package not found
   - Fix: Installed Python 3.11 from deadsnakes PPA

3. **GPG Configuration Error** (Build #4)
   - Error: `gpg-agent` not found when adding PPA
   - Fix: Added `gnupg` package before `add-apt-repository`

4. **Python Wheel Build Failures** (Build #5)
   - Error: `peewee` and `pypika` failed to build wheels
   - Fix: Added `build-essential` and `python3.11-dev` packages

5. **Setuptools Compatibility** (Build #6)
   - Error: `AttributeError: install_layout` when building wheels
   - Fix: Upgrade pip, setuptools, and wheel before installing open-webui
   - **Result**: Build succeeded! ✅

### Dependency Chain Learned
```
Ubuntu 22.04 base
  → software-properties-common (for add-apt-repository)
  → gnupg (for PPA key import)
  → deadsnakes/ppa (for Python 3.11)
  → python3.11 + python3.11-dev + python3.11-venv
  → build-essential (gcc, make, etc.)
  → pip3 upgrade (pip, setuptools, wheel)
  → open-webui (finally installs!)
```

## Feedback Iterations

### Initial Feedback (User Review)
1. ✅ Ollama: Switch from convenience script to proper binary installation
2. ✅ Privacy: Removed network isolation script (iptables can't filter domains)
3. ✅ SSH: Removed port 22 exposure (no SSH server installed)
4. ✅ GitHub Actions: Added step ID for digest output
5. ✅ License: Added MIT LICENSE file

### Second Feedback (Post-Build)
1. **Privacy Confusion**: `ALLOWED_DOMAINS` still referenced but doesn't work → Remove
2. **SSH Confusion**: Port 22 in compose/template but no server → Remove
3. **Missing Tools**: `free` command not found, optional Python modules missing → Add procps
4. **GitHub Actions**: Missing disk cleanup like Ignition has → Add cleanup steps
5. **Versioning**: Need proper git tags (v1.0.0, v1.0.1, etc.) → Implement tagging

## Current State

### What's Working ✅
- Docker builds successfully (Build #6)
- Ollama installs via manual tarball extraction
- Open WebUI installs with Python 3.11
- Telemetry off via environment variables (the /etc/hosts blocklist was removed in v1.2.0)
- Health checks with proper timeouts
- GitHub Actions auto-builds on push

### What's Deployed 🚀
- Docker Hub: `heapsgo0d/sanctum:latest` (v1.1.0)
- GitHub: `https://github.com/HeapsGo0d/sanctum`
- Repository: Public, MIT licensed

### Known Issues 🐛
- None outstanding. All v1.0.x issues resolved; see the v1.1.0 section below

## File Structure

```
sanctum/
├── CONTEXT.md                              # This file (project continuity)
├── Dockerfile                              # Container definition
├── README.md                               # User documentation
├── LICENSE                                 # MIT License
├── docker-compose.yml                      # Local testing
├── template.sh                             # RunPod template generator
├── sanctum_template.json                  # Generated by template.sh (gitignored, untracked)
├── .github/workflows/build-and-push.yml   # CI/CD pipeline
└── scripts/
    ├── startup.sh                          # Main entrypoint
    └── health-check.sh                    # Service verification
```

## Lessons Learned

### Technical
1. **iptables can't filter by domain** - Only IPs, making allowlists impractical
2. **Python packaging is fragile** - Need exact dependency chain for wheels to build
3. **RunPod provides SSH** - No need for container-level SSH server
4. **setuptools compatibility** - Always upgrade pip/setuptools/wheel first
5. **/etc/hosts is simple but does not work for this** - exact-match only; telemetry
   lives on subdomains. Settings are the control (learned v1.2.0, after shipping it for a year)

### Process
1. **Be honest about limitations** - Users appreciate transparency
2. **Minimal is better** - Fewer services = faster startup, easier debugging
3. **Test the build** - Each fix taught us something about dependencies
4. **Document decisions** - This file exists because context matters

## Completed (v1.1.0) ✅

### Session 2026-08-19 - Review, Dependency Update, Release

Full code review after six idle months, then the updates it turned up.

**Updates**
- [x] Ollama v0.12.10 → v0.32.14, including the `.tgz` → `.tar.zst` asset-format change
- [x] Open WebUI rebuilt against latest PyPI (0.11.0 — full UI redesign). Deliberately left unpinned
- [x] CPU-only PyTorch — drops the unused CUDA wheels from the image

**Fixes found by review**
- [x] `tail -f /dev/null` → `wait -n` supervision + signal trap (a crashed service left a zombie pod)
- [x] Health check and startup probe now hit `/health`, not `/` (the SPA shell can 200 with a dead backend)
- [x] Open WebUI readiness budget 30s → 120s (first boot runs DB migrations)
- [x] Startup banner version now comes from a build ARG (was hardcoded, had drifted to v1.0.5)
- [x] Dropped the hardcoded "22 domains blocked" string — `setup-blocklist.sh` already prints the real count
- [x] Removed `iptables`, `iproute2`, `net-tools` — dead since the v1.0.1 network-isolation removal, and they implied a filtering capability Sanctum doesn't have
- [x] `pip3` → `python3.11 -m pip` (explicit interpreter, not dependent on update-alternatives ordering)
- [x] `docker-compose.yml`: dropped the obsolete `version:` key and the partial env duplication that had already drifted from the Dockerfile

**template.sh**
- [x] REST API (`POST https://rest.runpod.io/v1/templates`) with the legacy GraphQL mutation as fallback
- [x] ignition-style argument parsing: `--deploy`/`-d`, `--yes`/`-y`, bare `v*` version

**Privacy**: unchanged. All 22 blocklist domains, IPv4+IPv6 entries, validation, and every
telemetry-off env var carried over untouched.

**Checked, no action needed**: the CI `latest` tag does publish on tag pushes (Docker Hub
shows `latest` and `v1.0.6` written in the same second); `AUDIT_LOG_LEVEL` and
`ENABLE_AUDIT_LOGS_FILE` still exist in Open WebUI 0.11.0's `env.py`; Python 3.11 still
satisfies its `>=3.11,<3.13` requirement.

## Completed (v1.0.5) ✅

### Session 2026-02-24 - Privacy Hardening (Option A+)
- [x] Add `OLLAMA_NO_CLOUD=1` to Dockerfile Ollama ENV block
- [x] Add Open WebUI telemetry-off vars (`SCARF_NO_ANALYTICS`, `DO_NOT_TRACK`, `ANONYMIZED_TELEMETRY`, `AUDIT_LOG_LEVEL`, `ENABLE_AUDIT_LOGS_FILE`) to Dockerfile
- [x] Add Ollama cloud domains to blocklist (`ollama.ai`, `updates.ollama.ai`, `telemetry.ollama.ai`)
- [x] Update `print_config()` to surface Ollama cloud status and corrected domain count (22)
- [x] Update `print_success()` privacy status block with Ollama cloud line
- [x] Document all three privacy decisions as architecture decisions in CONTEXT.md

**Issue**: Sanctum relied on upstream defaults for Ollama/Open WebUI privacy settings — fragile and undocumented
**Fix**: Explicit env vars + belt-and-suspenders blocklist entries; all decisions documented with rationale and acknowledged limitations

## Completed (v1.0.4) ✅

### Session 2025-11-10 - Blocklist Validation Fix
- [x] Fix blocklist validation to accept IPv6 null addresses (:: and ::0)
- [x] Update validation logic to recognize both IPv4 (0.0.0.0) and IPv6 (::) as valid blocked states
- [x] Improve validation messages to show actual resolved address

**Issue**: Validation script incorrectly warned domains weren't blocked when they resolved to IPv6 null (::) instead of IPv4 null (0.0.0.0)
**Fix**: Accept both address types as valid - blocking works correctly with either

## Completed (v1.0.3) ✅

### Session 2025-11-10 - Ollama Version Update
- [x] Update Ollama from v0.5.4 to v0.12.10 (8 minor versions, ~1 year of improvements)
- [x] Add ARG-based version pinning to Dockerfile (reproducible builds)
- [x] Document versioning approach in CONTEXT.md (simple, quarterly review schedule)
- [x] Add comment for quarterly version review

**Changes**: Dockerfile ARG approach, CONTEXT.md architecture decision
**Benefits**: Latest embeddings, vision models, CPU performance fixes, new model support

## Completed (v1.0.2) ✅

### Session 2025-11-10 - Polish & UX Improvements
- [x] Remove psutil/httpx mention from CONTEXT.md (documentation accuracy)
- [x] Add blocked domain count to startup log (shows "20 domains blocked")
- [x] Add model download helper message (guides first-time users)
- [x] Improve blocklist validation (uses getent instead of curl for clarity)

**Changes**: 4 files, +25/-11 lines - all polish improvements aligned with "simple, functional, elegant"

## Completed (v1.0.1) ✅

### Session 2025-11-08
- [x] Create CONTEXT.md
- [x] Remove ALLOWED_DOMAINS references (Dockerfile, startup.sh, template.sh, docker-compose.yml)
- [x] Remove SSH port 22 confusion (docker-compose.yml, template.sh, README.md)
- [x] Add procps package to Dockerfile
- [x] Update GitHub Actions (disk cleanup, tag-based triggers, old tag cleanup)
- [x] Tag v1.0.1 and trigger versioned build (commit e0aa889, tag pushed)
- [x] Add privacy validation to blocklist script (tests 3 sample domains)

**Build Status**: Completed (Build #7, triggered by v1.0.1 tag)

## Next Steps (Future)

### Future Considerations
- Monitor Docker Hub for "unrecognized" status (likely transient)
- Test on actual RunPod with GPU
- Gather user feedback on privacy approach

## References

- **Original Inspiration**: Ignition (ComfyUI template) - `/home/nathan/dev/ignition`
- **Docker Image**: https://hub.docker.com/r/heapsgo0d/sanctum
- **GitHub Repo**: https://github.com/HeapsGo0d/sanctum
- **Ollama Releases**: https://github.com/ollama/ollama/releases
- **Open WebUI**: https://github.com/open-webui/open-webui

---

**Philosophy Reminder**: Simple, functional, elegant. Only promise what we deliver.

# Sanctum - Project Context

**Last Updated**: 2026-02-24
**Current Version**: v1.0.5
**Status**: Active Development

## Project Philosophy

**"Simple, Functional, Elegant"**

Sanctum is designed to be the minimal, honest alternative to complex AI hosting templates. Core principles:

- **Only implement what actually works** - No aspirational features that don't deliver
- **Be honest about limitations** - Clear documentation about what we do/don't provide
- **Minimal complexity** - 8 core files, no supervisor loops, no unnecessary services
- **Fast startup** - Health checks with timeouts, no auto-downloads
- **Privacy-first** - Block telemetry where possible, be transparent about scope

## Architecture Decisions

### Why Manual Ollama Installation?
- **Decision**: Install Ollama via GitHub release tarball, not convenience script
- **Reason**: Proper installation method, more control, aligns with minimal philosophy
- **File**: `Dockerfile:48-52`

### Why Python 3.11?
- **Decision**: Use Python 3.11 from deadsnakes PPA
- **Reason**: `open-webui` package requires Python 3.11+, Ubuntu 22.04 ships with 3.10
- **File**: `Dockerfile:35-46`

### Why /etc/hosts Only for Privacy?
- **Decision**: Use `/etc/hosts` blocking for telemetry, NOT iptables network isolation
- **Reason**: iptables cannot filter by domain names (only IPs), allowlist doesn't work
- **Impact**: Removed `setup-network-isolation.sh`, removed `ALLOWED_DOMAINS` variable
- **Honesty**: README clearly states "blocks telemetry domains" not "full network isolation"
- **File**: `scripts/privacy/setup-blocklist.sh`

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
- **File**: `Dockerfile:20-27`

### Why Ollama Domains in Blocklist?
- **Decision**: Add `ollama.ai`, `updates.ollama.ai`, `telemetry.ollama.ai` to the `/etc/hosts` blocklist
- **Reason**: Belt-and-suspenders. `OLLAMA_NO_CLOUD=1` is the primary control; `/etc/hosts` is the network-level backstop — consistent with Sanctum's existing privacy philosophy.
- **Acknowledged limitation**: Domains are best-effort. If Ollama changes endpoints, this list won't catch new ones. The env var is more reliable.
- **File**: `scripts/privacy/setup-blocklist.sh:47-49`

### Why Pinned Ollama Version?
- **Decision**: Pin Ollama to specific version (v0.12.10), not dynamic "latest"
- **Reason**: Reproducible builds, simple to understand, no API rate limits or failures
- **Philosophy**: Aligns with "simple, functional, elegant" - one-line version updates
- **Maintenance**: Review quarterly or when important updates announced
- **Current**: v0.12.10 (updated 2025-11-10)
- **File**: `Dockerfile:50`

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
- /etc/hosts telemetry blocking works
- Health checks with proper timeouts
- GitHub Actions auto-builds on push

### What's Deployed 🚀
- Docker Hub: `heapsgo0d/sanctum:latest` (v1.0.0)
- GitHub: `https://github.com/HeapsGo0d/sanctum`
- Repository: Public, MIT licensed

### Known Issues 🐛
- `ALLOWED_DOMAINS` referenced but doesn't do anything (v1.0.1 will fix)
- Port 22 exposed but unused (v1.0.1 will fix)
- No git version tags yet (v1.0.1 will add)
- GitHub Actions builds on every push, should be tag-based (v1.0.1 will fix)

## File Structure

```
sanctum/
├── CONTEXT.md                              # This file (project continuity)
├── Dockerfile                              # Container definition
├── README.md                               # User documentation
├── LICENSE                                 # MIT License
├── docker-compose.yml                      # Local testing
├── template.sh                             # RunPod template generator
├── sanctum_template.json                  # Generated template (gitignored)
├── .github/workflows/build-and-push.yml   # CI/CD pipeline
└── scripts/
    ├── startup.sh                          # Main entrypoint
    ├── health-check.sh                    # Service verification
    └── privacy/
        └── setup-blocklist.sh              # /etc/hosts blocking
```

## Lessons Learned

### Technical
1. **iptables can't filter by domain** - Only IPs, making allowlists impractical
2. **Python packaging is fragile** - Need exact dependency chain for wheels to build
3. **RunPod provides SSH** - No need for container-level SSH server
4. **setuptools compatibility** - Always upgrade pip/setuptools/wheel first
5. **/etc/hosts is simple and works** - Better than complex networking that doesn't

### Process
1. **Be honest about limitations** - Users appreciate transparency
2. **Minimal is better** - Fewer services = faster startup, easier debugging
3. **Test the build** - Each fix taught us something about dependencies
4. **Document decisions** - This file exists because context matters

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

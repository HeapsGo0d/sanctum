#!/bin/bash
# Sanctum RunPod Template Creator
# Generates RunPod template configuration for Sanctum, and optionally creates
# it directly via the RunPod API.
#
#   ./template.sh                      # generate sanctum_template.json only
#   ./template.sh --deploy             # prompt, then create the template
#   ./template.sh -y v1.1.0 --deploy   # non-interactive, uses defaults

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
DOCKER_IMAGE="heapsgo0d/sanctum:latest"
TEMPLATE_NAME="Sanctum Latest"
TEMPLATE_DESCRIPTION="Minimal, privacy-first Ollama + Open WebUI for RunPod. Login on, telemetry off, no outbound features. Fast startup, clean architecture."

# Disk defaults (can be overridden interactively or via env)
CONTAINER_DISK_GB="${CONTAINER_DISK_GB:-50}"
VOLUME_GB="${VOLUME_GB:-20}"

# RunPod API endpoints
RUNPOD_REST_URL="https://rest.runpod.io/v1/templates"
RUNPOD_GRAPHQL_URL="https://api.runpod.io/graphql"

# Parse command line arguments
DEPLOY_MODE="local"
YES_MODE=false
VERSION_ARG=""

for arg in "$@"; do
    case "$arg" in
        --deploy|-d) DEPLOY_MODE="api" ;;
        --yes|-y)    YES_MODE=true ;;
        v*)          VERSION_ARG="$arg" ;;
    esac
done

# Print banner
print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════╗"
    echo "║          🔒 SANCTUM TEMPLATE             ║"
    echo "║       RunPod Template Creator v1.1        ║"
    echo "╚═══════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Print usage information
print_usage() {
    echo -e "${YELLOW}📋 Sanctum RunPod Template Creator${NC}"
    echo ""

    if [[ "$DEPLOY_MODE" == "api" ]]; then
        echo -e "${GREEN}🚀 API Deployment Mode${NC} - Will create template directly in RunPod"
        echo -e "${BLUE}Requirements:${NC}"
        echo "  • RunPod API key (set RUNPOD_API_KEY environment variable)"
        echo "  • curl command available"
        echo ""
    else
        echo -e "${BLUE}📁 Local File Mode${NC} - Will generate files for manual upload"
        echo -e "${YELLOW}💡 Tips:${NC}"
        echo "  • './template.sh --deploy' for automatic RunPod deployment"
        echo "  • './template.sh -y v1.1.0 --deploy' to skip all prompts"
        echo ""
    fi

    echo -e "${GREEN}Template includes:${NC}"
    echo "  ✅ Ollama + Open WebUI"
    echo "  ✅ Privacy-first: login required, telemetry off, outbound features disabled"
    echo "  ✅ GPU support enabled"
    echo "  ✅ Persistent storage for models and data"
    echo ""
}

# Check API key if in deploy mode
check_api_requirements() {
    if [[ "$DEPLOY_MODE" == "api" ]]; then
        if [[ -z "${RUNPOD_API_KEY:-}" ]]; then
            echo -e "${RED}❌ Error: RUNPOD_API_KEY environment variable not set${NC}"
            echo ""
            echo -e "${YELLOW}To use API deployment mode:${NC}"
            echo "1. Get your API key from RunPod → Settings → API Keys"
            echo "2. Export it: export RUNPOD_API_KEY=\"your_key_here\""
            echo "3. Run the script again: ./template.sh --deploy"
            echo ""
            echo -e "${BLUE}Or use local file mode: ./template.sh${NC}"
            exit 1
        fi

        # curl must exist
        if ! command -v curl &> /dev/null; then
            echo -e "${RED}❌ Error: curl command not found${NC}"
            echo "Please install curl to use API deployment mode"
            exit 1
        fi

        # jq is optional
        if ! command -v jq &> /dev/null; then
            echo -e "${YELLOW}⚠️  jq not found — will show raw JSON and use a basic parser fallback${NC}"
        else
            echo -e "${GREEN}✅ jq detected — pretty JSON parsing enabled${NC}"
        fi

        echo -e "${GREEN}✅ API key found, deployment mode ready${NC}"
        echo ""
    fi
}

# Derive image and template name from the version tag
set_names_from_version() {
    if [[ "$VERSION_TAG" == "latest" ]]; then
        DOCKER_IMAGE="heapsgo0d/sanctum:latest"
        TEMPLATE_NAME="Sanctum Latest"
    else
        DOCKER_IMAGE="heapsgo0d/sanctum:$VERSION_TAG"
        TEMPLATE_NAME="Sanctum $VERSION_TAG"
    fi
}

# Get user input for configuration
get_configuration() {
    echo -e "${YELLOW}🔧 Configuration Setup${NC}"
    echo ""

    if [[ "$YES_MODE" == true ]]; then
        VERSION_TAG="${VERSION_ARG:-latest}"
        set_names_from_version
        echo "  → Docker Image: $DOCKER_IMAGE"
        echo "  → Container Disk: ${CONTAINER_DISK_GB}GB, Volume: ${VOLUME_GB}GB"
        echo ""
        return
    fi

    # Version input
    echo -e "${BLUE}Version:${NC}"
    read -p "Enter version tag (e.g., v1.1.0) [${VERSION_ARG:-latest}]: " version_input
    VERSION_TAG=${version_input:-${VERSION_ARG:-latest}}
    set_names_from_version

    echo "  → Docker Image: $DOCKER_IMAGE"
    echo "  → Template Name: $TEMPLATE_NAME"
    echo ""

    # Disk settings
    echo -e "${BLUE}Disk Settings:${NC}"
    read -p "Container disk size in GB [${CONTAINER_DISK_GB}]: " tmp_disk
    CONTAINER_DISK_GB=${tmp_disk:-$CONTAINER_DISK_GB}
    read -p "Default volume size in GB [${VOLUME_GB}]: " tmp_vol
    VOLUME_GB=${tmp_vol:-$VOLUME_GB}
    echo ""
}

# Readme body, shared by both API paths (JSON string, escaped newlines)
make_readme() {
    printf '%s' "# $TEMPLATE_NAME\\n\\n$TEMPLATE_DESCRIPTION\\n\\n## Features\\n- Login required (WEBUI_AUTH=True); set WEBUI_ADMIN_EMAIL/PASSWORD before first boot\\n- Ollama cloud/update checks disabled (OLLAMA_NO_CLOUD=1)\\n- Open WebUI telemetry disabled\\n- Minimal architecture: fast startup, clean design\\n- Persistent storage for models and data\\n\\n## Storage\\n- Container: ${CONTAINER_DISK_GB}GB\\n- Volume: ${VOLUME_GB}GB mounted at /workspace\\n\\n## Access\\n- Open WebUI: https://[pod-id]-8080.proxy.runpod.net\\n- SSH: RunPod provides host-level SSH automatically\\n\\n## First Run\\nNo models ship in the image. Pull one from the WebUI\\n(Settings → Models) or run: ollama pull llama3.2:1b"
}

# Generate template JSON (manual upload option; schema differs from the API)
generate_template() {
    cat > sanctum_template.json << EOF
{
  "name": "$TEMPLATE_NAME",
  "description": "$TEMPLATE_DESCRIPTION",
  "dockerImage": "$DOCKER_IMAGE",
  "ports": [
    {
      "privatePort": 8080,
      "publicPort": 8080,
      "type": "http",
      "description": "Open WebUI"
    }
  ],
  "volumeMounts": [
    {
      "containerPath": "/workspace",
      "name": "workspace"
    }
  ],
  "environmentVariables": [
    {
      "key": "OLLAMA_HOST",
      "value": "0.0.0.0",
      "description": "Ollama server bind address"
    },
    {
      "key": "OLLAMA_MODELS",
      "value": "/workspace/models",
      "description": "Ollama models directory"
    },
    {
      "key": "DATA_DIR",
      "value": "/workspace/data",
      "description": "Open WebUI data directory"
    },
    {
      "key": "WEBUI_AUTH",
      "value": "True",
      "description": "Open WebUI login (True). Do not disable on a proxied pod"
    },
    {
      "key": "WEBUI_ADMIN_EMAIL",
      "value": "",
      "description": "Set before first boot to pre-create the admin (avoids the first-visitor-becomes-admin race)"
    },
    {
      "key": "WEBUI_ADMIN_PASSWORD",
      "value": "",
      "description": "Password for WEBUI_ADMIN_EMAIL; only used when no users exist yet"
    },
    {
      "key": "WEBUI_PORT",
      "value": "8080",
      "description": "Open WebUI port"
    },
    {
      "key": "RESET_CONFIG_ON_START",
      "value": "false",
      "description": "Set true for ONE boot to re-seed Open WebUI settings from these variables, then set back to false"
    }
  ],
  "startScript": "/scripts/startup.sh"
}
EOF
}

# Print template summary
print_summary() {
    echo -e "${GREEN}📋 Template Configuration Summary:${NC}"
    echo ""
    echo -e "${BLUE}Template Details:${NC}"
    echo "  Name: $TEMPLATE_NAME"
    echo "  Docker Image: $DOCKER_IMAGE"
    echo "  Container Disk: ${CONTAINER_DISK_GB}GB"
    echo "  Volume Size: ${VOLUME_GB}GB"
    echo ""
    echo -e "${BLUE}Access:${NC}"
    echo "  Open WebUI: https://[pod-id]-8080.proxy.runpod.net"
    echo "  SSH: RunPod provides host-level SSH (see RunPod console)"
    echo ""
}

# Pull "id" and "name" out of an API response
parse_template_id() {
    local response="$1" path="$2"
    if $HAS_JQ; then
        echo "$response" | jq -r "$path // empty"
    else
        echo "$response" | grep -o '"id":"[^"]*' | head -n1 | cut -d'"' -f4
    fi
}

# Deploy via the current REST API. Returns 0 on success.
deploy_rest() {
    echo -e "${BLUE}Trying REST API (${RUNPOD_REST_URL})...${NC}"

    local payload
    payload=$(cat << EOF
{
  "name": "$TEMPLATE_NAME",
  "imageName": "$DOCKER_IMAGE",
  "containerDiskInGb": $CONTAINER_DISK_GB,
  "volumeInGb": $VOLUME_GB,
  "volumeMountPath": "/workspace",
  "ports": ["8080/http"],
  "category": "NVIDIA",
  "isPublic": false,
  "isServerless": false,
  "readme": "$(make_readme)",
  "env": {
    "OLLAMA_HOST": "0.0.0.0",
    "OLLAMA_MODELS": "/workspace/models",
    "DATA_DIR": "/workspace/data",
    "WEBUI_AUTH": "True",
    "WEBUI_ADMIN_EMAIL": "",
    "WEBUI_ADMIN_PASSWORD": "",
    "WEBUI_PORT": "8080",
    "RESET_CONFIG_ON_START": "false"
  }
}
EOF
)

    local raw http_code body
    raw=$(curl -s -w '\n%{http_code}' -X POST "$RUNPOD_REST_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $RUNPOD_API_KEY" \
        -d "$payload")
    http_code=$(echo "$raw" | tail -n1)
    body=$(echo "$raw" | sed '$d')

    if [[ "$http_code" != "200" && "$http_code" != "201" ]]; then
        echo -e "${YELLOW}⚠️  REST API returned HTTP $http_code${NC}"
        echo -e "${YELLOW}   Response:${NC} $(echo "$body" | head -c 400)"
        return 1
    fi

    TEMPLATE_ID=$(parse_template_id "$body" '.id')
    if [[ -z "$TEMPLATE_ID" || "$TEMPLATE_ID" == "null" ]]; then
        echo -e "${YELLOW}⚠️  REST API returned HTTP $http_code but no template id${NC}"
        echo -e "${YELLOW}   Response:${NC} $(echo "$body" | head -c 400)"
        return 1
    fi

    DEPLOY_VIA="REST v1"
    return 0
}

# Deploy via the legacy GraphQL mutation. Returns 0 on success.
deploy_graphql() {
    echo -e "${BLUE}Trying legacy GraphQL API (${RUNPOD_GRAPHQL_URL})...${NC}"

    local api_payload
    api_payload=$(cat << EOF
{
  "name": "$TEMPLATE_NAME",
  "imageName": "$DOCKER_IMAGE",
  "containerDiskInGb": $CONTAINER_DISK_GB,
  "volumeInGb": $VOLUME_GB,
  "volumeMountPath": "/workspace",
  "dockerArgs": "",
  "ports": "8080/http",
  "readme": "$(make_readme)",
  "env": [
    {"key": "OLLAMA_HOST", "value": "0.0.0.0"},
    {"key": "OLLAMA_MODELS", "value": "/workspace/models"},
    {"key": "DATA_DIR", "value": "/workspace/data"},
    {"key": "WEBUI_AUTH", "value": "True"},
    {"key": "WEBUI_ADMIN_EMAIL", "value": ""},
    {"key": "WEBUI_ADMIN_PASSWORD", "value": ""},
    {"key": "WEBUI_PORT", "value": "8080"},
    {"key": "RESET_CONFIG_ON_START", "value": "false"}
  ]
}
EOF
)

    local response
    response=$(curl -s -X POST "$RUNPOD_GRAPHQL_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $RUNPOD_API_KEY" \
        -d "$(cat << EOF
{
  "query": "mutation saveTemplate(\$input: SaveTemplateInput!) { saveTemplate(input: \$input) { id name imageName } }",
  "variables": {
    "input": $api_payload
  }
}
EOF
)")

    # Non-JSON response (e.g. "Internal Server Error") - report it as-is
    if ! echo "$response" | grep -q '^{'; then
        echo -e "${RED}❌ GraphQL API returned non-JSON response:${NC} $(echo "$response" | head -c 400)"
        return 1
    fi

    if echo "$response" | grep -q '"errors"'; then
        echo -e "${RED}❌ GraphQL API Error:${NC}"
        if $HAS_JQ; then
            echo "$response" | jq -r '.errors[0].message'
        else
            echo "$response" | head -c 400
        fi
        return 1
    fi

    TEMPLATE_ID=$(parse_template_id "$response" '.data.saveTemplate.id')
    if [[ -z "$TEMPLATE_ID" || "$TEMPLATE_ID" == "null" ]]; then
        echo -e "${RED}❌ GraphQL response contained no template id${NC}"
        echo -e "${YELLOW}Response:${NC} $(echo "$response" | head -c 400)"
        return 1
    fi

    DEPLOY_VIA="GraphQL (legacy)"
    return 0
}

# Deploy template to RunPod: REST first, GraphQL as fallback
deploy_template() {
    echo -e "${YELLOW}🚀 Deploying template to RunPod...${NC}"

    HAS_JQ=true
    command -v jq &>/dev/null || HAS_JQ=false

    if deploy_rest || { echo -e "${YELLOW}↩️  Falling back to the legacy GraphQL API...${NC}"; deploy_graphql; }; then
        echo -e "${GREEN}✅ Template created successfully via ${DEPLOY_VIA}!${NC}"
        echo -e "${BLUE}Template ID:${NC} $TEMPLATE_ID"
        echo -e "${BLUE}Template Name:${NC} $TEMPLATE_NAME"
        echo -e "${BLUE}RunPod Console:${NC} https://runpod.io/console/user/templates"
        return 0
    fi

    echo -e "${RED}❌ Both API paths failed${NC}"
    return 1
}

# Main execution
main() {
    print_banner
    print_usage

    check_api_requirements

    if [[ "$YES_MODE" != true ]]; then
        echo -e "${YELLOW}Press Enter to continue with template creation...${NC}"
        read
    fi

    get_configuration

    echo -e "${YELLOW}🔨 Generating template files...${NC}"
    generate_template
    print_summary

    if [[ "$DEPLOY_MODE" == "api" ]]; then
        if deploy_template; then
            echo ""
            echo -e "${YELLOW}Next Steps:${NC}"
            echo "  1. Go to RunPod Console → Templates"
            echo "  2. Find '$TEMPLATE_NAME'"
            echo "  3. Deploy a pod with GPU"
            echo "  4. Access Open WebUI at https://[pod-id]-8080.proxy.runpod.net"
        else
            echo ""
            echo -e "${YELLOW}⚠️  API deployment failed, but the local file was created${NC}"
            echo -e "${BLUE}Upload sanctum_template.json manually${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✅ Template file created successfully!${NC}"
        echo ""
        echo -e "${BLUE}Generated File:${NC}"
        echo "  📄 sanctum_template.json - RunPod template definition"
        echo ""
        echo -e "${YELLOW}Next Steps:${NC}"
        echo "  1. Upload sanctum_template.json to RunPod Templates"
        echo "  2. Deploy a pod using your template"
        echo "  3. Access Open WebUI at https://[pod-id]-8080.proxy.runpod.net"
        echo ""
        echo -e "${BLUE}💡 Tip: Use './template.sh --deploy' for automatic deployment${NC}"
    fi

    echo ""
    echo -e "${GREEN}🔒 Sanctum - Privacy-focused AI on RunPod${NC}"
}

main "$@"

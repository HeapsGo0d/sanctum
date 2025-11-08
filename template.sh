#!/bin/bash
# Sanctum RunPod Template Creator
# Generates RunPod template configuration for Sanctum

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
TEMPLATE_NAME="Sanctum - Privacy-Focused Ollama + Open WebUI"
TEMPLATE_DESCRIPTION="Minimal, privacy-first Ollama + Open WebUI for RunPod. Telemetry blocking, fast startup, clean architecture."

# Disk defaults (can be overridden interactively or via env)
CONTAINER_DISK_GB="${CONTAINER_DISK_GB:-50}"
VOLUME_GB="${VOLUME_GB:-20}"

# Check for command line arguments
DEPLOY_MODE="local"  # Default to local file generation
if [[ "$1" == "--deploy" || "$1" == "-d" ]]; then
    DEPLOY_MODE="api"
fi

# Print banner
print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════╗"
    echo "║          🔒 SANCTUM TEMPLATE             ║"
    echo "║       RunPod Template Creator v1.0        ║"
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
        echo -e "${YELLOW}💡 Tip: Use './template.sh --deploy' for automatic deployment${NC}"
        echo ""
    fi

    echo -e "${GREEN}Template includes:${NC}"
    echo "  ✅ Ollama + Open WebUI"
    echo "  ✅ Privacy-first: telemetry blocking via /etc/hosts"
    echo "  ✅ GPU support enabled"
    echo "  ✅ Persistent storage for models and data"
    echo ""
}

# Check API key if in deploy mode
check_api_requirements() {
    if [[ "$DEPLOY_MODE" == "api" ]]; then
        if [[ -z "$RUNPOD_API_KEY" ]]; then
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
            echo -e "${YELLOW}⚠️  jq not found — will show raw JSON${NC}"
        else
            echo -e "${GREEN}✅ jq detected — pretty JSON parsing enabled${NC}"
        fi

        echo -e "${GREEN}✅ API key found, deployment mode ready${NC}"
        echo ""
    fi
}

# Get user input for configuration
get_configuration() {
    echo -e "${YELLOW}🔧 Configuration Setup${NC}"
    echo ""

    # Version input
    echo -e "${BLUE}Version:${NC}"
    read -p "Enter version tag (e.g., v1.0.0) [latest]: " version_input
    VERSION_TAG=${version_input:-latest}

    # Auto-generate image and template names based on version
    if [[ "$VERSION_TAG" == "latest" ]]; then
        DOCKER_IMAGE="heapsgo0d/sanctum:latest"
        TEMPLATE_NAME="Sanctum Latest"
    else
        DOCKER_IMAGE="heapsgo0d/sanctum:$VERSION_TAG"
        TEMPLATE_NAME="Sanctum $VERSION_TAG"
    fi

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

    # Privacy mode
    echo -e "${BLUE}Privacy Settings:${NC}"
    read -p "Enable privacy mode by default? [yes]: " privacy_input
    PRIVACY_MODE=${privacy_input:-yes}
    if [[ "$PRIVACY_MODE" =~ ^[Yy] ]]; then
        PRIVACY_MODE="enabled"
    else
        PRIVACY_MODE="disabled"
    fi
    echo "  → Privacy Mode: $PRIVACY_MODE"
    echo ""
}

# Generate template JSON
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
      "value": "False",
      "description": "Open WebUI authentication (set to True to enable)"
    },
    {
      "key": "WEBUI_PORT",
      "value": "8080",
      "description": "Open WebUI port"
    },
    {
      "key": "PRIVACY_MODE",
      "value": "$PRIVACY_MODE",
      "description": "Enable telemetry blocking (enabled/disabled)"
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
    echo "  Privacy Mode: $PRIVACY_MODE"
    echo ""
    echo -e "${BLUE}Access:${NC}"
    echo "  Open WebUI: http://[pod-id]-8080.proxy.runpod.net"
    echo "  SSH: RunPod provides host-level SSH (see RunPod console)"
    echo ""
}

# Deploy template via RunPod API
deploy_template() {
    echo -e "${YELLOW}🚀 Deploying template to RunPod...${NC}"

    HAS_JQ=true
    if ! command -v jq &>/dev/null; then
        HAS_JQ=false
    fi

    # Create API payload
    local api_payload=$(cat << EOF
{
  "name": "$TEMPLATE_NAME",
  "imageName": "$DOCKER_IMAGE",
  "containerDiskInGb": $CONTAINER_DISK_GB,
  "volumeInGb": $VOLUME_GB,
  "volumeMountPath": "/workspace",
  "dockerArgs": "",
  "ports": "8080/http",
  "readme": "# $TEMPLATE_NAME\\n\\n$TEMPLATE_DESCRIPTION\\n\\n## Features\\n- Privacy-first: telemetry blocking via /etc/hosts\\n- Minimal architecture: fast startup, clean design\\n- Persistent storage for models and data\\n\\n## Storage\\n- Container: ${CONTAINER_DISK_GB}GB\\n- Volume: ${VOLUME_GB}GB\\n\\n## Access\\n- Open WebUI: http://[pod-id]-8080.proxy.runpod.net\\n- SSH: RunPod provides host-level SSH automatically",
  "env": [
    {"key": "OLLAMA_HOST", "value": "0.0.0.0"},
    {"key": "OLLAMA_MODELS", "value": "/workspace/models"},
    {"key": "DATA_DIR", "value": "/workspace/data"},
    {"key": "WEBUI_AUTH", "value": "False"},
    {"key": "WEBUI_PORT", "value": "8080"},
    {"key": "PRIVACY_MODE", "value": "$PRIVACY_MODE"}
  ]
}
EOF
)

    echo -e "${BLUE}Sending request to RunPod API...${NC}"

    local response=$(curl -s -X POST \
        "https://api.runpod.io/graphql" \
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

    # Error detection
    if echo "$response" | grep -q '"errors"'; then
        echo -e "${RED}❌ API Error:${NC}"
        if $HAS_JQ; then
            echo "$response" | jq -r '.errors[0].message'
        else
            echo "$response"
        fi
        return 1
    fi

    # Extract template info
    local template_id
    local template_name
    if $HAS_JQ; then
        template_id=$(echo "$response" | jq -r '.data.saveTemplate.id')
        template_name=$(echo "$response" | jq -r '.data.saveTemplate.name')
    else
        template_id=$(echo "$response" | grep -o '"id":"[^"]*' | head -n1 | cut -d'"' -f4)
        template_name=$(echo "$response" | grep -o '"name":"[^"]*' | head -n1 | cut -d'"' -f4)
    fi

    if [[ -n "$template_id" && "$template_id" != "null" ]]; then
        echo -e "${GREEN}✅ Template deployed successfully!${NC}"
        echo -e "${BLUE}Template ID:${NC} $template_id"
        echo -e "${BLUE}Template Name:${NC} $template_name"
        echo -e "${BLUE}RunPod Console:${NC} https://runpod.io/console/user/templates"
        return 0
    else
        echo -e "${RED}❌ Failed to deploy template${NC}"
        echo -e "${YELLOW}Response:${NC} $response"
        return 1
    fi
}

# Main execution
main() {
    print_banner
    print_usage

    check_api_requirements

    echo -e "${YELLOW}Press Enter to continue with template creation...${NC}"
    read

    get_configuration

    echo -e "${YELLOW}🔨 Generating template files...${NC}"
    generate_template
    print_summary

    if [[ "$DEPLOY_MODE" == "api" ]]; then
        echo -e "${YELLOW}🚀 Deploying to RunPod...${NC}"
        if deploy_template; then
            echo ""
            echo -e "${GREEN}✅ Deployment complete!${NC}"
            echo ""
            echo -e "${YELLOW}Next Steps:${NC}"
            echo "  1. Go to RunPod Console → Templates"
            echo "  2. Find '$TEMPLATE_NAME'"
            echo "  3. Deploy a pod with GPU"
            echo "  4. Access Open WebUI at http://[pod-id]-8080.proxy.runpod.net"
        else
            echo ""
            echo -e "${YELLOW}⚠️  API deployment failed, but local file created${NC}"
            echo -e "${BLUE}Upload sanctum_template.json manually${NC}"
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
        echo "  3. Access Open WebUI at http://[pod-id]-8080.proxy.runpod.net"
        echo ""
        echo -e "${BLUE}💡 Tip: Use './template.sh --deploy' for automatic deployment${NC}"
    fi

    echo ""
    echo -e "${GREEN}🔒 Sanctum - Privacy-focused AI on RunPod${NC}"
}

main "$@"

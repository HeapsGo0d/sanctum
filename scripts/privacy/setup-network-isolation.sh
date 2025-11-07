#!/bin/bash
# Sanctum Network Isolation
# iptables-based allowlist for controlled egress

set -euo pipefail

echo "🔒 Setting up network isolation..."

# Parse allowed domains from environment variable
IFS=',' read -ra DOMAINS <<< "${ALLOWED_DOMAINS:-ollama.com,huggingface.co,registry.ollama.ai,ghcr.io}"

# Flush existing rules
iptables -F OUTPUT || true
iptables -F INPUT || true

# Default policy: deny all outbound traffic
iptables -P OUTPUT DROP
iptables -P INPUT ACCEPT
iptables -P FORWARD DROP

echo "  • Default policy: DROP outbound traffic"

# Allow loopback (localhost communication)
iptables -A OUTPUT -o lo -j ACCEPT
echo "  • Allow: localhost"

# Allow established and related connections
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
echo "  • Allow: established connections"

# Allow DNS (needed for domain resolution)
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
echo "  • Allow: DNS (port 53)"

# Allow HTTPS (443) and HTTP (80) to allowed domains
# Note: iptables doesn't filter by domain, so we allow all HTTPS/HTTP
# The DNS blocklist in setup-blocklist.sh provides domain-level filtering
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
echo "  • Allow: HTTPS (443) and HTTP (80)"

# Log the allowed domains (informational)
echo "  • Allowed domains (via DNS blocklist):"
for domain in "${DOMAINS[@]}"; do
    echo "    - $domain"
done

echo "✅ Network isolation active"
echo "   All outbound traffic blocked except:"
echo "   - Localhost"
echo "   - DNS"
echo "   - HTTPS/HTTP (filtered by DNS blocklist)"

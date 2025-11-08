#!/bin/bash
# Sanctum Telemetry Blocklist
# Blocks known telemetry and tracking domains via /etc/hosts

set -euo pipefail

# Check if we can modify /etc/hosts (graceful failure)
if [[ ! -w /etc/hosts ]]; then
    echo "⚠️  Cannot modify /etc/hosts - skipping blocklist"
    exit 0
fi

echo "🔒 Setting up telemetry blocklist..."

# Backup original hosts file if not already backed up
if [[ ! -f /etc/hosts.backup ]]; then
    cp /etc/hosts /etc/hosts.backup
    echo "  • Backed up /etc/hosts"
fi

# Blocklist - telemetry and tracking domains
BLOCKLIST=(
    # Common Analytics
    "google-analytics.com"
    "googletagmanager.com"
    "segment.io"
    "segment.com"
    "amplitude.com"
    "mixpanel.com"
    "sentry.io"
    "posthog.com"
    "hotjar.com"
    "fullstory.com"
    "logrocket.com"

    # AI/ML Tracking
    "analytics.openai.com"
    "telemetry.openai.com"
    "track.huggingface.co"
    "analytics.anthropic.com"

    # Additional tracking services
    "matomo.org"
    "piwik.org"
    "heap.io"
    "intercom.io"
)

# Add blocklist entries (IPv4 + IPv6)
for domain in "${BLOCKLIST[@]}"; do
    # Check IPv4 separately
    if ! grep -q "0.0.0.0 $domain" /etc/hosts 2>/dev/null; then
        echo "0.0.0.0 $domain" >> /etc/hosts
        echo "  • Blocked IPv4: $domain"
    fi

    # Check IPv6 separately
    if ! grep -q "::0 $domain" /etc/hosts 2>/dev/null; then
        echo "::0 $domain" >> /etc/hosts
        echo "  • Blocked IPv6: $domain"
    fi
done

echo "✅ Telemetry blocklist active (${#BLOCKLIST[@]} domains, IPv4 + IPv6)"

# Validate blocklist (optional verification)
echo ""
echo "🔍 Validating blocklist..."

# Test a few sample domains to confirm they resolve to 0.0.0.0
SAMPLE_DOMAINS=("google-analytics.com" "segment.io" "sentry.io")
VALIDATION_PASSED=true

for domain in "${SAMPLE_DOMAINS[@]}"; do
    # Use curl with very short timeout to test if domain is blocked
    if timeout 2 curl -s --connect-timeout 1 "http://$domain" > /dev/null 2>&1; then
        echo "  ⚠️  Warning: $domain may not be blocked (connected successfully)"
        VALIDATION_PASSED=false
    else
        # Connection failed or timed out = good (blocked)
        echo "  ✓ $domain blocked"
    fi
done

if [ "$VALIDATION_PASSED" = true ]; then
    echo "✅ Blocklist validation successful"
else
    echo "⚠️  Some domains may not be properly blocked (check /etc/hosts)"
fi

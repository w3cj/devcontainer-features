#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Verify configuration file integrity before loading
if [ -f /usr/local/bin/firewall-config.sha256 ]; then
    if ! sha256sum -c /usr/local/bin/firewall-config.sha256 --quiet 2>/dev/null; then
        echo "ERROR: Firewall config integrity check failed - file may have been tampered with"
        echo "Expected hash:"
        cat /usr/local/bin/firewall-config.sha256
        echo "Actual hash:"
        sha256sum /usr/local/bin/firewall-config.sh
        exit 1
    fi
    echo "Config integrity verified"
fi

# Source configuration (generated at install time)
source /usr/local/bin/firewall-config.sh

#######################################
# Helper Functions
#######################################

# Add a CIDR or IP to the ipset, with optional validation
# Usage: add_to_ipset "entry" "source_name" [strict]
add_to_ipset() {
    local entry="$1"
    local source="$2"
    local strict="${3:-false}"

    # Validate CIDR format (IP/prefix or just IP)
    if [[ "$entry" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?$ ]]; then
        echo "Adding $source: $entry"
        ipset add allowed-hosts "$entry" 2>/dev/null || true
    else
        if [ "$strict" = "true" ]; then
            echo "ERROR: Invalid entry from $source: $entry"
            exit 1
        else
            echo "WARNING: Skipping invalid entry from $source: $entry"
        fi
    fi
}

# Fetch JSON from URL with retry and exponential backoff
# Usage: fetch_json "url" "source_name"
fetch_json() {
    local url="$1"
    local source="$2"
    local max_retries=3
    local retry_delay=2
    local attempt=1
    local result
    local curl_exit

    echo "Fetching $source IP ranges..." >&2

    while [ $attempt -le $max_retries ]; do
        result=$(curl -sf --connect-timeout 10 --max-time 30 "$url" 2>/dev/null)
        curl_exit=$?

        if [ $curl_exit -eq 0 ] && [ -n "$result" ]; then
            # Validate JSON
            if echo "$result" | jq -e . >/dev/null 2>&1; then
                echo "$result"
                return 0
            fi
            echo "WARNING: $source API returned invalid JSON (attempt $attempt/$max_retries)" >&2
        else
            echo "WARNING: Failed to fetch $source (curl exit: $curl_exit, attempt $attempt/$max_retries)" >&2
        fi

        if [ $attempt -lt $max_retries ]; then
            echo "Retrying in ${retry_delay}s..." >&2
            sleep $retry_delay
            retry_delay=$((retry_delay * 2))
        fi
        attempt=$((attempt + 1))
    done

    echo "ERROR: Failed to fetch $source IP ranges after $max_retries attempts" >&2
    echo "URL: $url" >&2
    exit 1
}

# Process IP ranges from JSON and add to ipset
# Usage: process_ip_ranges "json_data" "jq_filter" "source_name" [use_aggregate]
process_ip_ranges() {
    local json_data="$1"
    local jq_filter="$2"
    local source="$3"
    local use_aggregate="${4:-false}"

    echo "Processing $source IPs..."
    if [ "$use_aggregate" = "true" ]; then
        while read -r cidr; do
            add_to_ipset "$cidr" "$source"
        done < <(echo "$json_data" | jq -r "$jq_filter" | aggregate -q)
    else
        while read -r cidr; do
            add_to_ipset "$cidr" "$source"
        done < <(echo "$json_data" | jq -r "$jq_filter")
    fi
}

# Add entries from a comma-separated list to ipset
# Usage: add_list_to_ipset "comma,separated,list" "source_name"
add_list_to_ipset() {
    local list="$1"
    local source="$2"

    if [ -z "$list" ]; then
        return
    fi

    echo "Adding $source..."
    IFS=',' read -ra ENTRIES <<< "$list"
    for entry in "${ENTRIES[@]}"; do
        entry=$(echo "$entry" | xargs)
        [ -z "$entry" ] && continue
        add_to_ipset "$entry" "$source"
    done
}

# Resolve domain to IPs and add to ipset
# Usage: resolve_and_add "domain"
resolve_and_add() {
    local domain="$1"

    if [[ "$domain" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        add_to_ipset "$domain" "IP address"
        return
    fi

    echo "Resolving $domain..."
    local ips
    ips=$(dig +timeout=5 +noall +answer A "$domain" | awk '$4 == "A" {print $5}')
    if [ -z "$ips" ]; then
        echo "WARNING: Failed to resolve $domain, skipping"
        return
    fi

    while read -r ip; do
        add_to_ipset "$ip" "$domain" "true"
    done < <(echo "$ips")
}

# Detect all Docker network CIDRs
# Usage: detect_docker_networks
detect_docker_networks() {
    ip -o -f inet addr show | grep -v "127.0.0.1" | awk '{print $4}'
}

# Allow traffic to/from a network CIDR via iptables
# Usage: allow_network "cidr" "description"
allow_network() {
    local cidr="$1"
    local desc="$2"
    echo "Allowing $desc: $cidr"
    iptables -A INPUT -s "$cidr" -j ACCEPT
    iptables -A OUTPUT -d "$cidr" -j ACCEPT
}

#######################################
# Main Firewall Setup
#######################################

# 1. Capture state BEFORE any flushing
DOCKER_DNS_RULES=$(iptables-save -t nat | grep "127\.0\.0\.11" || true)

# Detect Docker networks before flushing (needed for inter-container communication)
if [ "$INCLUDE_DOCKER_NETWORKS" = "true" ]; then
    echo "Detecting Docker networks..."
    DOCKER_NETWORKS=$(detect_docker_networks)
    if [ -z "$DOCKER_NETWORKS" ]; then
        echo "WARNING: No Docker networks detected"
    fi
fi

# 2. Flush existing rules and delete existing ipsets
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
ipset destroy allowed-hosts 2>/dev/null || true

# 3. Restore Docker DNS resolution
if [ -n "$DOCKER_DNS_RULES" ]; then
    echo "Restoring Docker DNS rules..."
    iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
    iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
    echo "$DOCKER_DNS_RULES" | xargs -L 1 iptables -t nat
else
    echo "No Docker DNS rules to restore"
fi

# 4. Allow DNS and localhost before any restrictions
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# 5. Create ipset with CIDR support
ipset create allowed-hosts hash:net

# 6. Fetch and add dynamic IP ranges

if [ "$INCLUDE_GITHUB_IPS" = "true" ]; then
    gh_data=$(fetch_json "https://api.github.com/meta" "GitHub")
    if ! echo "$gh_data" | jq -e '.web and .api and .git' >/dev/null; then
        echo "ERROR: GitHub API response missing required fields"
        exit 1
    fi
    process_ip_ranges "$gh_data" '(.web + .api + .git)[]' "GitHub" "true"
fi

if [ "$INCLUDE_GOOGLE_CLOUD_IPS" = "true" ]; then
    goog_data=$(fetch_json "https://www.gstatic.com/ipranges/goog.json" "Google Cloud")
    if ! echo "$goog_data" | jq -e '.prefixes' >/dev/null; then
        echo "ERROR: Google API response missing required fields"
        exit 1
    fi
    process_ip_ranges "$goog_data" '.prefixes[].ipv4Prefix | select(. != null)' "Google Cloud"
fi

if [ "$INCLUDE_CLOUDFLARE_IPS" = "true" ]; then
    cf_data=$(fetch_json "https://api.cloudflare.com/client/v4/ips" "Cloudflare")
    if ! echo "$cf_data" | jq -e '.result.ipv4_cidrs' >/dev/null; then
        echo "ERROR: Cloudflare API response missing required fields"
        exit 1
    fi
    process_ip_ranges "$cf_data" '.result.ipv4_cidrs[]' "Cloudflare"
fi

# AWS (filtered for US regions and specific services)
if [ "$INCLUDE_AWS_IPS" = "true" ]; then
    aws_data=$(fetch_json "https://ip-ranges.amazonaws.com/ip-ranges.json" "AWS")
    if ! echo "$aws_data" | jq -e '.prefixes' >/dev/null; then
        echo "ERROR: AWS API response missing required fields"
        exit 1
    fi
    echo "Processing AWS IPs (US regions: us-east-1, us-west-2; Services: EC2, CLOUDFRONT)..."
    process_ip_ranges "$aws_data" '.prefixes[] | select(.region == "us-east-1" or .region == "us-west-2") | select(.service == "EC2" or .service == "CLOUDFRONT") | .ip_prefix' "AWS" "true"
fi

# 7. Add static IP ranges
add_list_to_ipset "$ANTHROPIC_IPS" "Anthropic IPs"

# 8. Resolve and add configured hosts
if [ -n "$ALLOWED_HOSTS" ]; then
    IFS=',' read -ra HOST_ARRAY <<< "$ALLOWED_HOSTS"
    for host in "${HOST_ARRAY[@]}"; do
        host=$(echo "$host" | xargs)
        [ -z "$host" ] && continue
        resolve_and_add "$host"
    done
fi

# 9. Allow Docker/host networks
if [ "$INCLUDE_DOCKER_NETWORKS" = "true" ] && [ -n "$DOCKER_NETWORKS" ]; then
    echo "Allowing Docker networks..."
    while read -r network; do
        [ -z "$network" ] && continue
        allow_network "$network" "Docker network"
    done < <(echo "$DOCKER_NETWORKS")
else
    # Fallback: detect and allow only the host network from default route
    HOST_IP=$(ip route | grep default | cut -d" " -f3)
    if [ -z "$HOST_IP" ]; then
        echo "ERROR: Failed to detect host IP"
        exit 1
    fi
    HOST_NETWORK=$(echo "$HOST_IP" | sed "s/\.[0-9]*$/.0\/24/")
    allow_network "$HOST_NETWORK" "Host network"
fi

# 10. Set restrictive default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# 11. Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# 12. Allow traffic to approved hosts
iptables -A OUTPUT -m set --match-set allowed-hosts dst -j ACCEPT

# 12.5. If verbose mode, add NFLOG rule before REJECT (uses userspace logging via ulogd2)
if [ "$VERBOSE_MODE" = "true" ]; then
    echo "Enabling verbose firewall logging..."
    iptables -A OUTPUT -j NFLOG --nflog-prefix "FW-BLOCKED:" --nflog-group 1
fi

# 13. Reject all other outbound traffic
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

echo "Firewall configuration complete"

# 14. Verification tests
echo "Verifying firewall rules..."
# Skip example.com check if Cloudflare IPs are allowed (example.com is hosted on Cloudflare)
if [ "$INCLUDE_CLOUDFLARE_IPS" = "true" ]; then
    echo "Skipping example.com verification (Cloudflare IPs are allowed)"
else
    if curl --connect-timeout 5 https://example.com >/dev/null 2>&1; then
        echo "ERROR: Firewall verification failed - was able to reach https://example.com"
        exit 1
    else
        echo "Firewall verification passed - unable to reach https://example.com as expected"
    fi
fi

if [ "$INCLUDE_GITHUB_IPS" = "true" ]; then
    if ! curl --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
        echo "ERROR: Firewall verification failed - unable to reach https://api.github.com"
        exit 1
    else
        echo "Firewall verification passed - able to reach https://api.github.com as expected"
    fi
fi

# 15. Start verbose logging if enabled
if [ "$VERBOSE_MODE" = "true" ]; then
    echo "Starting ulogd2 daemon for NFLOG logging..."
    pkill -f "ulogd" 2>/dev/null || true
    sleep 1
    ulogd -d
    echo "ulogd2 started"

    echo "Starting firewall block watcher..."
    if [ -f /var/run/firewall-watcher.pid ]; then
        kill "$(cat /var/run/firewall-watcher.pid)" 2>/dev/null || true
        rm -f /var/run/firewall-watcher.pid
    fi
    nohup /usr/local/bin/firewall-watcher.sh &>/dev/null &
    echo $! > /var/run/firewall-watcher.pid
    echo "Firewall watcher started (PID: $!)"
fi

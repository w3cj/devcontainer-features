#!/usr/bin/env bash

set -e

source ./library_scripts.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTS_JSON="$SCRIPT_DIR/hosts.json"

get_hosts() {
    local key="$1"
    jq -r ".$key // [] | join(\",\")" "$HOSTS_JSON"
}

# Usage: add_hosts_if_enabled "FLAGNAME" "hostsJsonKey"
add_hosts_if_enabled() {
    local flag_name="$1"
    local hosts_key="$2"
    local flag_value
    flag_value=$(eval echo "\$$flag_name")
    if [ "$flag_value" = "true" ]; then
        ALL_HOSTS="$ALL_HOSTS,$(get_hosts "$hosts_key")"
    fi
}

HOSTS="${HOSTS:-""}"
DOCKERNETWORKS="${DOCKERNETWORKS:-"true"}"
GITHUBIPS="${GITHUBIPS:-"false"}"

CLAUDECODE="${CLAUDECODE:-"false"}"
CODEX="${CODEX:-"false"}"
ALLAIPROVIDERS="${ALLAIPROVIDERS:-"false"}"

ANTHROPICAPI="${ANTHROPICAPI:-"false"}"
SENTRY="${SENTRY:-"false"}"
OPENAIAPI="${OPENAIAPI:-"false"}"
GOOGLEAIAPI="${GOOGLEAIAPI:-"false"}"
CEREBRASAPI="${CEREBRASAPI:-"false"}"
QWENAPI="${QWENAPI:-"false"}"
MINIMAXAPI="${MINIMAXAPI:-"false"}"
COHEREAPI="${COHEREAPI:-"false"}"
TOGETHERAPI="${TOGETHERAPI:-"false"}"
REPLICATEAPI="${REPLICATEAPI:-"false"}"
HUGGINGFACEAPI="${HUGGINGFACEAPI:-"false"}"
PERPLEXITYAPI="${PERPLEXITYAPI:-"false"}"
MISTRALAPI="${MISTRALAPI:-"false"}"
DEEPINFRAAPI="${DEEPINFRAAPI:-"false"}"
FIREWORKSAPI="${FIREWORKSAPI:-"false"}"
GROQAPI="${GROQAPI:-"false"}"
LEPTONAPI="${LEPTONAPI:-"false"}"
MANCERAPI="${MANCERAPI:-"false"}"
DEEPSEEKAPI="${DEEPSEEKAPI:-"false"}"
YIAPI="${YIAPI:-"false"}"
OPENROUTERAPI="${OPENROUTERAPI:-"false"}"

NPMREGISTRY="${NPMREGISTRY:-"false"}"
PYPI="${PYPI:-"false"}"
VSCODEMARKETPLACE="${VSCODEMARKETPLACE:-"false"}"
DNSPUBLIC="${DNSPUBLIC:-"false"}"
GITHUBDOMAINS="${GITHUBDOMAINS:-"false"}"
DOCKERREGISTRY="${DOCKERREGISTRY:-"false"}"
DEBIANPACKAGES="${DEBIANPACKAGES:-"false"}"
UBUNTUPACKAGES="${UBUNTUPACKAGES:-"false"}"
CRATESIOREGISTRY="${CRATESIOREGISTRY:-"false"}"
CONTEXT7MCP="${CONTEXT7MCP:-"false"}"

GOOGLECLOUDIPS="${GOOGLECLOUDIPS:-"false"}"
CLOUDFLAREIPS="${CLOUDFLAREIPS:-"false"}"
AWSIPS="${AWSIPS:-"false"}"
ANTHROPICIPS="${ANTHROPICIPS:-"false"}"

VERBOSE="${VERBOSE:-"false"}"

if [ "$CLAUDECODE" = "true" ]; then
    ANTHROPICAPI="true"
    ANTHROPICIPS="true"
    SENTRY="true"
    NPMREGISTRY="true"
    VSCODEMARKETPLACE="true"
fi

if [ "$CODEX" = "true" ]; then
    OPENAIAPI="true"
    NPMREGISTRY="true"
fi

if [ "$ALLAIPROVIDERS" = "true" ]; then
    ANTHROPICAPI="true"
    ANTHROPICIPS="true"
    OPENAIAPI="true"
    GOOGLEAIAPI="true"
    CEREBRASAPI="true"
    QWENAPI="true"
    MINIMAXAPI="true"
    COHEREAPI="true"
    TOGETHERAPI="true"
    REPLICATEAPI="true"
    HUGGINGFACEAPI="true"
    PERPLEXITYAPI="true"
    MISTRALAPI="true"
    DEEPINFRAAPI="true"
    FIREWORKSAPI="true"
    GROQAPI="true"
    LEPTONAPI="true"
    MANCERAPI="true"
    DEEPSEEKAPI="true"
    YIAPI="true"
    OPENROUTERAPI="true"
fi

ALL_HOSTS=""

add_hosts_if_enabled "ANTHROPICAPI" "anthropicApi"
add_hosts_if_enabled "SENTRY" "sentry"
add_hosts_if_enabled "OPENAIAPI" "openaiApi"
add_hosts_if_enabled "GOOGLEAIAPI" "googleAiApi"
add_hosts_if_enabled "CEREBRASAPI" "cerebrasApi"
add_hosts_if_enabled "QWENAPI" "qwenApi"
add_hosts_if_enabled "MINIMAXAPI" "minimaxApi"
add_hosts_if_enabled "COHEREAPI" "cohereApi"
add_hosts_if_enabled "TOGETHERAPI" "togetherApi"
add_hosts_if_enabled "REPLICATEAPI" "replicateApi"
add_hosts_if_enabled "HUGGINGFACEAPI" "huggingfaceApi"
add_hosts_if_enabled "PERPLEXITYAPI" "perplexityApi"
add_hosts_if_enabled "MISTRALAPI" "mistralApi"
add_hosts_if_enabled "DEEPINFRAAPI" "deepinfraApi"
add_hosts_if_enabled "FIREWORKSAPI" "fireworksApi"
add_hosts_if_enabled "GROQAPI" "groqApi"
add_hosts_if_enabled "LEPTONAPI" "leptonApi"
add_hosts_if_enabled "MANCERAPI" "mancerApi"
add_hosts_if_enabled "DEEPSEEKAPI" "deepseekApi"
add_hosts_if_enabled "YIAPI" "yiApi"
add_hosts_if_enabled "OPENROUTERAPI" "openrouterApi"

add_hosts_if_enabled "NPMREGISTRY" "npmRegistry"
add_hosts_if_enabled "PYPI" "pypi"
add_hosts_if_enabled "VSCODEMARKETPLACE" "vscodeMarketplace"
add_hosts_if_enabled "DNSPUBLIC" "dnsPublic"
add_hosts_if_enabled "GITHUBDOMAINS" "githubDomains"
add_hosts_if_enabled "DOCKERREGISTRY" "dockerRegistry"
add_hosts_if_enabled "DEBIANPACKAGES" "debianPackages"
add_hosts_if_enabled "UBUNTUPACKAGES" "ubuntuPackages"
add_hosts_if_enabled "CRATESIOREGISTRY" "cratesIoRegistry"
add_hosts_if_enabled "CONTEXT7MCP" "context7Mcp"

if [ -n "$HOSTS" ]; then
    ALL_HOSTS="$ALL_HOSTS,$HOSTS"
fi

ALL_HOSTS="${ALL_HOSTS#,}"

ANTHROPIC_IPS_LIST=""
if [ "$ANTHROPICIPS" = "true" ]; then
    ANTHROPIC_IPS_LIST="$(get_hosts "anthropicIps")"
fi

# Generate the firewall configuration file (sourced by init-firewall.sh at runtime)
cat > /usr/local/bin/firewall-config.sh << EOF
# Firewall configuration - generated at install time
ALLOWED_HOSTS="${ALL_HOSTS}"
INCLUDE_GITHUB_IPS="${GITHUBIPS}"
INCLUDE_DOCKER_NETWORKS="${DOCKERNETWORKS}"
INCLUDE_GOOGLE_CLOUD_IPS="${GOOGLECLOUDIPS}"
INCLUDE_CLOUDFLARE_IPS="${CLOUDFLAREIPS}"
INCLUDE_AWS_IPS="${AWSIPS}"
ANTHROPIC_IPS="${ANTHROPIC_IPS_LIST}"
VERBOSE_MODE="${VERBOSE}"
EOF

# Generate integrity hash for config file
sha256sum /usr/local/bin/firewall-config.sh > /usr/local/bin/firewall-config.sha256

# Harden config file permissions - read-only to prevent tampering
chown root:root /usr/local/bin/firewall-config.sh
chmod 444 /usr/local/bin/firewall-config.sh
chown root:root /usr/local/bin/firewall-config.sha256
chmod 444 /usr/local/bin/firewall-config.sha256

cp "$SCRIPT_DIR/scripts/init-firewall.sh" /usr/local/bin/init-firewall.sh
chown root:root /usr/local/bin/init-firewall.sh
chmod 755 /usr/local/bin/init-firewall.sh

if [ "$VERBOSE" = "true" ]; then
    mkdir -p /var/log/ulog
    cp "$SCRIPT_DIR/scripts/ulogd.conf" /etc/ulogd.conf

    touch /var/log/firewall-blocks.log
    chmod 644 /var/log/firewall-blocks.log

    # Create temp directory for firewall runtime files
    # 755 allows user shells to read the display queue via firewall-verbose.sh
    mkdir -p /var/run/firewall
    chmod 755 /var/run/firewall

    cp "$SCRIPT_DIR/scripts/firewall-watcher.sh" /usr/local/bin/firewall-watcher.sh
    chown root:root /usr/local/bin/firewall-watcher.sh
    chmod 755 /usr/local/bin/firewall-watcher.sh

    cp "$SCRIPT_DIR/scripts/firewall-verbose.sh" /etc/profile.d/firewall-verbose.sh
    chmod 644 /etc/profile.d/firewall-verbose.sh

    echo "Verbose mode scripts installed"
fi

# Configure sudoers to allow any user to run the firewall script without password
# This is safe because:
# - firewall-config.sh is read-only (444) and owned by root
# - firewall-config.sh has integrity hash verification in init-firewall.sh
# - init-firewall.sh is owned by root with 755 permissions
mkdir -p /etc/sudoers.d
echo "ALL ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/firewall
chmod 0440 /etc/sudoers.d/firewall

echo 'Firewall feature installed successfully!'
echo "Configured hosts: ${ALL_HOSTS:-"(none)"}"
echo "Include GitHub IPs: ${GITHUBIPS}"
echo "Include Docker networks: ${DOCKERNETWORKS}"
echo "Include Google Cloud IPs: ${GOOGLECLOUDIPS}"
echo "Include Cloudflare IPs: ${CLOUDFLAREIPS}"
echo "Include AWS IPs: ${AWSIPS}"
echo "Anthropic IPs: ${ANTHROPIC_IPS_LIST:-"(none)"}"
echo "Verbose mode: ${VERBOSE}"

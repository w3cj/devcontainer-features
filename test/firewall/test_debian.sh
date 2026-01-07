#!/usr/bin/env bash

set -e

source dev-container-features-test-lib

# =============================================================================
# File checks
# =============================================================================

# Check that the firewall script is installed
check "firewall script exists" test -f /usr/local/bin/init-firewall.sh
check "firewall script is executable" test -x /usr/local/bin/init-firewall.sh

# Check that firewall config is generated
check "firewall config exists" test -f /usr/local/bin/firewall-config.sh

# Check that sudoers is configured
check "sudoers file exists" test -f /etc/sudoers.d/firewall

# =============================================================================
# Package checks (all packages from dependsOn)
# =============================================================================

# Core firewall packages
check "iptables is installed" which iptables
check "ipset is installed" which ipset

# DNS utilities (dnsutils package)
check "dig is installed" which dig

# JSON processing
check "jq is installed" which jq

# HTTP client
check "curl is installed" which curl

# Network utilities (iproute2 package)
check "ip command is installed" which ip

# IP aggregation tool
check "aggregate is installed" which aggregate

# Privilege escalation
check "sudo is installed" which sudo

# Packet capture (for verbose mode DNS resolution)
check "tcpdump is installed" which tcpdump

# Userspace logging (for verbose mode)
check "ulogd is installed" which ulogd

# =============================================================================
# Configuration checks for test_debian scenario (githubIps: true)
# =============================================================================

check "includeGitHubIps is true" grep -q 'INCLUDE_GITHUB_IPS="true"' /usr/local/bin/firewall-config.sh

# =============================================================================
# Functional firewall verification
# =============================================================================

# Verify blocked domain is unreachable (example.com should be blocked)
check "blocked domain unreachable" bash -c "! curl --connect-timeout 3 -sf https://example.com"

# Verify allowed domain is reachable (GitHub should be allowed since github: true)
check "allowed domain reachable" bash -c "curl --connect-timeout 5 -sf https://api.github.com/zen"

reportResults

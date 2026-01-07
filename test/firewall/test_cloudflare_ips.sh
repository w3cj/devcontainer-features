#!/usr/bin/env bash

set -e

source dev-container-features-test-lib

# Check that the firewall script is installed
check "firewall script exists" test -f /usr/local/bin/init-firewall.sh
check "firewall script is executable" test -x /usr/local/bin/init-firewall.sh

# Check that Cloudflare IPs option is enabled in config
check "cloudflare IPs enabled" grep -q 'INCLUDE_CLOUDFLARE_IPS="true"' /usr/local/bin/firewall-config.sh

# Verify ipset has Cloudflare entries (populated at runtime by init-firewall.sh)
# Cloudflare IPs are in ranges like 173.245.48.0/20, 103.21.244.0/22, 104.16.0.0/13, etc.
check "ipset has cloudflare entries" bash -c "sudo ipset list allowed-hosts | grep -qE '(173\.245|103\.21|104\.16)'"

# Check that GitHub IPs is enabled (for comparison/sanity check)
check "includeGitHubIps is true" grep -q 'INCLUDE_GITHUB_IPS="true"' /usr/local/bin/firewall-config.sh

reportResults

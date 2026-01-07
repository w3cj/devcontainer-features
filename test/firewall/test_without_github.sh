#!/usr/bin/env bash

set -e

source dev-container-features-test-lib

# Check that the firewall script is installed
check "firewall script exists" test -f /usr/local/bin/init-firewall.sh
check "firewall script is executable" test -x /usr/local/bin/init-firewall.sh

# Check that the domains are baked into the config (config is in firewall-config.sh)
check "domains are configured" grep -q "api.anthropic.com" /usr/local/bin/firewall-config.sh

# Check that GitHub IPs is disabled
check "includeGitHubIps is false" grep -q 'INCLUDE_GITHUB_IPS="false"' /usr/local/bin/firewall-config.sh

reportResults

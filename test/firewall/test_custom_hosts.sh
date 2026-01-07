#!/usr/bin/env bash

set -e

source dev-container-features-test-lib

# Check that the firewall script is installed
check "firewall script exists" test -f /usr/local/bin/init-firewall.sh
check "firewall script is executable" test -x /usr/local/bin/init-firewall.sh

# Check that custom hosts are configured (config is in firewall-config.sh)
check "anthropic api configured" grep -q "api.anthropic.com" /usr/local/bin/firewall-config.sh
check "npm registry configured" grep -q "registry.npmjs.org" /usr/local/bin/firewall-config.sh

# Check that GitHub IPs is enabled
check "includeGitHubIps is true" grep -q 'INCLUDE_GITHUB_IPS="true"' /usr/local/bin/firewall-config.sh

reportResults

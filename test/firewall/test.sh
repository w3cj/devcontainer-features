#!/usr/bin/env bash

set -e

source dev-container-features-test-lib

# Check that the firewall script is installed
check "firewall script exists" test -f /usr/local/bin/init-firewall.sh
check "firewall script is executable" test -x /usr/local/bin/init-firewall.sh

# Check that required dependencies are installed
check "iptables is installed" which iptables
check "ipset is installed" which ipset
check "dig is installed" which dig
check "jq is installed" which jq
check "curl is installed" which curl

# Check that sudoers is configured
check "sudoers file exists" test -f /etc/sudoers.d/firewall

# Check that firewall config exists
check "firewall config exists" test -f /usr/local/bin/firewall-config.sh

# Verify default configuration values
check "dockerNetworks default is true" grep -q 'INCLUDE_DOCKER_NETWORKS="true"' /usr/local/bin/firewall-config.sh
check "verbose default is false" grep -q 'VERBOSE_MODE="false"' /usr/local/bin/firewall-config.sh
check "githubIps default is false" grep -q 'INCLUDE_GITHUB_IPS="false"' /usr/local/bin/firewall-config.sh

reportResults

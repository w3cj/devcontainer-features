#!/usr/bin/env bash

set -e

source dev-container-features-test-lib

# Check that the firewall script is installed
check "firewall script exists" test -f /usr/local/bin/init-firewall.sh
check "firewall script is executable" test -x /usr/local/bin/init-firewall.sh

# Firewall is already initialized by postStartCommand, verify it's active
check "firewall DROP policy is set" bash -c 'sudo iptables -L OUTPUT | grep -q "policy DROP"'

# Positive test: GitHub should be accessible (allowed)
check "github is accessible" curl --connect-timeout 10 -sf https://api.github.com/zen

# Negative test: example.com should be blocked (not in allowlist)
# We expect curl to fail, so we invert the exit code
check "example.com is blocked" bash -c '! curl --connect-timeout 5 -sf https://example.com'

# Negative test: httpbin.org should be blocked
check "httpbin.org is blocked" bash -c '! curl --connect-timeout 5 -sf https://httpbin.org/get'

reportResults

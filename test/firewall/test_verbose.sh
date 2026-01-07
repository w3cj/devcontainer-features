#!/usr/bin/env bash

set -e

source dev-container-features-test-lib

# Check that the firewall script is installed
check "firewall script exists" test -f /usr/local/bin/init-firewall.sh
check "firewall script is executable" test -x /usr/local/bin/init-firewall.sh

# Check that verbose mode is configured (config is in firewall-config.sh, sourced by init-firewall.sh)
check "verbose mode is true" grep -q 'VERBOSE_MODE="true"' /usr/local/bin/firewall-config.sh

# Check that the watcher script is installed
check "watcher script exists" test -f /usr/local/bin/firewall-watcher.sh
check "watcher script is executable" test -x /usr/local/bin/firewall-watcher.sh

# Check that the profile.d hook is installed
check "profile.d hook exists" test -f /etc/profile.d/firewall-verbose.sh

# Check that ulogd2 is installed
check "ulogd2 is installed" which ulogd

# Check that ulogd.conf exists
check "ulogd.conf exists" test -f /etc/ulogd.conf

# Check that the firewall runtime directory exists
check "firewall runtime dir exists" test -d /var/run/firewall

# Check that tcpdump is installed (required for DNS capture)
check "tcpdump is installed" which tcpdump

# Check that the watcher script contains key components
check "watcher has DNS capture" grep -q "tcpdump" /usr/local/bin/firewall-watcher.sh
check "watcher monitors ulogd log" grep -q "firewall-blocks.log" /usr/local/bin/firewall-watcher.sh
check "watcher has FW-BLOCKED detection" grep -q "FW-BLOCKED" /usr/local/bin/firewall-watcher.sh

# Check that the profile hook contains the display function
check "profile has display function" grep -q "__firewall_display_blocks" /etc/profile.d/firewall-verbose.sh
check "profile has PROMPT_COMMAND hook" grep -q "PROMPT_COMMAND" /etc/profile.d/firewall-verbose.sh

# Check that the init script has the NFLOG rule logic (not LOG)
check "init script has NFLOG rule" grep -q "iptables -A OUTPUT -j NFLOG" /usr/local/bin/init-firewall.sh

# Functional test: Verify blocked request gets logged
echo "Running functional test for verbose logging..."

# Check that ulogd2 is running
check "ulogd2 process running" pgrep -f "ulogd"

# Check that the watcher process is running
check "watcher process running" pgrep -f "firewall-watcher.sh"

# Check that the iptables NFLOG rule was added
check "iptables NFLOG rule exists" bash -c "sudo iptables -L OUTPUT -n | grep -q 'NFLOG.*nflog-prefix'"

# Clear any existing queue
: > /var/run/firewall/display-queue 2>/dev/null || true

# Try to access a blocked domain (example.com should be blocked)
echo "Triggering blocked request to example.com..."
curl --connect-timeout 3 https://example.com 2>/dev/null || true

# Wait for ulogd2 to write to log and watcher to process
# The watcher does reverse DNS lookups (2s timeout each), so we need to wait longer
echo "Waiting for watcher to process (includes reverse DNS lookups)..."
sleep 8

# Check if ulogd2 log file has content
echo "=== Checking ulogd2 log file ==="
cat /var/log/firewall-blocks.log 2>/dev/null | tail -5 || echo "(log file empty or not readable)"

# Check if the watcher's display queue has content (now in /var/run/firewall/)
echo "=== Display queue content ==="
cat /var/run/firewall/display-queue 2>/dev/null || echo "(queue empty or not readable)"
echo "============================="

# Debug: Check watcher process details
echo "=== Watcher debug info ==="
echo "Watcher PIDs: $(pgrep -f firewall-watcher.sh)"
echo "Process tree:"
ps aux | grep -E "(watcher|tail|tcpdump)" | grep -v grep || echo "(no matching processes)"
echo "Files in /var/run/firewall/:"
ls -la /var/run/firewall/ 2>/dev/null || echo "(directory not found)"
echo "Watcher debug log:"
cat /var/run/firewall/watcher-debug.log 2>/dev/null || echo "(no debug log)"
echo "==========================="

# Check iptables packet counts - this always works
echo "Checking iptables NFLOG rule packet counts..."
NFLOG_PACKETS=$(sudo iptables -L OUTPUT -v -n | grep 'NFLOG.*nflog-prefix' | awk '{print $1}')
echo "NFLOG rule matched packets: $NFLOG_PACKETS"

# If the NFLOG rule has matched packets, the logging is working at the iptables level
check "iptables NFLOG rule matched traffic" bash -c "sudo iptables -L OUTPUT -v -n | grep 'NFLOG.*nflog-prefix' | awk '{print \$1}' | grep -qv '^0$'"

# Check that the ulogd2 log file received the blocked connection
check "ulogd2 log has content" test -s /var/log/firewall-blocks.log

# Check that the watcher processed the block into the display queue (now in /var/run/firewall/)
check "watcher processed the block" test -s /var/run/firewall/display-queue
check "log contains FIREWALL prefix" grep -q "\[FIREWALL\]" /var/run/firewall/display-queue
check "log contains Blocked" grep -q "Blocked:" /var/run/firewall/display-queue

reportResults

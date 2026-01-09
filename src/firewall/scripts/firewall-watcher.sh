#!/bin/bash
# Firewall block watcher daemon
# Monitors ulogd2 log file for blocked connections and queues notifications
# Works in unprivileged containers (no kernel log access required)

set -u

FIREWALL_TMP="/var/run/firewall"
DNS_CACHE="$FIREWALL_TMP/dns-cache"
DNS_PENDING="$FIREWALL_TMP/dns-pending"
DISPLAY_QUEUE="$FIREWALL_TMP/display-queue"
DEDUP_FILE="$FIREWALL_TMP/dedup"
DEBUG_LOG="$FIREWALL_TMP/watcher-debug.log"
CACHE_TTL=120
DEDUP_WINDOW=30

# Debug logging function
log_debug() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$DEBUG_LOG"
}

log_debug "Watcher script started"

# Display queue and lock are writable by user shells for atomic read-and-clear
touch "$DISPLAY_QUEUE" "$FIREWALL_TMP/queue.lock"
chmod 666 "$DISPLAY_QUEUE" "$FIREWALL_TMP/queue.lock"
touch "$DNS_CACHE" "$DNS_PENDING" "$DEDUP_FILE"
chmod 644 "$DNS_CACHE" "$DNS_PENDING" "$DEDUP_FILE"

log_debug "Files initialized"

# Cleanup expired DNS cache and pending query entries
cleanup_dns_cache() {
    local now
    now=$(date +%s)
    local temp_file

    # Cleanup DNS cache
    temp_file=$(mktemp)
    while IFS='|' read -r ip hostname timestamp; do
        if [ $((now - timestamp)) -lt $CACHE_TTL ]; then
            echo "$ip|$hostname|$timestamp"
        fi
    done < "$DNS_CACHE" > "$temp_file" 2>/dev/null
    mv "$temp_file" "$DNS_CACHE" 2>/dev/null || true

    # Cleanup pending DNS queries (use shorter 10s TTL since responses arrive quickly)
    temp_file=$(mktemp)
    while IFS='|' read -r txn_id domain timestamp; do
        if [ $((now - timestamp)) -lt 10 ]; then
            echo "$txn_id|$domain|$timestamp"
        fi
    done < "$DNS_PENDING" > "$temp_file" 2>/dev/null
    mv "$temp_file" "$DNS_PENDING" 2>/dev/null || true
}

# Cleanup expired dedup entries
cleanup_dedup() {
    local now
    now=$(date +%s)
    local temp_file
    temp_file=$(mktemp)
    while IFS='|' read -r key timestamp; do
        if [ $((now - timestamp)) -lt $DEDUP_WINDOW ]; then
            echo "$key|$timestamp"
        fi
    done < "$DEDUP_FILE" > "$temp_file" 2>/dev/null
    mv "$temp_file" "$DEDUP_FILE" 2>/dev/null || true
}

# Check if we should deduplicate this block
should_skip() {
    local key="$1"
    local now
    now=$(date +%s)
    if grep -q "^$key|" "$DEDUP_FILE" 2>/dev/null; then
        return 0  # Skip, already seen recently
    fi
    echo "$key|$now" >> "$DEDUP_FILE"
    return 1  # Don't skip, first time seeing this
}

# Look up domain from DNS cache
lookup_dns_cache() {
    local ip="$1"
    grep "^$ip|" "$DNS_CACHE" 2>/dev/null | head -1 | cut -d'|' -f2
}

# Reverse DNS lookup with timeout (fallback)
reverse_dns() {
    local ip="$1"
    local result
    result=$(timeout 2 host "$ip" 2>/dev/null | awk '/domain name pointer/ {print $5; exit}' | sed 's/\.$//')
    if [ -z "$result" ]; then
        result="unknown"
    fi
    echo "$result"
}

# Parse DNS query/response from tcpdump and update cache
# Correlates queries (which have domain names) with responses (which have IPs)
# using the DNS transaction ID
parse_dns_line() {
    local line="$1"
    local now
    now=$(date +%s)

    # DNS Query format: "... 25679+ A? example.com. (43)"
    # Extract transaction ID and domain from queries
    if echo "$line" | grep -qE '[0-9]+\+ A\?'; then
        local txn_id domain
        txn_id=$(echo "$line" | grep -oE '[0-9]+\+ A\?' | grep -oE '^[0-9]+')
        domain=$(echo "$line" | grep -oE 'A\? [^ ]+' | sed 's/A? //' | sed 's/\.$//')
        if [ -n "$txn_id" ] && [ -n "$domain" ]; then
            # Store pending query (will be matched with response)
            echo "$txn_id|$domain|$now" >> "$DNS_PENDING"
        fi
        return
    fi

    # DNS Response format: "... 25679 4/0/0 A 185.199.111.133, A 185.199.108.133"
    # Extract transaction ID and IPs, lookup domain from pending queries
    if echo "$line" | grep -qE '[0-9]+ [0-9]+/[0-9]+/[0-9]+ A '; then
        local txn_id domain
        txn_id=$(echo "$line" | grep -oE '[0-9]+ [0-9]+/[0-9]+/[0-9]+' | awk '{print $1}')
        domain=$(grep "^$txn_id|" "$DNS_PENDING" 2>/dev/null | head -1 | cut -d'|' -f2)

        if [ -n "$domain" ]; then
            # Extract all IPs from response (may have multiple A records)
            local ips
            ips=$(echo "$line" | grep -oE 'A [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | awk '{print $2}')
            while read -r ip; do
                [ -z "$ip" ] && continue
                # Update DNS cache with IP -> domain mapping
                grep -v "^$ip|" "$DNS_CACHE" > "$DNS_CACHE.tmp" 2>/dev/null || true
                echo "$ip|$domain|$now" >> "$DNS_CACHE.tmp"
                mv "$DNS_CACHE.tmp" "$DNS_CACHE" 2>/dev/null || true
            done <<< "$ips"

            # Remove matched query from pending
            grep -v "^$txn_id|" "$DNS_PENDING" > "$DNS_PENDING.tmp" 2>/dev/null || true
            mv "$DNS_PENDING.tmp" "$DNS_PENDING" 2>/dev/null || true
        fi
    fi
}

# Parse iptables log line
parse_block_line() {
    local line="$1"

    local dst dpt proto
    dst=$(echo "$line" | grep -oE 'DST=[0-9.]+' | cut -d= -f2)
    dpt=$(echo "$line" | grep -oE 'DPT=[0-9]+' | cut -d= -f2)
    proto=$(echo "$line" | grep -oE 'PROTO=[A-Z]+' | cut -d= -f2)

    if [ -z "$dst" ] || [ -z "$dpt" ]; then
        return 1
    fi

    echo "$dst|$dpt|${proto:-TCP}"
}

# Main loop counter for periodic cleanup
counter=0

# Start DNS capture in background
log_debug "Starting DNS capture..."
tcpdump -l -n -i any 'port 53' 2>/dev/null | while IFS= read -r line; do
    parse_dns_line "$line"
done &
DNS_PID=$!
log_debug "DNS capture started with PID $DNS_PID"
trap "kill $DNS_PID 2>/dev/null" EXIT

process_log_line() {
    local line="$1"

    # Only process our firewall log entries
    case "$line" in
        *"FW-BLOCKED:"*)
            ;;
        *)
            return 1
            ;;
    esac

    parsed=$(parse_block_line "$line")
    if [ -z "$parsed" ]; then
        return 1
    fi

    dst=$(echo "$parsed" | cut -d'|' -f1)
    dpt=$(echo "$parsed" | cut -d'|' -f2)
    proto=$(echo "$parsed" | cut -d'|' -f3)

    # Deduplication check
    dedup_key="$dst:$dpt"
    if should_skip "$dedup_key"; then
        return 0
    fi

    # Look up domain: first try DNS cache, then fallback to reverse DNS
    hostname=$(lookup_dns_cache "$dst")
    if [ -z "$hostname" ]; then
        hostname=$(reverse_dns "$dst")
    fi

    timestamp=$(date +%H:%M:%S)
    message="[FIREWALL] Blocked: $dst:$dpt ($hostname) $proto @ $timestamp"

    # Append to display queue (with file locking for safety)
    (
        flock -w 1 200 || exit 1
        echo "$message" >> "$DISPLAY_QUEUE"
    ) 200>"$FIREWALL_TMP/queue.lock"

    # Periodic cleanup (every 50 entries)
    counter=$((counter + 1))
    if [ $((counter % 50)) -eq 0 ]; then
        cleanup_dns_cache
        cleanup_dedup
    fi
}

# Log file location (written by ulogd2)
ULOGD_LOG="/var/log/firewall-blocks.log"

log_debug "Starting log file monitoring..."

# Wait for ulogd2 to create the log file
for i in $(seq 1 30); do
    if [ -f "$ULOGD_LOG" ]; then
        log_debug "Log file found after $i iterations"
        break
    fi
    sleep 0.5
done

if [ ! -f "$ULOGD_LOG" ]; then
    log_debug "ERROR: ulogd2 log file not found at $ULOGD_LOG"
    exit 1
fi

log_debug "Starting tail on $ULOGD_LOG"

# Monitor the ulogd2 log file for blocked connections
tail -F "$ULOGD_LOG" 2>/dev/null | while IFS= read -r line; do
    log_debug "Got line: $line"
    process_log_line "$line"
    log_debug "Processed line, queue size: $(wc -l < "$DISPLAY_QUEUE" 2>/dev/null || echo 0)"
done

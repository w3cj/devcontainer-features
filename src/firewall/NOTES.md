See [`hosts.json`](hosts.json) for the full list of domains allowed by each option. All boolean options default to `false` unless otherwise noted.

## Another Example

```json
"features": {
    "ghcr.io/w3cj/devcontainer-features/firewall:latest": {
      "verbose": true,
      "hosts": "10.0.0.42,myapi.com,api.mysite.com",
      "githubIps": true,
      "githubDomains": true,
      "npmRegistry": true,
      "vscodeMarketplace": true,
      "anthropicIps": true,
      "anthropicApi": true
    }
}
```

## How It Works

This feature:

1. **Generates a firewall script** at `/usr/local/bin/init-firewall.sh` that runs on container start
1. **Configures sudoers** to allow non-root users to execute the firewall script

The firewall script:

- Preserves Docker's internal DNS resolution
- Allows DNS queries (UDP port 53) and SSH (TCP port 22)
- Allows localhost and host network communication
- Creates an ipset of allowed IP addresses from DNS resolution of all enabled hosts
- Sets default DROP policies for INPUT, FORWARD, and OUTPUT
- Allows only traffic to the whitelisted IP addresses
- Runs verification tests to confirm the firewall is working

## Requirements

This feature automatically adds the required Linux capabilities:
- `NET_ADMIN` - Required for iptables modifications
- `NET_RAW` - Required for raw socket operations

These are added via the `capAdd` property in the feature configuration.

## Verbose Mode

Enable `verbose: true` to see inline terminal notifications when connections are blocked:

```json
"features": {
    "ghcr.io/w3cj/devcontainer-features/firewall:latest": {
        "verbose": true
    }
}
```

When enabled, blocked connections will display at your shell prompt:

```
[FIREWALL] Blocked: 93.184.216.34:443 (example.com) TCP @ 14:32:15
```

Features:
- DNS query capture shows the actual domain name being accessed (not just IP)
- Reverse DNS fallback for direct IP access attempts
- Deduplication (same IP:port shown only once per 30 seconds)
- Works with bash and zsh
- Can be disabled per-session with `export FIREWALL_VERBOSE=false`

### Verbose Mode Logging Details

When verbose mode is enabled, the following components are activated:

1. **NFLOG iptables rule** - Captures metadata about blocked packets (source/destination IP, port, protocol)
2. **ulogd2 daemon** - Writes packet metadata to `/var/log/ulog/syslogemu.log`
3. **firewall-watcher.sh daemon** - Parses logs and resolves IPs to domain names
4. **tcpdump** - Captures DNS responses to map IPs back to requested domains

**Data captured includes:**
- Destination IP addresses and ports of blocked connections
- Timestamps of blocked connection attempts
- Domain names (resolved via DNS cache or reverse lookup)
- Protocol (TCP/UDP)

**Data is NOT captured:**
- Packet payloads or content
- Successful/allowed connections
- Source application or process information

**Log locations:**
- `/var/log/firewall-blocks.log` - Raw NFLOG output from ulogd2
- `/var/run/firewall/` - Runtime files (display queue, DNS cache)

**Privacy considerations:**
- Blocked connection logs reveal what external services code/tools attempted to contact
- Logs persist until container restart
- In shared environments, other users with root access could view the logs
- Consider disabling verbose mode when working with sensitive projects

## Security Considerations

- The firewall runs on every container start via `postStartCommand`
- Domain IP addresses are resolved at container start time, so changes to DNS will be picked up on restart
- The feature uses a default-deny approach - all traffic is blocked except explicitly allowed domains
- Blocked traffic is rejected with ICMP admin-prohibited for immediate feedback
- Configuration file is read-only (chmod 444) to prevent tampering
- SHA256 integrity verification before loading configuration
- Scripts owned by root with hardened permissions (755)

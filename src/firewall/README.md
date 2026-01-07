
# Firewall (firewall)

Sets up an iptables-based firewall that restricts network access to only specified hosts. This is useful for creating sandboxed development environments with limited network access.

## Example Usage

```json
"features": {
    "ghcr.io/w3cj/devcontainer-features/firewall:0": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| verbose | Show inline terminal notifications when connections are blocked | boolean | false |
| hosts | Comma-separated list of additional hosts to allow | string | - |
| dockerNetworks | Allow traffic to/from all Docker networks (for inter-container communication) | boolean | true |
| dnsPublic | Public DNS servers | boolean | false |
| githubDomains | GitHub domains | boolean | false |
| githubIps | GitHub IP ranges (fetched at runtime) | boolean | false |
| npmRegistry | npm registry | boolean | false |
| pypi | Python Package Index | boolean | false |
| cratesIoRegistry | Rust crates.io registry | boolean | false |
| vscodeMarketplace | VS Code marketplace | boolean | false |
| dockerRegistry | Docker Hub registry | boolean | false |
| debianPackages | Debian repositories | boolean | false |
| ubuntuPackages | Ubuntu repositories | boolean | false |
| googleCloudIps | Google Cloud IP ranges (fetched at runtime) | boolean | false |
| cloudflareIps | Cloudflare CDN IP ranges (fetched at runtime) | boolean | false |
| awsIps | AWS IP ranges (US regions, fetched at runtime) | boolean | false |
| anthropicIps | Anthropic static IP ranges | boolean | false |
| claudeCode | Claude Code (Anthropic API, Sentry, npm, VS Code marketplace) | boolean | false |
| codex | OpenAI Codex CLI (OpenAI API, npm) | boolean | false |
| allAiProviders | Enable all AI provider APIs | boolean | false |
| context7Mcp | Context7 MCP | boolean | false |
| openrouterApi | OpenRouter API | boolean | false |
| anthropicApi | Anthropic API | boolean | false |
| sentry | Sentry error tracking | boolean | false |
| openaiApi | OpenAI API | boolean | false |
| googleAiApi | Google AI API | boolean | false |
| cerebrasApi | Cerebras API | boolean | false |
| qwenApi | Qwen/Alibaba API | boolean | false |
| minimaxApi | Minimax API | boolean | false |
| cohereApi | Cohere API | boolean | false |
| togetherApi | Together API | boolean | false |
| replicateApi | Replicate API | boolean | false |
| huggingfaceApi | Hugging Face API | boolean | false |
| perplexityApi | Perplexity API | boolean | false |
| mistralApi | Mistral API | boolean | false |
| deepinfraApi | DeepInfra API | boolean | false |
| fireworksApi | Fireworks API | boolean | false |
| groqApi | Groq API | boolean | false |
| leptonApi | Lepton API | boolean | false |
| mancerApi | Mancer API | boolean | false |
| deepseekApi | DeepSeek API | boolean | false |
| yiApi | Yi/01.AI API | boolean | false |

See [`hosts.json`](hosts.json) for the full list of domains allowed by each option. All boolean options default to `false` unless otherwise noted.

## Another Example

```json
"features": {
    "ghcr.io/w3cj/devcontainer-features/firewall:1": {
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
    "ghcr.io/w3cj/devcontainer-features/firewall:1": {
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


---

_Note: This file was auto-generated from the [devcontainer-feature.json](devcontainer-feature.json).  Add additional notes to a `NOTES.md`._

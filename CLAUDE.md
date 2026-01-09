# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains Dev Container Features published to `ghcr.io/w3cj/devcontainer-features`. Currently includes a single feature: **firewall** - an iptables-based firewall that restricts outbound network access to only specified hosts.

## Build & Test Commands

```bash
# Test all features (global scenarios only)
make test

# Test a specific feature with all its scenarios
make test-feature feature=firewall
```

Requires: [Dev Container CLI](https://github.com/devcontainers/cli) and Docker.

## Repository Structure

```
src/<feature>/
├── devcontainer-feature.json  # Feature metadata, options, dependencies
├── install.sh                 # Main install script (runs at build time)
├── hosts.json                 # Domain allowlists by category
├── library_scripts.sh         # Shared bash functions
└── scripts/                   # Runtime scripts installed to /usr/local/bin

test/<feature>/
├── scenarios.json             # Test scenario definitions
└── test_*.sh                  # Test scripts using dev-container-features-test-lib
```

## Firewall Feature Architecture

**Install-time** (`install.sh`):
- Reads options from environment variables (UPPER_SNAKE_CASE)
- Resolves `hosts.json` keys to domain lists based on enabled options
- Generates `/usr/local/bin/firewall-config.sh` with SHA256 integrity hash
- Copies runtime scripts to `/usr/local/bin/`
- Configures sudoers for passwordless firewall execution

**Runtime** (`scripts/init-firewall.sh`):
- Runs via `postStartCommand` on container start
- Verifies config integrity, flushes iptables, creates ipset
- Fetches dynamic IP ranges (GitHub, Cloudflare, AWS, Google Cloud) if enabled
- Resolves configured domains via DNS and adds to ipset
- Sets DROP default policy with explicit allows for approved hosts
- Runs verification tests (blocks example.com, allows github.com if configured)

**Key files to modify when adding new allowlist options**:
1. `src/firewall/devcontainer-feature.json` - Add option definition
2. `src/firewall/hosts.json` - Add domain list
3. `src/firewall/install.sh` - Add variable and `add_hosts_if_enabled` call

## Testing Conventions

Test files use `dev-container-features-test-lib` which provides `check` and `reportResults` functions. Each scenario in `scenarios.json` maps to a `test_<name>.sh` file that validates the feature configuration works correctly.

## Publishing

Features are published via the `Release` GitHub Action workflow (manual trigger).

# Dev Container Features

A collection of Dev Container Features published to `ghcr.io/w3cj/devcontainer-features`.

## Features

| Feature | Description |
|---------|-------------|
| [firewall](src/firewall/README.md) | Configure a firewall to restrict outbound network access. Includes allow lists for common APIs, services and package managers. |

## Usage

Add features to your `devcontainer.json`:

```json
{
    "features": {
        "ghcr.io/w3cj/devcontainer-features/firewall:1": {
            "githubIps": true,
            "claudeCode": true
        }
    }
}
```

## Development

### Prerequisites

- [Dev Container CLI](https://github.com/devcontainers/cli)
- Docker

### Testing

Test all features:

```bash
make test
```

Test a specific feature:

```bash
make test-feature feature=firewall
```

### Publishing

Features are published via the `Release` GitHub Action workflow (manual trigger).

### References / Inspiration

* [devcontainers/feature-starter](https://github.com/devcontainers/feature-starter) for the base starter project
* [devcontainers-extra/features](https://github.com/devcontainers-extra/features) for tons of features to use as examples / inspiration
* [centminmod/claude-code-devcontainers](https://github.com/centminmod/claude-code-devcontainers) for the initial [firewall allow list](https://github.com/centminmod/claude-code-devcontainers/blob/master/.devcontainer/init-firewall.sh)
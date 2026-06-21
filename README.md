# Secure Hermes

A Docker-based sandbox for running [Hermes Agent](https://hermes-agent.nousresearch.com/) with a practical isolation boundary, persistent agent state, RTK integration, and preinstalled browser tooling.

This repository is intended for developers who want to run Hermes against a selected project directory without mounting their full home directory, Docker socket, SSH agent, or other broad host resources into the agent environment.

## Table of Contents

- [Features](#features)
- [Security Model](#security-model)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Secret Management](#secret-management)
- [Configuration](#configuration)
- [Persistence](#persistence)
- [Messaging Gateway](#messaging-gateway)
- [Browser Tooling](#browser-tooling)
- [RTK Integration](#rtk-integration)
- [Troubleshooting](#troubleshooting)
- [Project Structure](#project-structure)
- [License](#license)

## Features

- Runs Hermes Agent in an `ubuntu:24.04` Docker container.
- Mounts only one selected host workspace at `/workspace`.
- Keeps Hermes state in persistent Docker storage.
- Installs [Rust Token Killer](https://github.com/rtk-ai/rtk) and initializes its Hermes plugin.
- Disables RTK telemetry with `RTK_TELEMETRY_DISABLED=1`.
- Starts the Hermes messaging gateway automatically by default.
- Preinstalls Playwright and Chromium for browser-capable workflows.
- Applies practical Docker hardening defaults:
  - no privileged mode
  - no host networking
  - no Docker socket mount
  - no SSH agent mount
  - no full home-directory mount
  - `no-new-privileges`
  - private IPC namespace
  - PID, CPU, and memory limits

## Security Model

Secure Hermes is a practical Docker isolation setup, not a formal security sandbox.

By default, the container has:

- internet access through normal Docker bridge networking
- a writable Linux filesystem inside Docker
- one writable bind mount from the host into `/workspace`
- persistent container or volume-backed state under `/root`

The default launcher intentionally avoids sensitive host mounts. Do not add the following unless you explicitly want to weaken the boundary:

- `--privileged`
- `--network host`
- `-v /:/host`
- `-v "$HOME":...`
- `-v /var/run/docker.sock:/var/run/docker.sock`
- SSH agent mounts

Because the container has internet access, it may still reach network services available from your machine or local network. Avoid exposing sensitive local services on broad interfaces while using an internet-enabled agent.

## Requirements

- Docker
- Docker Compose v2, optional but supported
- Bash-compatible shell for `run-hermes.sh`
- A Hermes-compatible API key or secret configuration

## Quick Start

Build the image:

```bash
docker build -t hermes-agent-sandbox:latest .
```

Start Hermes with the helper script:

```bash
./run-hermes.sh
```

Or start with Docker Compose:

```bash
docker compose up
```

The helper script creates a persistent container named `hermes-agent-sandbox` on first run. Later runs restart and reattach to the same container so container-internal state persists across sessions.

## Secret Management

Secure Hermes supports two common secret-management patterns.

### Option A: Bitwarden Secrets Manager

Export a Bitwarden Secrets Manager access token on the host:

```bash
export BWS_ACCESS_TOKEN="your_token_here"
```

The token is passed into the container at runtime. Hermes can then use it to fetch provider keys without storing those keys directly in this repository.

### Option B: Local `.env` File

You can also store Hermes environment variables in the container state at:

```text
/root/.hermes/.env
```

This file lives inside the persistent container or Docker volume, not in this repository by default.

## Configuration

### Mount a Different Workspace

By default, `run-hermes.sh` mounts the current directory at `/workspace`.

Use `HOST_WORKSPACE_DIR` to mount another project:

```bash
HOST_WORKSPACE_DIR=/path/to/project ./run-hermes.sh
```

With Docker Compose:

```bash
HOST_WORKSPACE_DIR=/path/to/project docker compose up
```

### Disable Gateway Autostart

The Hermes messaging gateway starts automatically unless disabled:

```bash
HERMES_GATEWAY_ENABLED=0 ./run-hermes.sh
```

### Runtime Paths

The container uses these runtime paths:

| Variable | Value |
| --- | --- |
| `HOME` | `/root` |
| `HERMES_HOME` | `/root/.hermes` |
| `XDG_CACHE_HOME` | `/root/.cache` |
| `XDG_CONFIG_HOME` | `/root/.config` |
| `XDG_DATA_HOME` | `/root/.local/share` |
| `NPM_CONFIG_CACHE` | `/root/.cache/npm` |

### Docker Resource Limits

The default launcher and Compose service use:

| Setting | Value |
| --- | --- |
| CPUs | `2` |
| Memory | `2g` |
| PID limit | `1024` |
| Network | Docker bridge |
| IPC | private namespace |

## Persistence

Stop Hermes with `exit` or `Ctrl-D`. The container remains on disk and can be restarted:

```bash
./run-hermes.sh
```

Delete all container-internal state for the script-managed container:

```bash
docker rm -f hermes-agent-sandbox
```

After rebuilding the image, recreate the persistent container so it picks up image changes:

```bash
RECREATE=1 ./run-hermes.sh
```

Avoid `docker run --rm` or `docker compose run --rm` for normal use because those modes delete writable container state when the session exits.

## Messaging Gateway

The image entrypoint and `run-hermes.sh` both know how to start:

```bash
hermes gateway run
```

When started by the entrypoint, gateway output is written to:

```text
/root/.hermes/gateway.stdout.log
```

When started by `run-hermes.sh` for an existing container, Docker keeps the detached process output.

Check whether the gateway is running:

```bash
docker exec -it hermes-agent-sandbox bash -lc 'pgrep -af "[h]ermes gateway run"'
```

Follow the entrypoint-managed gateway log:

```bash
docker exec -it hermes-agent-sandbox bash -lc 'tail -f /root/.hermes/gateway.stdout.log'
```

Restart the gateway manually:

```bash
docker exec -it hermes-agent-sandbox bash -lc 'pkill -f "[h]ermes gateway run" || true'
docker exec -d hermes-agent-sandbox hermes gateway run
```

## Browser Tooling

The image installs Chromium and the system libraries needed by Playwright during the Docker build:

```dockerfile
RUN python3 -m pip install --break-system-packages playwright \
    && playwright install chromium --with-deps
```

This avoids browser installation during normal container startup.

## RTK Integration

RTK is installed into:

```text
/usr/local/bin/rtk
```

The Docker build verifies RTK with:

```bash
rtk --version
rtk gain
```

The Hermes integration is initialized during build with:

```bash
rtk init --agent hermes
```

At container startup, the entrypoint re-runs initialization only if the Hermes RTK plugin directory is missing:

```text
/root/.hermes/plugins/rtk-rewrite
```

## Troubleshooting

### `/workspace` Is Not Mounted

The entrypoint refuses to start unless `/workspace` is a mounted volume. Start the container through `run-hermes.sh`, Docker Compose, or an equivalent `docker run` command with a bind mount:

```bash
--mount type=bind,source="$(pwd)",target=/workspace,readonly=false
```

### Image Changes Are Not Visible

If you rebuilt the image but the running container still behaves the same, recreate the persistent container:

```bash
RECREATE=1 ./run-hermes.sh
```

### Gateway Does Not Start

Check whether gateway autostart is disabled:

```bash
echo "$HERMES_GATEWAY_ENABLED"
```

Then inspect the process and logs:

```bash
docker exec -it hermes-agent-sandbox bash -lc 'pgrep -af "[h]ermes gateway run" || true'
docker exec -it hermes-agent-sandbox bash -lc 'tail -n 100 /root/.hermes/gateway.stdout.log'
```

## Project Structure

```text
.
├── Dockerfile              # Builds the Hermes sandbox image
├── docker-compose.yml      # Compose service with the same sandbox defaults
├── docker-entrypoint.sh    # Runtime validation, state setup, and gateway startup
├── run-hermes.sh           # Persistent-container launcher
├── LICENSE                 # MIT License
└── README.md               # Project documentation
```

## License

This project is licensed under the [MIT License](LICENSE).

#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-hermes-agent-sandbox:latest}"
CONTAINER_NAME="${CONTAINER_NAME:-hermes-agent-sandbox}"
HERMES_GATEWAY_ENABLED="${HERMES_GATEWAY_ENABLED:-1}"
HOST_WORKSPACE_DIR="${HOST_WORKSPACE_DIR:-$(pwd)}"

start_gateway() {
  if [ "${HERMES_GATEWAY_ENABLED}" != "1" ]; then
    return 0
  fi

  if [ "${1:-}" = "hermes" ] && [ "${2:-}" = "gateway" ]; then
    return 0
  fi

  if docker exec "${CONTAINER_NAME}" bash -lc 'pgrep -f "[h]ermes gateway run" >/dev/null 2>&1'; then
    return 0
  fi

  docker exec -d "${CONTAINER_NAME}" hermes gateway run
}

if [ "${RECREATE:-0}" = "1" ] && docker container inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
  docker rm -f "${CONTAINER_NAME}" >/dev/null
fi

if docker container inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
  if [ "$(docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}")" != "true" ]; then
    docker start "${CONTAINER_NAME}" >/dev/null
  fi
  start_gateway "$@"
  docker attach "${CONTAINER_NAME}"
  exit $?
fi

docker create -it \
  --name "${CONTAINER_NAME}" \
  --network bridge \
  --add-host host.docker.internal:127.0.0.1 \
  --add-host gateway.docker.internal:127.0.0.1 \
  --security-opt no-new-privileges:true \
  --ipc private \
  --pids-limit 1024 \
  --memory 2g \
  --cpus 2 \
  -e BWS_ACCESS_TOKEN \
  --workdir /workspace \
  --mount type=bind,source="${HOST_WORKSPACE_DIR}",target=/workspace,readonly=false,bind-propagation=rprivate \
  --mount type=volume,source=hermes-data,target=/root \
  "${IMAGE_NAME}" "$@" >/dev/null

docker start "${CONTAINER_NAME}" >/dev/null
start_gateway "$@"
docker attach "${CONTAINER_NAME}"

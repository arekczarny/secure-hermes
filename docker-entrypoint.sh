#!/usr/bin/env bash
set -euo pipefail

workspace_mount="$(findmnt -rn --target /workspace --output TARGET | head -n 1 || true)"
if [ "${workspace_mount}" != "/workspace" ]; then
  echo "Refusing to start: /workspace is not a mounted volume." >&2
  echo "Run with: --mount type=bind,source=\"\$(pwd)\",target=/workspace,readonly=false" >&2
  exit 70
fi

umask 077
mkdir -p \
  "${HERMES_HOME:-/root/.hermes}" \
  "${XDG_CACHE_HOME:-/root/.cache}" \
  "${XDG_CONFIG_HOME:-/root/.config}" \
  "${XDG_DATA_HOME:-/root/.local/share}" \
  "${NPM_CONFIG_CACHE:-/root/.cache/npm}"

if command -v rtk >/dev/null 2>&1 && [ ! -d "${HERMES_HOME:-/root/.hermes}/plugins/rtk-rewrite" ]; then
  HOME="${HOME:-/root}" HERMES_HOME="${HERMES_HOME:-/root/.hermes}" rtk init --agent hermes >/dev/null 2>&1 || true
fi

if [ "${HERMES_GATEWAY_ENABLED:-1}" = "1" ] && { [ "${1:-}" != "hermes" ] || [ "${2:-}" != "gateway" ]; }; then
  if ! pgrep -f "[h]ermes gateway run" >/dev/null 2>&1; then
    hermes_home="${HERMES_HOME:-/root/.hermes}"
    log_path="${HERMES_GATEWAY_STDOUT_LOG:-${hermes_home}/gateway.stdout.log}"
    mkdir -p "${hermes_home}" "$(dirname "${log_path}")"
    setsid hermes gateway run >> "${log_path}" 2>&1 < /dev/null &
  fi
fi

exec "$@"

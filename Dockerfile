# syntax=docker/dockerfile:1.7

FROM ubuntu:24.04

ARG HERMES_INSTALL_URL="https://hermes-agent.nousresearch.com/install.sh"
ARG HERMES_INSTALL_FLAGS="--skip-setup --non-interactive"
ARG RTK_INSTALL_URL="https://raw.githubusercontent.com/rtk-ai/rtk/master/install.sh"

ENV DEBIAN_FRONTEND=noninteractive \
    HERMES_HOME=/opt/hermes-home \
    PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers \
    RTK_TELEMETRY_DISABLED=1 \
    UV_NO_CONFIG=1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        coreutils \
        curl \
        ffmpeg \
        findutils \
        git \
        gzip \
        openssh-client \
        procps \
        ripgrep \
        sudo \
        tar \
        unzip \
        util-linux \
        xz-utils \
        wget \
        gnupg \
        python3-pip \
        python3-venv \
        libgbm1 \
        libnss3 \
        libatk1.0-0 \
        libatk-bridge2.0-0 \
        libcups2 \
        libdrm2 \
        libxkbcommon0 \
        libxcomposite1 \
        libxdamage1 \
        libxrandr2 \
        libasound2t64 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "${HERMES_INSTALL_URL}" | bash -s -- ${HERMES_INSTALL_FLAGS}

RUN curl -fsSL "${RTK_INSTALL_URL}" | RTK_INSTALL_DIR=/usr/local/bin sh \
    && rtk --version \
    && rtk gain >/dev/null

RUN mkdir -p /workspace /root/.hermes /root/.cache /root/.config /root/.local/share \
    && HOME=/root HERMES_HOME=/root/.hermes timeout 60s rtk init --agent hermes

# --- Pre-install Playwright Browsers ---
# This ensures Chrome is available immediately without needing an 'install' call at runtime
RUN python3 -m pip install --break-system-packages playwright && playwright install chromium --with-deps
# ---------------------------------------

COPY docker-entrypoint.sh /usr/local/bin/hermes-entrypoint
RUN chmod 0755 /usr/local/bin/hermes-entrypoint

WORKDIR /workspace

ENV HOME=/root \
    HERMES_HOME=/root/.hermes \
    XDG_CACHE_HOME=/root/.cache \
    XDG_CONFIG_HOME=/root/.config \
    XDG_DATA_HOME=/root/.local/share \
    NPM_CONFIG_CACHE=/root/.cache/npm \
    RTK_TELEMETRY_DISABLED=1 \
    PATH=/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin

ENTRYPOINT ["/usr/local/bin/hermes-entrypoint"]
CMD ["hermes"]

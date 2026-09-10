# dsh — DeepSeek Harness web UI, containerized so it survives terminal closes,
# sleeps and reboots (Coolify `restart: unless-stopped`, Coolify restart policy).
#
# Host-agnostic: the workspace root is /workspace by default. Override at run
# time with `-w <path>` (or compose `working_dir:`) and a matching bind mount.
FROM node:22-bookworm-slim

# Pinned to the version the author's host runs so behaviour matches.
ARG DSH_VERSION=0.1.2-rc.1

ENV DEBIAN_FRONTEND=noninteractive \
    PNPM_HOME=/pnpm \
    PATH=/pnpm:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Tools the harness's bash/terminal tools expect, plus the build chain the
# transitive native modules (node-pty) compile against, plus python3.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git git-lfs jq less procps ripgrep unzip \
      python3 python3-venv python3-pip \
      build-essential pkg-config \
 && rm -rf /var/lib/apt/lists/*

# pnpm is what `dsh plugin` and the profile bootstrap expect next to dsh.
RUN npm install -g pnpm@10 && npm cache clean --force

# The harness itself, installed through pnpm so the dependency closure lands in
# the layout dsh's profile bootstrap walks.
RUN pnpm add -g @deepseek-ai/dsh@${DSH_VERSION} \
 && pnpm store prune \
 && dsh --version

# uid/gid 501: matches the author's macOS host user, and stays harmless on a
# Linux host where only the image-owned directories are touched.
RUN groupadd -g 501 dsh \
 && useradd -m -u 501 -g 501 -s /bin/bash dsh \
 && mkdir -p /workspace /home/dsh/.dsh \
 && chown -R dsh:dsh /home/dsh /workspace

USER dsh
ENV HOME=/home/dsh \
    DSH_HOME=/home/dsh/.dsh

# Default workspace root. Mount something here (or change -w at run time).
WORKDIR /workspace
EXPOSE 3080

ENTRYPOINT ["dsh"]
CMD ["web", "--host", "0.0.0.0", "--port", "3080", "--no-open"]

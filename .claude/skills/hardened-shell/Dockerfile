# syntax=docker/dockerfile:1.7

# Base: Debian stable slim. Small, current glibc, apt is easy.
FROM debian:stable-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    MISE_DATA_DIR=/opt/mise \
    PATH=/opt/mise/shims:/usr/local/bin:/usr/bin:/bin

# OS packages: shell + dev CLIs + network + build deps.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl wget gnupg \
      git ripgrep fd-find bat jq tree less \
      bash-completion procps file \
      build-essential \
      tini \
      openssh-client \
 && ln -s /usr/bin/fdfind /usr/local/bin/fd \
 && ln -s /usr/bin/batcat /usr/local/bin/bat \
 && rm -rf /var/lib/apt/lists/*

# GitHub CLI (upstream apt repo)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/*

# Doppler CLI (official install script)
RUN curl -fsSL https://cli.doppler.com/install.sh | sh -s -- --verify-signature

# mise — installed under /opt/mise so shims are on PATH for every user.
# Pinned LTS versions. Bump in place when a new LTS lands.
# pinned 2026-04-14 — replace with the versions you recorded in Step 1.
ENV NODE_LTS_VERSION=24.14.1 \
    PYTHON_VERSION=3.14.4

RUN curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh \
 && mise settings set experimental true \
 && mise use -g "node@${NODE_LTS_VERSION}" "python@${PYTHON_VERSION}" \
 && mise reshim

# Claude Code CLI — install from the official npm package so it uses the
# bundled node. This is the supported install path.
RUN npm install -g @anthropic-ai/claude-code \
 && claude --version

# Non-root "agent" user. UID 1000 is the common Ubuntu desktop default;
# hshell launcher overrides via --user $(id -u):$(id -g) when needed.
RUN useradd -m -u 1000 -U -s /bin/bash agent \
 && mkdir -p /home/agent/.claude /work \
 && chown -R agent:agent /home/agent /work

WORKDIR /work

# tini reaps zombies for long-running agent subprocesses
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["bash"]

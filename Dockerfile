ARG BASE_IMAGE=nvidia/cuda:12.9.1-cudnn-runtime-ubuntu22.04
FROM ${BASE_IMAGE}

ARG DEV_UID=1000
ARG DEV_GID=1000

# Basics packages
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates curl git vim tini openssh-server python3 python3-venv python3-pip \
    build-essential ninja-build \
    && rm -rf /var/lib/apt/lists/* && mkdir -p /var/run/sshd

# Prefer gcc
ENV CC=/usr/bin/gcc CXX=/usr/bin/g++

# Triton JIT cache
ENV TRITON_CACHE_DIR=/cache/triton
RUN mkdir -p /cache/triton && chown -R ${DEV_UID}:${DEV_GID} /cache/triton

# Fast Python tool
ENV UV_CACHE_DIR=/cache/uv
RUN env UV_UNMANAGED_INSTALL=/usr/local/bin \
    sh -c 'curl -LsSf https://astral.sh/uv/install.sh | sh' \
 && chmod 0755 /usr/local/bin/uv

# Create non-root login user "dev" with chosen UID/GID
RUN groupadd -g ${DEV_GID} dev && useradd -m -u ${DEV_UID} -g ${DEV_GID} -s /bin/bash dev && \
    install -d -m 700 -o dev -g dev /home/dev/.ssh

# Harden sshd (keys only, no root login) + persistent host keys path
RUN printf '%s\n' \
  'PasswordAuthentication no' \
  'PermitRootLogin no' \
  'PubkeyAuthentication yes' \
  'ChallengeResponseAuthentication no' \
  'UsePAM yes' \
  'X11Forwarding no' \
  'AuthorizedKeysFile /home/dev/.ssh/authorized_keys' \
  'HostKey /etc/ssh/keys/ssh_host_ed25519_key' \
  'HostKey /etc/ssh/keys/ssh_host_rsa_key' \
  > /etc/ssh/sshd_config.d/10-team.conf

# Env setup
RUN cat >/etc/environment <<'EOF'
HF_HOME=/cache/hf
HUGGINGFACE_HUB_CACHE=/cache/hf
PIP_CACHE_DIR=/cache/pip
UV_CACHE_DIR=/cache/uv
POETRY_CACHE_DIR=/cache/poetry
EOF

WORKDIR /work
ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["/usr/sbin/sshd","-D","-e"]

# Build args you can override from compose
ARG BASE_IMAGE=nvidia/cuda:12.9.1-cudnn-runtime-ubuntu22.04
ARG DEV_UID=1000
ARG DEV_GID=1000

FROM ${BASE_IMAGE}

# Base tools + sshd + tini + python (uv/poetry will manage most envs)
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    openssh-server ca-certificates curl git tini \
    python3 python3-venv python3-pip build-essential pkg-config \
    libffi-dev libssl-dev && \
    rm -rf /var/lib/apt/lists/* && mkdir -p /var/run/sshd

# Create dev user matching host uid/gid (so bind mounts have sane ownership)
RUN groupadd -g ${DEV_GID} dev && useradd -m -u ${DEV_UID} -g ${DEV_GID} -s /bin/bash dev && \
    install -d -m 700 -o dev -g dev /home/dev/.ssh

# Install uv (fast Python & package manager)
ENV UV_CACHE_DIR=/cache/uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && ln -s /root/.local/bin/uv /usr/local/bin/uv

# Install Poetry
ENV POETRY_CACHE_DIR=/cache/poetry
RUN curl -sSL https://install.python-poetry.org | python3 - && \
    ln -s /root/.local/bin/poetry /usr/local/bin/poetry

# Common caches (bind-mounted in compose)
ENV PIP_CACHE_DIR=/cache/pip \
    POETRY_VIRTUALENVS_PATH=/cache/poetry/venvs \
    # Uncomment if you also want these:
    # HF_HOME=/cache/hf \
    # TRANSFORMERS_CACHE=/cache/hf \
    # TORCH_HOME=/cache/torch \
    PYTHONUNBUFFERED=1

# Minimal hardening for sshd (keys only, no root login)
RUN printf '%s\n' \
  'PasswordAuthentication no' \
  'PermitRootLogin no' \
  'PubkeyAuthentication yes' \
  'ChallengeResponseAuthentication no' \
  'UsePAM no' \
  'X11Forwarding no' \
  'ClientAliveInterval 30' \
  'ClientAliveCountMax 4' \
  > /etc/ssh/sshd_config.d/10-team.conf

WORKDIR /work
EXPOSE 22

# Proper signal handling
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/sbin/sshd","-D","-e"]

# GPU Container Management

Multi-team GPU container orchestration using Docker Compose with NVIDIA GPU support.

## Quick Start

```bash
# Start all team containers
docker compose up -d

# Start specific team
docker compose up -d team_asap

# View running containers
docker compose ps

# Stop all containers
docker compose down
```

## Team Management

### Adding a New Team

1. Add a new service in `docker-compose.yml`:
```yaml
services:
  team_oldteam:
    ...

  team_newteam:
    <<: *dev
    container_name: team_newteam-dev-ssh
    ports: ["2224:22"]  # Use next available port
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              device_ids: ["4","5"]  # Assign specific GPUs
              capabilities: ["gpu"]
    depens_on:        # Add dependency for container's ip address reproducibility
      - team_oldteam
    volumes:
        # Volumes shared across all teams
        - /data/cache/hf:/cache/hf:rw
        - /data/cache/uv:/cache/uv:rw
        - /data/ssh/authorized_keys:/home/dev/.ssh/authorized_keys:ro
        - /data/ssh/hostkeys:/etc/ssh/keys:ro
        # Team-specific volumes
        - /data/work/team_newteam/work:/work:rw # Mount /work volume with team name

```

2. Add SSH config entry in `ssh-config`:
```
Host mipt_aigrant_newteam
  HostName 127.0.0.1
  Port 2224
  User dev
  ProxyJump mipt_aigrant_cluster
  IdentityFile ~/.ssh/mipt/rsa_newteam
  IdentitiesOnly yes
```

### Modifying Team Resources

**GPU Allocation**: Edit the `device_ids` array in docker-compose.yml
```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          device_ids: ["0","1","2","3"]
          capabilities: ["gpu"]
```

```
docker compose up -d --force-recreate team_asap
```


## Server Folder Structure

```
/data/
├── cache/          # Shared package caches (mounted read-write)
│   ├── hf/         # HuggingFace models cache
│   ├── pip/        # Python pip cache
│   ├── poetry/     # Poetry dependency cache
│   ├── torch/      # PyTorch cache
│   └── uv/         # UV package manager cache
├── docker/         # Docker daemon data
├── ssh/            # SSH configuration
│   ├── authorized_keys  # Public keys for access
│   └── hostkeys/   # SSH host keys
└── work/           # Team workspaces (mounted read-write)
    ├── team_name_1/work
    └── team_name_2/work
```

## GPU Resource Management

### Checking GPU Availability
```bash
# On host system
nvidia-smi

# Inside container
nvidia-smi
python -c "import torch; print(torch.cuda.device_count())"
```

### Resource Monitoring
```bash
# Monitor GPU usage
watch nvidia-smi

# Check container resources
docker stats

# View container logs
docker compose logs team_asap
```

## SSH Access

### Connection Setup
1. Copy the `ssh-config` to your `~/.ssh/config`
2. Update proxy host details and key paths
3. Connect: `ssh mipt_aigrant_asap`

### Key Management
- Team keys go in `/data/ssh/authorized_keys`
- One key per line format
- Restart containers after key changes

## Container Features

- **Base**: NVIDIA CUDA 12.9.1 with cuDNN on Ubuntu 22.04
- **User**: Non-root `dev` user (UID/GID 1000)
- **SSH**: Key-based authentication only, no password login
- **Caches**: Shared package caches for faster installs
- **Security**: Hardened SSH config, no-new-privileges

## Common Operations

```bash
# Restart a team's container
docker compose restart team_asap

# Update container (rebuild)
docker compose up -d --build team_asap

# View container shell
docker compose exec team_asap bash

# Check GPU allocation
docker compose exec team_asap nvidia-smi

# Monitor logs
docker compose logs -f team_asap
```

## Environment Variables

Key environment variables set in containers:
- `HF_HOME=/cache/hf` - HuggingFace cache location
- `UV_CACHE_DIR=/cache/uv` - UV package cache
- `NVIDIA_DRIVER_CAPABILITIES=compute,utility` - GPU capabilities
- `CUDA_VISIBLE_DEVICES` - GPU visibility control

## Server Setup Hint

Not verified but reflects the necessary commands

```
# data & caches permissions setup
sudo mkdir -p /data/{work,cache/{uv,hf},ssh/hostkeys}
sudo chown -R mipt-user:mipt-user /data/{work,cache,ssh}
chmod 755 /data /data/{work,cache,ssh}

# SSH host keys
ssh-keygen -t ed25519 -N '' -f /data/ssh/hostkeys/ssh_host_ed25519_key
chmod 600 /data/ssh/hostkeys/ssh_host_ed25519_key

# Authorized keys (your login key)
cat ~/.ssh/id_rsa.pub >> /data/ssh/authorized_keys   # or id_ed25519.pub
chmod 700 /data/ssh && chmod 600 /data/ssh/authorized_keys

# Permissions for volume directories
sudo chown -R 1000:1000 /data/cache/uv /data/shared/hf /data/work
sudo chmod -R 2775 /data/cache/uv /data/shared/hf /data/work

# Clone repo and setup .env
cd /data
git clone https://github.com/ti3c2/gpu-containers-mipt/
cd gpu-containers-mipt
cp .env.example .env

# Create containers
docker compose up -d

```

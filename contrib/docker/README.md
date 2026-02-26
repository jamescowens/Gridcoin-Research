# Gridcoin Docker Images

Official Docker images for running Gridcoin as a headless daemon or with the Qt GUI.

## Images

| Image | Description |
|-------|-------------|
| `ghcr.io/gridcoin-community/gridcoinresearchd` | Headless daemon only |
| `ghcr.io/gridcoin-community/gridcoinresearch` | Daemon + Qt GUI |

Both images currently support `linux/amd64`. ARM64 support is planned for a future release
once the depends build system supports aarch64 cross-compilation.

## Quick Start

### Headless (Daemon)

```bash
docker pull ghcr.io/gridcoin-community/gridcoinresearchd:latest

docker run -d \
  --name gridcoin \
  -v ~/.GridcoinResearch:/home/gridcoin/.GridcoinResearch \
  -p 32749:32749 \
  ghcr.io/gridcoin-community/gridcoinresearchd:latest
```

### GUI

```bash
docker pull ghcr.io/gridcoin-community/gridcoinresearch:latest

# Allow X11 connections (run on host)
xhost +local:docker

docker run -d \
  --name gridcoin-gui \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  -v ~/.GridcoinResearch:/home/gridcoin/.GridcoinResearch \
  -p 32749:32749 \
  ghcr.io/gridcoin-community/gridcoinresearch:latest \
  gridcoinresearch
```

## Docker Compose

### Headless + BOINC

```bash
cd contrib/docker
cp .env.example .env
# Edit .env to set GRIDCOIN_DATA_DIR

docker compose up -d
```

This starts both the Gridcoin daemon and a BOINC client with a shared data volume,
allowing Gridcoin to read BOINC statistics for research reward eligibility.

### GUI + BOINC

```bash
cd contrib/docker
cp .env.example .env
# Edit .env to set GRIDCOIN_DATA_DIR and DISPLAY

docker compose -f docker-compose.gui.yml up -d
```

## Data Persistence

All blockchain data, wallet files, and configuration are stored in the data directory
mounted at `/home/gridcoin/.GridcoinResearch` inside the container. This is a standard
bind mount -- the same directory layout as a bare-metal installation.

**Back up your wallet:** The wallet file is at `<data-dir>/wallet.dat`. Back it up
regularly, especially before upgrading.

## Configuration

### Auto-Generated Config

On first run, if no `gridcoinresearch.conf` exists, the entrypoint creates one with:
- `server=1` (RPC server enabled)
- Random `rpcpassword` (generated via `openssl rand -hex 32`)
- `rpcallowip` entries for localhost and Docker internal networks
- `printtoconsole=1` (forced for Docker log visibility)

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GRIDCOIN_DATA_DIR` | `./.gridcoin` | Host path for persistent data |
| `P2P_PORT` | `32749` | Host P2P port mapping |
| `RPC_PORT` | `15715` | Host RPC port mapping |
| `DISPLAY` | (none) | X11 display for GUI |

### Custom Config

Edit `<data-dir>/gridcoinresearch.conf` directly, or pass arguments to the daemon:

```bash
docker run -d \
  --name gridcoin \
  -v ~/.GridcoinResearch:/home/gridcoin/.GridcoinResearch \
  ghcr.io/gridcoin-community/gridcoinresearchd:latest \
  -testnet -debug=net
```

## Exchange Deployment

For exchange integration, enable the RPC port and configure credentials:

```bash
docker run -d \
  --name gridcoin \
  -v /data/gridcoin:/home/gridcoin/.GridcoinResearch \
  -p 32749:32749 \
  -p 127.0.0.1:15715:15715 \
  ghcr.io/gridcoin-community/gridcoinresearchd:latest
```

The auto-generated config enables `server=1` with a random password. Retrieve it:

```bash
docker exec gridcoin grep rpcpassword /home/gridcoin/.GridcoinResearch/gridcoinresearch.conf
```

Key RPC methods for exchanges:
- `getnewaddress` -- generate deposit addresses
- `sendtoaddress` -- process withdrawals
- `listtransactions` / `listsinceblock` -- track deposits
- `getblockchaininfo` -- monitor sync status
- `walletnotify` / `blocknotify` -- real-time transaction/block notifications

Transaction index is always enabled (no `-txindex` flag needed).

**Note:** Gridcoin uses plaintext `rpcuser`/`rpcpassword` (hashed `rpcauth` is not
supported). Docker network isolation (binding RPC to 127.0.0.1 only) mitigates this.

## GUI Display Server Notes

The GUI image includes the Qt XCB (X11) platform plugin.

- **X11 sessions:** Work directly with the X11 socket mount shown above
- **Wayland sessions:** Work via XWayland, which is enabled by default on GNOME, KDE
  Plasma, Sway, and other major Wayland compositors
- **Pure Wayland (no XWayland):** Not supported

## Building Locally

Build static binaries using the `depends/` system, then create Docker images:

```bash
# 1. Build static binaries
cmake -B build_depends \
  --toolchain depends/x86_64-pc-linux-gnu/toolchain.cmake \
  -DSTATIC_LIBS=ON -DENABLE_GUI=ON -DENABLE_TESTS=OFF \
  -DCMAKE_BUILD_TYPE=Release
cmake --build build_depends -j$(nproc)

# 2. Stage binaries
cd contrib/docker
mkdir -p bin/amd64
cp ../../build_depends/src/gridcoinresearchd bin/amd64/
cp ../../build_depends/src/qt/gridcoinresearch bin/amd64/

# 3. Build images
docker build -f Dockerfile.headless -t gridcoin-headless .
docker build -f Dockerfile.gui -t gridcoin-gui .
```

## Ports

| Port | Protocol | Network | Description |
|------|----------|---------|-------------|
| 32749 | TCP | Mainnet | P2P |
| 15715 | TCP | Mainnet | RPC |
| 32748 | TCP | Testnet | P2P |
| 25715 | TCP | Testnet | RPC |

## Security Model

The images follow defense-in-depth principles:

- **Non-root execution:** The daemon runs as user `gridcoin` (UID/GID 1000) via `gosu`
- **Read-only filesystem:** `read_only: true` in docker-compose (writable data dir via volume)
- **Dropped capabilities:** `cap_drop: ALL` removes all Linux capabilities
- **No privilege escalation:** `no-new-privileges` security option
- **Private tmp:** `tmpfs` mount for `/tmp`
- **Minimal base image:** `ubuntu:24.04` with only `ca-certificates`, `gosu`,
  and `openssl` installed (GUI adds X11 libraries)
- **Config permissions:** `gridcoinresearch.conf` created with mode `0600`

## Troubleshooting

### Container won't start

Check logs:
```bash
docker logs gridcoin
```

### GUI shows "could not connect to display"

1. Ensure `DISPLAY` is set: `echo $DISPLAY`
2. Allow Docker X11 access: `xhost +local:docker`
3. Verify X11 socket exists: `ls /tmp/.X11-unix/`

### Sync is slow

This is normal for initial blockchain download. Monitor progress:
```bash
docker exec gridcoin gridcoinresearchd getblockchaininfo
```

### Permission denied on data directory

The container runs as UID/GID 1000. Ensure your data directory is owned by the same:
```bash
sudo chown -R 1000:1000 ~/.GridcoinResearch
```

Or build with custom UID/GID:
```bash
docker build --build-arg UID=$(id -u) --build-arg GID=$(id -g) \
  -f Dockerfile.headless -t gridcoin-headless .
```
